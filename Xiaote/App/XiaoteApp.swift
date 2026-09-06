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
}
