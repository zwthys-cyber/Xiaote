import AppIntents
import Foundation

private enum ShortcutError: LocalizedError {
    case commandFailed

    var errorDescription: String? {
        "车辆没有确认操作，请靠近车辆并打开小特蓝牙钥匙后重试。"
    }
}

struct LockVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "锁定 Tesla"
    static var description = IntentDescription("通过本地蓝牙锁定已配对车辆。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        let started = Date()
        guard await controller.lock(), controller.isLocked == true,
              let updated = controller.stateFreshness.dates[.lock], updated >= started else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆已锁定")
    }
}

struct UnlockVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "解锁 Tesla"
    static var description = IntentDescription("通过本地蓝牙解锁已配对车辆。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        let started = Date()
        guard await controller.unlock(), controller.isLocked == false,
              let updated = controller.stateFreshness.dates[.lock], updated >= started else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆已解锁")
    }
}

struct ClimateVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "开启 Tesla 空调"
    static var description = IntentDescription("通过本地蓝牙开启已配对车辆的空调。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        let started = Date()
        guard await controller.setClimateEnabled(true), controller.isClimateOn,
              let updated = controller.stateFreshness.dates[.climateEnabled], updated >= started else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆空调已开启")
    }
}

struct StartChargingVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "开始 Tesla 充电"
    static var description = IntentDescription("通过本地蓝牙开始为已配对车辆充电。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        if !controller.isCharging { await controller.toggleCharging() }
        guard controller.isCharging else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆已开始充电")
    }
}

struct FlashVehicleLightsIntent: AppIntent {
    static var title: LocalizedStringResource = "Tesla 闪灯"
    static var description = IntentDescription("通过本地蓝牙让已配对车辆闪灯。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        guard await controller.flashLights() else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆已闪灯")
    }
}

struct HonkVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "Tesla 鸣笛"
    static var description = IntentDescription("通过本地蓝牙让已配对车辆鸣笛。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let controller = VehicleController(managesPassiveKey: false)
        defer { controller.disconnect() }
        try await controller.connect()
        guard await controller.honk() else { throw ShortcutError.commandFailed }
        return .result(dialog: "车辆已鸣笛")
    }
}

struct TeslaVehicleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LockVehicleIntent(),
            phrases: ["用 \(.applicationName) 锁车", "让 \(.applicationName) 锁定车辆"],
            shortTitle: "锁车",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: UnlockVehicleIntent(),
            phrases: ["用 \(.applicationName) 解锁车辆"],
            shortTitle: "解锁",
            systemImageName: "lock.open.fill"
        )
        AppShortcut(
            intent: ClimateVehicleIntent(),
            phrases: ["用 \(.applicationName) 开启空调"],
            shortTitle: "开启空调",
            systemImageName: "fan.fill"
        )
        AppShortcut(
            intent: StartChargingVehicleIntent(),
            phrases: ["用 \(.applicationName) 开始充电"],
            shortTitle: "开始充电",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: FlashVehicleLightsIntent(),
            phrases: ["用 \(.applicationName) 闪灯", "让 \(.applicationName) 找车"],
            shortTitle: "闪灯",
            systemImageName: "light.beacon.max"
        )
        AppShortcut(
            intent: HonkVehicleIntent(),
            phrases: ["用 \(.applicationName) 鸣笛"],
            shortTitle: "鸣笛",
            systemImageName: "speaker.wave.2.fill"
        )
    }
}
