import SwiftUI

struct FleetVehicleControlView: View {
    @State private var control: FleetRemoteController
    @State private var selectedCommand: FleetCommandDefinition?
    @State private var isPullRefreshing = false
    @Environment(\.dynamicTypeSize) private var typeSize

    init(account: FleetAccountController, vehicle: FleetVehicle) {
        _control = State(initialValue: FleetRemoteController(account: account, vehicle: vehicle))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                vehicleCard
                connectionNotice
                if let message = control.message {
                    Label(message, systemImage: "info.circle")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("remote-status-message")
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("常用控制", subtitle: "通过网络发送到这辆车")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(quickCommands) { command in
                            Button { selectedCommand = command } label: {
                                VStack(alignment: .leading, spacing: 16) {
                                    Image(systemName: command.symbol).font(.title2)
                                    Text(command.title).font(.subheadline.weight(.medium))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                .padding(16)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(UtilityPressStyle())
                            .disabled(!control.canControl || control.account.remoteCommandInFlight)
                            .accessibilityIdentifier("remote-quick-\(command.id)")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("全部功能", subtitle: "按类别设置与控制")
                    VStack(spacing: 0) {
                        ForEach(categories) { category in
                            NavigationLink {
                                FleetCommandCategoryView(control: control, category: category)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: category.symbol).font(.title3).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(category.rawValue).font(.body.weight(.medium))
                                        Text(category.subtitle).font(.caption).foregroundStyle(AppTheme.muted)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
                                }
                                .frame(minHeight: 52).padding(14).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("remote-category-\(category.id)")
                            if category != categories.last { Divider().overlay(AppTheme.hairline).padding(.leading, 56) }
                        }
                    }
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                NavigationLink {
                    FleetVehicleInfoView(fleetVehicle: control.currentVehicle)
                        .environment(control.account)
                } label: {
                    Label("车辆信息与软件版本", systemImage: "info.circle")
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 22).padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .appDestinationPage(title: control.currentVehicle.name)
        .tint(.white)
        .refreshable {
            isPullRefreshing = true
            defer { isPullRefreshing = false }
            await control.refresh()
        }
        .task {
            if control.data == nil { await control.refresh() }
            await control.account.loadCloudDetails(for: control.vehicle.vin)
        }
        .onChange(of: control.account.isSignedIn) { _, signedIn in if !signedIn { control.clear() } }
        .sheet(item: $selectedCommand) { command in
            FleetCommandSheet(control: control, command: command)
        }
    }

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2) }
    private var quickCommands: [FleetCommandDefinition] {
        ["door_lock", "door_unlock", "auto_conditioning_start", "actuate_trunk"].compactMap { id in FleetControlForm.commands.first { $0.id == id } }
    }
    private var categories: [FleetCommandDefinition.Category] {
        FleetCommandDefinition.Category.allCases.filter { category in FleetControlForm.commands.contains { $0.category == category } }
    }

    private var vehicleCard: some View {
        HairlinePanel {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("账号远程控制", systemImage: "network").font(.caption.weight(.medium)).foregroundStyle(AppTheme.muted)
                        Text(control.currentVehicle.name).font(.title2.weight(.semibold))
                        Text("•••• \(control.vehicle.vin.suffix(4))").font(.caption.monospacedDigit()).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "car.side.fill").font(.system(size: 40, weight: .light)).foregroundStyle(.white.opacity(0.8)).accessibilityHidden(true)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    metric("电量", value: control.data?.chargeState?.batteryLevel.map { "\($0)%" } ?? "—", icon: "battery.75percent")
                    metric("续航", value: control.data?.chargeState?.batteryRange.map { "\(Int(($0 * 1.609344).rounded())) km" } ?? "—", icon: "road.lanes")
                    metric("门锁", value: control.data?.vehicleState?.locked.map { $0 ? "已锁定" : "未锁定" } ?? "—", icon: "lock")
                    metric("车内温度", value: control.data?.climateState?.insideTemp.map { String(format: "%.1f °C", $0) } ?? "—", icon: "thermometer.medium")
                }
                if control.isRefreshing && !isPullRefreshing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在读取车辆状态").font(.caption).foregroundStyle(AppTheme.muted)
                    }.accessibilityIdentifier("remote-initial-loading")
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(freshness(at: context.date)).font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }

    @ViewBuilder private var connectionNotice: some View {
        if control.account.needsReauthentication {
            VStack(alignment: .leading, spacing: 10) {
                Label("账号授权已失效", systemImage: "person.crop.circle.badge.exclamationmark").font(.headline)
                Button("重新登录") { Task { await control.account.signIn() } }.disabled(control.account.isWorking)
            }
        } else if control.account.mobileAccess[control.vehicle.vin.uppercased()] == false {
            Label("请在车机中开启“允许手机访问”后，再使用远程控制。", systemImage: "iphone.slash").font(.subheadline)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(control.currentVehicle.state == "online" ? "车辆在线" : "车辆可能处于休眠或离线状态", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { Task { await control.wake() } } label: {
                        Group {
                            if control.isWaking { ProgressView() }
                            else { Text("唤醒") }
                        }.frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(!control.canControl || control.account.remoteCommandInFlight)
                    .accessibilityLabel("唤醒车辆")
                }
                NavigationLink { FleetRemoteSetupView() } label: {
                    Label("首次使用？设置远程控制", systemImage: "key.horizontal")
                        .font(.caption).foregroundStyle(AppTheme.muted).frame(minHeight: 44)
                }
            }
        }
    }

    private func freshness(at now: Date) -> String {
        guard let date = control.updatedAt else { return "尚未读取到状态 · 下拉刷新" }
        let prefix = now.timeIntervalSince(date) > 120 ? "状态可能已过期" : "最近读取"
        return "\(prefix) · \(date.formatted(date: .omitted, time: .shortened))"
    }
    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(AppTheme.muted)
            Text(value).font(.title3.weight(.medium)).monospacedDigit().accessibilityIdentifier("remote-metric-\(title)")
        }.accessibilityElement(children: .combine)
    }
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(AppTheme.muted)
        }
    }
}

struct FleetCommandCategoryView: View {
    let control: FleetRemoteController
    let category: FleetCommandDefinition.Category
    @State private var selectedCommand: FleetCommandDefinition?

    var body: some View {
        List {
            Section {
                ForEach(FleetControlForm.commands.filter { $0.category == category }) { command in
                    Button { selectedCommand = command } label: {
                        HStack(spacing: 14) {
                            Image(systemName: command.symbol).frame(width: 28).font(.title3)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(command.title).font(.body.weight(.medium))
                                Text(command.summary).font(.caption).foregroundStyle(AppTheme.muted)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
                        }.frame(minHeight: 52).contentShape(Rectangle())
                    }
                    .disabled(!control.canControl || control.account.remoteCommandInFlight)
                    .listRowBackground(AppTheme.surface)
                    .accessibilityIdentifier("remote-command-\(command.id)")
                }
            } footer: {
                Text("操作对象：\(control.vehicle.name) · \(control.vehicle.vin.suffix(4))。部分功能需要对应车辆配置或停车状态。")
            }
        }
        .scrollContentBackground(.hidden)
        .appDestinationPage(title: category.rawValue)
        .tint(.white)
        .sheet(item: $selectedCommand) { FleetCommandSheet(control: control, command: $0) }
    }
}

private extension FleetCommandDefinition.Category {
    var symbol: String {
        switch self {
        case .access: "lock"; case .charging: "bolt"; case .climate: "fan"
        case .media: "music.note"; case .navigation: "map"; case .security: "shield"
        case .scheduling: "calendar"; case .maintenance: "car.side"
        }
    }
    var subtitle: String {
        switch self {
        case .access: "门锁、行李厢与寻车"; case .charging: "充电口、电量上限与电流"
        case .climate: "温度、座椅与保持模式"; case .media: "播放、切歌与音量"
        case .navigation: "把目的地发送到车机"; case .security: "哨兵与驾驶授权"
        case .scheduling: "定时开始充电"; case .maintenance: "车辆名称与软件更新"
        }
    }
}

private struct FleetRemoteSetupView: View {
    var body: some View {
        List {
            Section("连接车辆") {
                Label("使用车辆所属或获授权的 Tesla 账号登录。", systemImage: "person.crop.circle")
                Label("在车机设置中开启“允许手机访问”。", systemImage: "iphone")
                Label("首次控制时，为车辆添加小特虚拟钥匙，并按 Tesla 提示完成授权。", systemImage: "key.horizontal")
                Link("添加小特虚拟钥匙", destination: URL(string: "https://tesla.cn/_ak/api.txx.app")!)
            }
            Section("使用提示") {
                Text("手机与车辆需要联网。休眠车辆可以先唤醒，再下拉读取状态。")
                Text("远程控制不会替代蓝牙手机钥匙；无感进入仍需添加本地蓝牙钥匙。")
                Text("只有车辆支持的功能才能执行。未配备的座椅通风、天窗等功能会返回不可用原因。")
            }
        }
        .scrollContentBackground(.hidden)
        .appDestinationPage(title: "设置远程控制")
    }
}
