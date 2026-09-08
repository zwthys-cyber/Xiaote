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
                    guard !isRefreshing else { return }
                    isRefreshing = true
                    defer { isRefreshing = false }
                    await action()
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
            .accessibilityValue(isRefreshing ? Text("正在刷新") : Text(""))
    }
}
