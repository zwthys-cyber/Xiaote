import SwiftUI

/// A compact account entry point. Account connectivity does not imply that
/// a vehicle is awake or that a remote command has been accepted.
struct AccountStatusButton: View {
    @Environment(FleetAccountController.self) private var account
    var showsActivity = true
    let openAccount: () -> Void

    private var state: FleetAccountController.ConnectionState {
        guard let session = account.session else { return .notConnected }
        if session.expiresAt <= Date() { return .reauthorizationRequired }
        return account.connectionState
    }

    var body: some View {
        Button {
            // The account page already offers inline recovery for these states.
            account.errorMessage = nil
            openAccount()
        } label: {
            ZStack {
                Circle().fill(AppTheme.surface)
                Circle().stroke(AppTheme.hairline, lineWidth: 0.5)
                if state == .checking && showsActivity {
                    ProgressView().tint(.white).controlSize(.small)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(state == .notConnected ? AppTheme.muted : .white)
                }
            }
            .frame(width: 44, height: 44)
            .overlay(alignment: .bottomTrailing) {
                if let symbol = badgeSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(state == .available ? Color.green : Color.orange)
                        .frame(width: 18, height: 18)
                        .background(AppTheme.background, in: Circle())
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(UtilityPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tesla 账号")
        .accessibilityValue(Text(LocalizedStringKey(accessibilityStatus)))
        .accessibilityHint("查看账号或重新登录")
        .accessibilityIdentifier("home-account-status")
    }

    private var badgeSymbol: String? {
        switch state {
        case .available: "checkmark.circle.fill"
        case .unavailable: "exclamationmark.circle.fill"
        case .reauthorizationRequired: "lock.fill"
        case .notConnected, .checking: nil
        }
    }

    private var accessibilityStatus: String {
        switch state {
        case .notConnected: "未登录"
        case .checking: "正在同步账号"
        case .available: "账号已连接"
        case .unavailable: "账号同步失败，点按重试"
        case .reauthorizationRequired: "需要重新登录"
        }
    }
}
