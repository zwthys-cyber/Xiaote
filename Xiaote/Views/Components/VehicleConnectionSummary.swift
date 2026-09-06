import SwiftUI

struct VehicleConnectionSummary: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(FleetAccountController.self) private var account
    let openAccount: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .leading, spacing: 9) {
                row("无感钥匙", value: vehicle.passiveEntryEnabled ? (vehicle.passiveKeyOnline ? "在线" : "恢复中") : "已关闭",
                    symbol: "key.horizontal", ready: vehicle.passiveEntryEnabled && vehicle.passiveKeyOnline)
                row("本地控制", value: vehicle.phase.title, symbol: "antenna.radiowaves.left.and.right", ready: locallyConnected)
                Button(action: openAccount) {
                    row("远程连接", value: cloudTitle(at: timeline.date), symbol: "network",
                        ready: account.connectionState == .available && VehicleDataAge.isFresh(account.lastAccountUpdate, at: timeline.date))
                }
                .buttonStyle(.plain)
                .accessibilityHint("查看账号或重新登录")
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                    if let date = vehicle.stateFreshness.updatedAt(requiring: [.battery, .range]) {
                        Text(VehicleDataAge.isFresh(date, at: timeline.date) ? "电量与续航" : "电量与续航为旧数据")
                        Text(date, style: .relative)
                    } else {
                        Text("电量与续航尚未完整读取")
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
        .task {
            if account.isSignedIn && account.lastAccountUpdate == nil { await account.refreshAccount() }
        }
    }

    private var locallyConnected: Bool {
        if vehicle.phase == .connected { return true }
        if case .executing = vehicle.phase { return true }
        return false
    }

    private func cloudTitle(at now: Date) -> String {
        guard account.isSignedIn else { return "未连接账号" }
        if account.connectionState == .available {
            return VehicleDataAge.isFresh(account.lastAccountUpdate, at: now) ? "可用" : "待检查"
        }
        return account.connectionState.title
    }

    private func row(_ title: String, value: String, symbol: String, ready: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).frame(width: 18).accessibilityHidden(true)
            Text(LocalizedStringKey(title))
            Spacer(minLength: 8)
            Circle().fill(ready ? Color.green : AppTheme.muted).frame(width: 5, height: 5).accessibilityHidden(true)
            Text(LocalizedStringKey(value)).multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .foregroundStyle(AppTheme.muted)
        .accessibilityElement(children: .combine)
    }
}
