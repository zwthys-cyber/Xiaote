import SwiftUI

/// One system refresh control owns the gesture and its progress indicator.
struct AccountRefreshScrollView<Content: View>: View {
    let isEnabled: Bool
    let action: @MainActor () async -> Void
    @ViewBuilder let content: (Bool) -> Content
    @State private var isRefreshing = false

    var body: some View {
        if isEnabled {
            scrollContent
                .refreshable {
                    // Updating the loading content can invalidate SwiftUI's
                    // refresh task. Keep the request alive through that update;
                    // account generation checks still discard signed-out results.
                    await Task { @MainActor in
                        guard !isRefreshing else { return }
                        isRefreshing = true
                        defer { isRefreshing = false }
                        await action()
                    }.value
                }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView { content(isRefreshing) }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .accessibilityIdentifier("account-refresh-scroll")
    }
}
