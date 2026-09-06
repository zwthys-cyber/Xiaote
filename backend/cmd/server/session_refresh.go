package main

import (
	"context"
	"errors"
	"time"
)

var errSessionRevoked = errors.New("session is revoked or expired")
var errAuthorizationExpired = errors.New("Tesla authorization has expired")

type sessionRefresh struct {
	done  chan struct{}
	entry session
	err   error
}

// Coalesce refreshes by session, including failures, without blocking unrelated
// accounts. Re-read the store after acquiring ownership so callers holding an
// old snapshot never refresh an already rotated token.
func (s *server) refreshSession(ctx context.Context, entry session) (session, error) {
	s.refreshMu.Lock()
	if flight := s.refreshes[entry.ID]; flight != nil {
		s.refreshMu.Unlock()
		select {
		case <-ctx.Done():
			return session{}, ctx.Err()
		case <-flight.done:
			return flight.entry, flight.err
		}
	}
	if s.refreshes == nil {
		s.refreshes = make(map[string]*sessionRefresh)
	}
	flight := &sessionRefresh{done: make(chan struct{})}
	s.refreshes[entry.ID] = flight
	s.refreshMu.Unlock()
	defer func() {
		s.refreshMu.Lock()
		delete(s.refreshes, entry.ID)
		close(flight.done)
		s.refreshMu.Unlock()
	}()

	s.store.mu.Lock()
	current, ok := s.store.data.Sessions[entry.ID]
	s.store.mu.Unlock()
	if !ok || current.TokenHash != entry.TokenHash || !time.Now().Before(current.ExpiresAt) {
		flight.err = errSessionRevoked
	} else if time.Until(current.TeslaExpiresAt) >= 2*time.Minute {
		flight.entry = current
	} else {
		flight.entry, flight.err = s.refreshSessionTokens(ctx, current)
	}
	return flight.entry, flight.err
}
