import Foundation

enum WatchVehicleCommand: String, Codable, CaseIterable, Sendable {
    case lock, unlock, climate, flash, horn
}

struct WatchCommandRequest: Codable, Equatable, Sendable {
    let id: UUID
    let vehicleID: String
    let command: WatchVehicleCommand
    let issuedAt: Date

    func isValid(at now: Date) -> Bool {
        !vehicleID.isEmpty && now.timeIntervalSince(issuedAt) >= -5 && now.timeIntervalSince(issuedAt) < 90
    }
}

struct WatchCommandResult: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case accepted, succeeded, failed, unconfirmed }
    let id: UUID
    let vehicleID: String
    let status: Status
    let message: String

    init(request: WatchCommandRequest, status: Status, message: String) {
        id = request.id
        vehicleID = request.vehicleID
        self.status = status
        self.message = message
    }
}

struct WatchVehicleSnapshot: Codable, Equatable, Sendable {
    let vehicleID: String
    let name: String
    let battery: Int?
    let range: Double?
    let locked: Bool?
    let batteryUpdatedAt: Date?
    let rangeUpdatedAt: Date?
    let lockUpdatedAt: Date?
    let publishedAt: Date
}

/// Persisted before executing a command, so reconnecting/restarting the phone
/// cannot execute the same request twice within its acceptance window.
struct WatchCommandLedger: Codable {
    struct Entry: Codable {
        let request: WatchCommandRequest
        var result: WatchCommandResult
    }
    private(set) var entries: [Entry] = []

    mutating func accept(_ request: WatchCommandRequest, now: Date = .now) -> WatchCommandResult? {
        entries.removeAll { now.timeIntervalSince($0.request.issuedAt) >= 90 }
        guard request.isValid(at: now), entries.count < 32,
              !entries.contains(where: { $0.request.id == request.id }) else { return nil }
        let result = WatchCommandResult(request: request, status: .accepted, message: "手机已接收，正在执行")
        entries.append(Entry(request: request, result: result))
        return result
    }

    func previousResult(for request: WatchCommandRequest) -> WatchCommandResult? {
        entries.first(where: { $0.request == request })?.result
    }

    mutating func finish(_ result: WatchCommandResult) {
        guard let index = entries.firstIndex(where: { $0.request.id == result.id && $0.request.vehicleID == result.vehicleID }) else { return }
        entries[index].result = result
    }

    mutating func recoverInterruptedCommands() {
        for index in entries.indices where entries[index].result.status == .accepted {
            entries[index].result = WatchCommandResult(request: entries[index].request, status: .unconfirmed,
                                                       message: "手机连接中断，执行结果尚未确认，请在 iPhone 查看")
        }
    }
}

/// Ignores late acknowledgements and results belonging to another command/car.
struct WatchCommandTracking: Codable {
    private(set) var request: WatchCommandRequest?
    private(set) var result: WatchCommandResult?
    var isPending: Bool { request != nil && (result == nil || result?.status == .accepted) }

    mutating func begin(_ request: WatchCommandRequest) {
        self.request = request
        result = nil
    }

    mutating func receive(_ incoming: WatchCommandResult) {
        guard let request, incoming.id == request.id, incoming.vehicleID == request.vehicleID else { return }
        if let result {
            if result.status == .succeeded || result.status == .failed { return }
            if result.status != .accepted && incoming.status == .accepted { return }
        }
        result = incoming
    }

    mutating func selectVehicle(_ vehicleID: String) {
        if let request, request.vehicleID != vehicleID { self = WatchCommandTracking() }
    }

    mutating func markUnconfirmed() {
        guard isPending, let request else { return }
        result = WatchCommandResult(request: request, status: .unconfirmed,
                                    message: "暂未收到执行结果，请在 iPhone 查看，勿重复操作")
    }
}
