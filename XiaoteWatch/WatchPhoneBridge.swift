import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchPhoneBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchVehicleSnapshot?
    @Published private(set) var tracking = WatchCommandTracking() {
        didSet {
            if let data = try? JSONEncoder().encode(tracking) { UserDefaults.standard.set(data, forKey: "watch.tracking.v2") }
        }
    }
    @Published private(set) var isReachable = false
    @Published private(set) var connectionMessage = "正在连接 iPhone"
    private var timeoutTask: Task<Void, Never>?

    var canSend: Bool { isReachable && snapshot?.vehicleID.isEmpty == false && !tracking.isPending }
    var status: String { tracking.result?.message ?? (tracking.isPending ? "正在发送" : connectionMessage) }

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: "watch.tracking.v2"),
           let stored = try? JSONDecoder().decode(WatchCommandTracking.self, from: data) {
            tracking = stored
            tracking.markUnconfirmed()
        }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    func send(_ command: WatchVehicleCommand) {
        guard canSend, let snapshot else { return }
        let request = WatchCommandRequest(id: UUID(), vehicleID: snapshot.vehicleID, command: command, issuedAt: .now)
        guard let data = try? JSONEncoder().encode(request) else { return }
        tracking.begin(request)
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            guard let self, self.tracking.request?.id == request.id else { return }
            self.tracking.markUnconfirmed()
        }
        WCSession.default.sendMessage(["commandV2": data], replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if reply["resultV2"] == nil, self.tracking.request?.id == request.id {
                    self.tracking.receive(WatchCommandResult(request: request, status: .failed,
                                                             message: "请更新 iPhone 上的小特后重试"))
                    self.timeoutTask?.cancel()
                } else { self.receive(reply) }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                guard let self, self.tracking.request?.id == request.id else { return }
                self.tracking.markUnconfirmed()
                self.timeoutTask?.cancel()
            }
        })
    }

    func refreshConnection() {
        isReachable = WCSession.default.isReachable
        connectionMessage = isReachable ? "iPhone 可达" : "请保持 iPhone 在附近"
        guard isReachable else { return }
        var request: [String: Any] = ["syncV2": true]
        if let current = tracking.request, let data = try? JSONEncoder().encode(current) { request["pendingRequestV2"] = data }
        WCSession.default.sendMessage(request, replyHandler: { [weak self] context in
            Task { @MainActor in self?.receive(context) }
        }, errorHandler: { _ in })
    }

    private func receive(_ context: [String: Any]) {
        if let data = context["snapshotV2"] as? Data,
           let incoming = try? JSONDecoder().decode(WatchVehicleSnapshot.self, from: data),
           snapshot == nil || incoming.publishedAt >= snapshot!.publishedAt {
            tracking.selectVehicle(incoming.vehicleID)
            if !tracking.isPending { timeoutTask?.cancel() }
            snapshot = incoming
        }
        if let data = context["resultV2"] as? Data,
           let result = try? JSONDecoder().decode(WatchCommandResult.self, from: data) {
            tracking.receive(result)
            if !tracking.isPending { timeoutTask?.cancel() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(applicationContext) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.receive(message) }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.receive(context); self.refreshConnection() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshConnection() }
    }
#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
#endif
}
