import Foundation
import WatchConnectivity

@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var commandHandler: ((WatchCommandRequest) async -> WatchCommandResult)?
    private var snapshot: WatchVehicleSnapshot?
    private var latestResult: WatchCommandResult?
    private var ledger = WatchCommandLedger()
    private var ledgerURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watch-command-ledger-v2.json")
    }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: ledgerURL),
           let stored = try? JSONDecoder().decode(WatchCommandLedger.self, from: data) {
            ledger = stored
            ledger.recoverInterruptedCommands()
            latestResult = ledger.entries.last?.result
            persistLedger()
        }
    }

    func activate(commandHandler: @escaping (WatchCommandRequest) async -> WatchCommandResult) {
        self.commandHandler = commandHandler
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func publish(_ snapshot: WatchVehicleSnapshot) {
        self.snapshot = snapshot
        publishContext()
    }

    private var context: [String: Any] {
        var value: [String: Any] = [:]
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) { value["snapshotV2"] = data }
        if let latestResult, let data = try? JSONEncoder().encode(latestResult) { value["resultV2"] = data }
        return value
    }

    private func publishContext() {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(context)
    }

    @discardableResult
    private func persistLedger() -> Bool {
        do {
            try FileManager.default.createDirectory(at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(ledger).write(to: ledgerURL, options: .atomic)
            return true
        } catch { return false }
    }

    private func envelope(_ result: WatchCommandResult) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(result) else { return ["accepted": false] }
        return ["resultV2": data]
    }

    private func receive(_ message: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        if message["syncV2"] as? Bool == true {
            var response = context
            if let data = message["pendingRequestV2"] as? Data,
               let request = try? JSONDecoder().decode(WatchCommandRequest.self, from: data),
               let result = ledger.previousResult(for: request) {
                response.merge(envelope(result)) { _, new in new }
            }
            reply(response)
            return
        }
        guard let data = message["commandV2"] as? Data,
              let request = try? JSONDecoder().decode(WatchCommandRequest.self, from: data) else {
            // Old watch versions must upgrade before sending controls.
            reply(["accepted": false]); return
        }
        if let existing = ledger.previousResult(for: request) { reply(envelope(existing)); return }
        guard let commandHandler, request.isValid(at: .now),
              snapshot?.vehicleID == request.vehicleID else {
            reply(envelope(WatchCommandResult(request: request, status: .failed,
                                              message: "车辆已切换或请求已过期，请刷新后重试")))
            return
        }
        guard let accepted = ledger.accept(request) else {
            reply(envelope(WatchCommandResult(request: request, status: .failed,
                                              message: "请求未接收，请稍后重试")))
            return
        }
        guard persistLedger() else {
            let failed = WatchCommandResult(request: request, status: .failed, message: "手机暂时无法接收操作，请在 iPhone 查看")
            ledger.finish(failed)
            reply(envelope(failed))
            return
        }
        reply(envelope(accepted))
        Task {
            let result = await commandHandler(request)
            ledger.finish(result)
            persistLedger()
            latestResult = result
            publishContext()
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(envelope(result), replyHandler: nil, errorHandler: { _ in })
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in self.receive(message, reply: replyHandler) }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.publishContext() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.publishContext() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
