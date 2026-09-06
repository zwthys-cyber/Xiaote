import SwiftUI

struct WatchControlView: View {
    @EnvironmentObject private var bridge: WatchPhoneBridge
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(bridge.snapshot?.name ?? "等待车辆信息").font(.headline).lineLimit(2)
                Text(LocalizedStringKey(bridge.connectionMessage)).font(.caption2).foregroundStyle(.secondary)
                if let snapshot = bridge.snapshot {
                    HStack {
                        if let battery = snapshot.battery { Label("\(battery)%", systemImage: "battery.75percent") }
                        if let range = snapshot.range { Text("\(Int(range)) km") }
                    }.font(.caption).monospacedDigit()
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        VStack(spacing: 3) {
                            let lockFresh = VehicleDataAge.isFresh(snapshot.lockUpdatedAt, at: timeline.date)
                            Text(lockFresh && snapshot.locked != nil ? (snapshot.locked == true ? "车辆已锁定" : "车辆未锁定") : "门锁状态待刷新")
                            if (snapshot.battery != nil && !VehicleDataAge.isFresh(snapshot.batteryUpdatedAt, at: timeline.date))
                                || (snapshot.range != nil && !VehicleDataAge.isFresh(snapshot.rangeUpdatedAt, at: timeline.date)) {
                                Text("电量或续航为旧数据")
                            }
                            if let date = snapshot.batteryUpdatedAt {
                                HStack(spacing: 3) {
                                    Text("电量数据：")
                                    Text(date, style: .relative)
                                }
                            }
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                // Explicit actions never invert based on an old lock snapshot.
                HStack {
                    Button { bridge.send(.lock) } label: { Label("锁车", systemImage: "lock.fill").frame(minHeight: 44) }
                    Button { bridge.send(.unlock) } label: { Label("解锁", systemImage: "lock.open.fill").frame(minHeight: 44) }
                }
                .disabled(!bridge.canSend)
                HStack {
                    control(.climate, label: "开启空调", symbol: "fan.fill")
                    control(.flash, label: "闪灯", symbol: "light.beacon.max")
                    control(.horn, label: "鸣笛", symbol: "speaker.wave.2.fill")
                }.disabled(!bridge.canSend)
                if bridge.tracking.isPending { ProgressView().controlSize(.small).accessibilityLabel("等待车辆执行") }
                Text(LocalizedStringKey(bridge.status)).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("刷新连接") { bridge.refreshConnection() }.font(.caption)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { bridge.refreshConnection() }
        }
    }

    private func control(_ command: WatchVehicleCommand, label: String, symbol: String) -> some View {
        Button { bridge.send(command) } label: {
            Image(systemName: symbol).frame(minHeight: 44)
        }
        .accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}
