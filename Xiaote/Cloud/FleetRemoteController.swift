import Foundation
import Observation

@MainActor
@Observable
final class FleetRemoteController {
    let account: FleetAccountController
    let vehicle: FleetVehicle
    private(set) var data: FleetVehicleData?
    private(set) var updatedAt: Date?
    private(set) var isRefreshing = false
    private(set) var isWaking = false
    var message: String?

    init(account: FleetAccountController, vehicle: FleetVehicle) {
        self.account = account
        self.vehicle = vehicle
    }

    var currentVehicle: FleetVehicle {
        account.vehicles.first { $0.vin.uppercased() == vehicle.vin.uppercased() } ?? vehicle
    }

    var canControl: Bool {
        account.isSignedIn && !account.needsReauthentication &&
        account.vehicles.contains { $0.vin.uppercased() == vehicle.vin.uppercased() } &&
        account.mobileAccess[vehicle.vin.uppercased()] != false
    }

    func refresh() async {
        guard !isRefreshing, account.isSignedIn else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let value = try await account.readVehicleData(for: vehicle.vin)
            guard value.vin == nil || value.vin?.uppercased() == vehicle.vin.uppercased() else {
                throw FleetAPIError.server("车辆状态与当前车辆不匹配，请重新打开车辆页面。")
            }
            data = value
            updatedAt = .now
            message = nil
        } catch {
            if !Self.isCancellation(error) { message = Self.describe(error) }
        }
    }

    func wake() async {
        guard canControl, !isWaking, !account.remoteCommandInFlight else { return }
        isWaking = true
        defer { isWaking = false }
        do {
            let response = try await account.wakeVehicle(vehicle)
            if response.state == "online" { await refresh() }
            else { message = "唤醒请求已发送，车辆上线后请下拉刷新。" }
        } catch {
            if !Self.isCancellation(error) { message = Self.describe(error) }
        }
    }

    func clear() { data = nil; updatedAt = nil; message = nil }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError, [.timedOut, .networkConnectionLost].contains(urlError.code) {
            return "连接中断，结果尚未确认。请先刷新车辆状态，再决定是否重试。"
        }
        if case FleetAPIError.http(let status, _, _) = error {
            switch status {
            case 403: return "车辆未授权此操作。请检查账号权限，并确认已添加小特虚拟钥匙。"
            case 408: return "车辆暂未响应。请先唤醒车辆，再重试。"
            case 429: return "操作过于频繁，请稍后再试。"
            case 502...504: return "远程服务暂未返回结果。请先检查车辆状态，不要连续重复操作。"
            default: break
            }
        }
        let explanations = [
            "not_in_park": "请先将车辆停稳并挂入 P 挡。",
            "vehicle unavailable": "车辆暂未响应。请先唤醒车辆，再重试。",
            "vehicle_unavailable": "车辆暂未响应。请先唤醒车辆，再重试。",
            "disconnected": "车辆未连接充电线，请连接后再开始充电。",
            "not_charging": "车辆当前没有在充电，无需停止。",
            "already_started": "车辆已在充电，请刷新查看最新状态。",
            "is_charging": "车辆已在充电，请刷新查看最新状态。",
            "complete": "车辆已达到充电目标。",
            "no_power": "充电设备没有供电，请检查电源和充电连接。",
            "user_not_present": "此操作需要车内有人，请进入车辆后重试。",
            "invalid_command": "当前远程服务尚未支持这个功能。",
            "command not implemented": "当前远程服务尚未支持这个功能。",
            "key_not_whitelisted": "请先在车辆中添加小特虚拟钥匙。"
        ]
        if let explanation = explanations[error.localizedDescription.lowercased()] {
            return NSLocalizedString(explanation, comment: "")
        }
        return error.localizedDescription
    }
}
