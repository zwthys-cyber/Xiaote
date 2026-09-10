import SwiftUI

/// Each destination uses the app's shared controllers. Browsing never sends a command.
struct FunctionsView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(FleetAccountController.self) private var account
    let openVehicle: () -> Void
    let openProfile: () -> Void

    var body: some View {
        List {
            if vehicle.isPaired {
                Section {
                    NavigationLink { ChargingControlView() } label: {
                        FunctionRow("充电", subtitle: "充电口、电量上限与电流", symbol: "bolt")
                    }.accessibilityIdentifier("functions-charging")
                    NavigationLink { CabinControlView() } label: {
                        FunctionRow("座舱", subtitle: "温度、座椅与保持模式", symbol: "fan")
                    }
                    NavigationLink { SentryControlView() } label: {
                        FunctionRow("哨兵", subtitle: "停车守护与安全", symbol: "shield")
                    }
                } header: {
                    Text("蓝牙控制")
                } footer: {
                    Text(vehicle.displayVehicleName)
                }
                .listRowBackground(AppTheme.surface)

                Section("出行与自动化") {
                    NavigationLink { AutomationScenesView() } label: {
                        FunctionRow("场景", subtitle: "组合常用车辆操作", symbol: "sparkles")
                    }.accessibilityIdentifier("functions-scenes")
                    NavigationLink { VehicleSchedulesView() } label: {
                        FunctionRow("预约", subtitle: "充电与出发计划", symbol: "calendar.badge.clock")
                    }
                    NavigationLink { NearbyChargingSitesView() } label: {
                        FunctionRow("充电站", subtitle: "查找附近的充电位置", symbol: "bolt.car")
                    }
                }
                .listRowBackground(AppTheme.surface)
            } else {
                Section {
                    Button(action: openVehicle) {
                        FunctionRow("添加蓝牙钥匙", subtitle: "配对车辆后使用近场控制", symbol: "key.horizontal")
                    }.accessibilityIdentifier("functions-add-key")
                }.listRowBackground(AppTheme.surface)
            }

            Section {
                ForEach(account.vehicles) { fleetVehicle in
                    NavigationLink {
                        FleetVehicleControlView(account: account, vehicle: fleetVehicle)
                    } label: {
                        FunctionRow(fleetVehicle.name, subtitle: "•••• \(fleetVehicle.vin.suffix(4))", symbol: "car.side")
                    }.accessibilityIdentifier("functions-remote-\(fleetVehicle.id)")
                }
                if account.vehicles.isEmpty {
                    Button(action: openProfile) {
                        FunctionRow(account.isSignedIn ? "管理账号" : "连接 Tesla 账号",
                                    subtitle: "查看账号车辆与远程功能", symbol: "person.crop.circle")
                    }.accessibilityIdentifier("functions-account")
                }
            } header: {
                Text("远程控制")
            } footer: {
                Text("选择车辆后使用门锁、空调、媒体与导航等功能。")
            }
            .listRowBackground(AppTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .appDestinationPage(title: NSLocalizedString("功能", comment: ""))
    }
}

struct FunctionRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    init(_ title: String, subtitle: String, symbol: String) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(title)).font(.body.weight(.medium))
                Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(AppTheme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
