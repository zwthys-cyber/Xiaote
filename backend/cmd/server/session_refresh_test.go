package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func expiredSession(t *testing.T, s *server) session {
	t.Helper()
	refresh, err := s.encrypt("old-refresh")
	if err != nil {
		t.Fatal(err)
	}
	entry := session{ID: "refresh-test", TokenHash: tokenHash("local-token"), TeslaRefreshToken: refresh,
		TeslaExpiresAt: time.Now().Add(-time.Minute), ExpiresAt: time.Now().Add(time.Hour)}
	if err := s.store.update(func(d *storeData) error { d.Sessions[entry.ID] = entry; return nil }); err != nil {
		t.Fatal(err)
	}
	return entry
}

func TestConcurrentRefreshUsesOneTokenRotation(t *testing.T) {
	s := testServer(t)
	entry := expiredSession(t, s)
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if err := r.ParseForm(); err != nil {
			t.Error(err)
		}
		if r.Form.Get("refresh_token") != "old-refresh" {
			t.Error("unexpected refresh token")
		}
		_, _ = w.Write([]byte(`{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}`))
	}))
	defer upstream.Close()
	s.cfg.AuthBaseURL = upstream.URL
	var group sync.WaitGroup
	for i := 0; i < 20; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			updated, err := s.refreshSession(context.Background(), entry)
			if err != nil {
				t.Error(err)
				return
			}
			token, err := s.decrypt(updated.TeslaRefreshToken)
			if err != nil || token != "new-refresh" {
				t.Errorf("rotation lost: %q %v", token, err)
			}
		}()
	}
	group.Wait()
	if calls.Load() != 1 {
		t.Fatalf("refresh count = %d, want 1", calls.Load())
	}
}

func TestLogoutDuringRefreshCannotResurrectSession(t *testing.T) {
	s := testServer(t)
	entry := expiredSession(t, s)
	started, release := make(chan struct{}), make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(started)
		<-release
		_, _ = w.Write([]byte(`{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}`))
	}))
	defer upstream.Close()
	s.cfg.AuthBaseURL = upstream.URL
	result := make(chan error, 1)
	go func() { _, err := s.refreshSession(context.Background(), entry); result <- err }()
	<-started
	req := httptest.NewRequest(http.MethodDelete, "/v1/auth/session", nil)
	req.Header.Set("Authorization", "Bearer local-token")
	w := httptest.NewRecorder()
	s.routes().ServeHTTP(w, req)
	close(release)
	if w.Code != http.StatusNoContent {
		t.Fatalf("logout returned %d", w.Code)
	}
	if err := <-result; !errors.Is(err, errSessionRevoked) {
		t.Fatalf("expected revocation, got %v", err)
	}
	if _, ok := s.store.readSession("local-token"); ok {
		t.Fatal("session resurrected")
	}
	persisted, err := openStore(s.store.path)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := persisted.readSession("local-token"); ok {
		t.Fatal("revocation was not persisted")
	}
}

func TestRefreshFailureDistinguishesTemporaryAndRevokedAuthorization(t *testing.T) {
	for _, test := range []struct {
		name   string
		status int
		body   string
		want   int
	}{
		{"temporary", 503, `{}`, 503},
		{"invalid grant", 400, `{"error":"invalid_grant"}`, 401},
	} {
		t.Run(test.name, func(t *testing.T) {
			s := testServer(t)
			expiredSession(t, s)
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(test.status)
				_, _ = w.Write([]byte(test.body))
			}))
			defer upstream.Close()
			s.cfg.AuthBaseURL = upstream.URL
			req := httptest.NewRequest(http.MethodGet, "/v1/vehicles", nil)
			req.Header.Set("Authorization", "Bearer local-token")
			w := httptest.NewRecorder()
			s.routes().ServeHTTP(w, req)
			if w.Code != test.want {
				t.Fatalf("got %d, want %d: %s", w.Code, test.want, w.Body.String())
			}
		})
	}
}

func TestRefreshWaiterCanCancel(t *testing.T) {
	s := testServer(t)
	entry := expiredSession(t, s)
	flight := &sessionRefresh{done: make(chan struct{})}
	s.refreshes = map[string]*sessionRefresh{entry.ID: flight}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := s.refreshSession(ctx, entry); !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v", err)
	}
}
