#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Simulator-only launch fixture. All requests are intercepted, including
/// unknown routes. UI tests can never issue a real vehicle command.
struct FleetUITestHarness: View {
    @State private var account: FleetAccountController
    @State private var ready = false
    private let emptyAccount: Bool
    private let largeText: Bool

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FleetUITestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        _account = State(initialValue: FleetAccountController(
            api: FleetAPIClient(session: session),
            restoredSession: FleetSession(token: "ui-test-only", expiresAt: .distantFuture), loadStoredSession: false
        ))
        emptyAccount = ProcessInfo.processInfo.arguments.contains("--empty-account")
        largeText = ProcessInfo.processInfo.arguments.contains("--large-text")
    }

    var body: some View {
        Group {
            if ready {
                if emptyAccount { TeslaAccountView().environment(account) }
                else if let vehicle = account.vehicles.first {
                    NavigationStack { FleetVehicleControlView(account: account, vehicle: vehicle) }
                }
            } else { ProgressView() }
        }
        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
        .preferredColorScheme(.dark)
        .task { await account.refreshVehicles(); ready = true }
    }
}

private final class FleetUITestURLProtocol: URLProtocol {
    private var work: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let args = ProcessInfo.processInfo.arguments
        let vehicle = #"{"id":1,"vin":"LRW3E7FA9MC123456","display_name":"小特 Model 3","state":"online"}"#
        let body: String
        var status = 200
        var delay = 0.1
        if path == "/v1/vehicles" {
            body = args.contains("--empty-account") ? #"{"response":[]}"# : "{\"response\":[\(vehicle)]}"
            delay = args.contains("--empty-account") ? 2 : 0.1
        } else if path.hasSuffix("/data") {
            if args.contains("--data-failure") {
                status = 408; body = #"{"error":{"message":"vehicle unavailable"}}"#
            } else {
                body = #"{"response":{"vin":"LRW3E7FA9MC123456","charge_state":{"battery_level":76,"battery_range":210.5,"charging_state":"Stopped","charge_limit_soc":80},"climate_state":{"inside_temp":23.5,"outside_temp":19,"is_climate_on":false},"vehicle_state":{"locked":true,"sentry_mode":true}}}"#
            }
            delay = 2
        } else if path.contains("/commands/") {
            body = args.contains("--command-failure") ? #"{"response":{"result":false,"reason":"车辆未连接充电线。"}}"# : #"{"response":{"result":true}}"#
            delay = 1
        } else if path.hasSuffix("/wake") { body = "{\"response\":\(vehicle)}" }
        else if path.hasSuffix("/mobile-enabled") { body = #"{"response":true}"# }
        else { status = 404; body = #"{"error":{"message":"UI fixture: unsupported optional route"}}"# }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    override func stopLoading() { work?.cancel(); work = nil }
}
#endif
