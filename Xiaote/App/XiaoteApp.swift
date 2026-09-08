import SwiftUI

@main
struct XiaoteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var vehicle = VehicleController()
    @State private var fleetAccount = FleetAccountController()

    init() {
        AppDiagnostics.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--fleet-ui-tests") {
                FleetUITestHarness()
            } else {
                appContent
            }
            #else
            appContent
            #endif
        }
    }

    private var appContent: some View {
            RootView()
                .environment(vehicle)
                .environment(fleetAccount)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await vehicle.refreshAfterReturningToForeground()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        vehicle.noteAppMovedToBackground()
                    }
                }
                .task {
                    WatchBridge.shared.activate { request in
                        await vehicle.performWatchCommand(request)
                    }
                    vehicle.publishWatchState()
                }
    }
}
