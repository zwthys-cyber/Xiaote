#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Simulator-only launch fixture. All requests are intercepted, including
/// unknown routes. UI tests can never issue a real vehicle command.
struct FleetUITestHarness: View {
    @State private var account: FleetAccountController
    @State private var ready = false
    @State private var localVehicle: VehicleController
    private let emptyAccount: Bool
    private let largeText: Bool
    private let localHome: Bool
    private let english: Bool
    private let pairing: Bool

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FleetUITestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let isPairing = ProcessInfo.processInfo.arguments.contains("--pairing")
        _account = State(initialValue: FleetAccountController(
            api: FleetAPIClient(session: session),
            restoredSession: isPairing ? nil : FleetSession(token: "ui-test-only", expiresAt: .distantFuture), usesKeychain: false
        ))
        emptyAccount = ProcessInfo.processInfo.arguments.contains("--empty-account")
        largeText = ProcessInfo.processInfo.arguments.contains("--large-text")
        localHome = ProcessInfo.processInfo.arguments.contains("--local-home")
        english = ProcessInfo.processInfo.arguments.contains("--english")
        pairing = isPairing
        let local = VehicleController(managesPassiveKey: false)
        local.vehicleID = "S0123456789abcdefC"
        local.isPaired = true
        local.phase = isPairing ? .idle : .connected
        local.customVehicleName = "小特 Model 3"
        local.passiveKeyOnline = true
        local.batteryLevel = 76
        local.estimatedRangeKilometers = 339
        local.isLocked = true
        local.cabinTemperature = 23.5
        local.chargingStatus = "未充电"
        local.chargeLimit = 80
        local.stateFreshness.record(.battery)
        local.stateFreshness.record(.range)
        local.stateFreshness.record(.lock)
        local.automationScenes = [.init(id: UUID(), name: "离车", symbol: "figure.walk.departure", actions: [.lock, .sentry])]
        _localVehicle = State(initialValue: local)
    }

    var body: some View {
        Group {
            if ready {
                if pairing {
                    NavigationStack { PairVehicleView(automaticallyScans: false) }
                        .environment(localVehicle).environment(account)
                } else if localHome {
                    NavigationStack { VehicleControlView() }
                        .environment(localVehicle).environment(account)
                } else if emptyAccount { TeslaAccountView().environment(account) }
                else if let vehicle = account.vehicles.first {
                    NavigationStack { FleetVehicleControlView(account: account, vehicle: vehicle) }
                }
            } else { ProgressView() }
        }
        .environment(\.locale, Locale(identifier: english ? "en_US" : "zh_Hans_CN"))
        .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
        .preferredColorScheme(.dark)
        .task {
            // The account page owns its initial load; preloading it here would
            // add a second artificial network delay before the gesture test.
            if !emptyAccount { await account.refreshVehicles() }
            ready = true
        }
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
            delay = args.contains("--empty-account") ? 1 : 0.1
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
