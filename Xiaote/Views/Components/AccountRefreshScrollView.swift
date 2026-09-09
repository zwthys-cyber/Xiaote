import SwiftUI

/// One system refresh control owns the gesture and its progress indicator.
struct AccountRefreshScrollView<Content: View>: View {
    let isEnabled: Bool
    let action: @MainActor () async -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isEnabled {
            scrollContent
                .refreshable {
                    await action()
                }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView { content() }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .accessibilityIdentifier("account-refresh-scroll")
    }
}
