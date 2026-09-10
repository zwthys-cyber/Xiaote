import SwiftUI

struct RootView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(FleetAccountController.self) private var fleetAccount
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = AppTab.vehicle
    @State private var profilePath = NavigationPath()

    private enum AppTab: Hashable { case vehicle, functions, profile }

    var body: some View {
        @Bindable var vehicle = vehicle

        TabView(selection: $selectedTab) {
            NavigationStack {
                vehiclePage
            }
            .tabItem { Label("车辆", systemImage: "car.side.fill") }
            .tag(AppTab.vehicle)

            NavigationStack {
                FunctionsView(openVehicle: { selectedTab = .vehicle }, openProfile: { selectedTab = .profile })
            }
            // A destination must never keep controlling a previously selected vehicle.
            .id(vehicle.vehicleID)
            .tabItem { Label("功能", systemImage: "square.grid.2x2.fill") }
            .tag(AppTab.functions)

            NavigationStack(path: $profilePath) { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: vehicle.vehicleID) { _, _ in profilePath = NavigationPath() }
        .alert("操作失败", isPresented: $vehicle.showingError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(vehicle.errorMessage)
        }
        .fullScreenCover(isPresented: $vehicle.showingVehicleIdentity) {
            VehicleIdentityView()
                .environment(vehicle)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var vehiclePage: some View {
        Group {
            if vehicle.isPaired {
                VehicleControlView()
                    .transition(.opacity)
            } else if fleetAccount.isSignedIn {
                FleetHomeView()
                    .transition(.opacity)
            } else {
                PairVehicleView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? AppMotion.reduced : AppMotion.state, value: vehicle.isPaired)
        .animation(reduceMotion ? AppMotion.reduced : AppMotion.state, value: fleetAccount.isSignedIn)
    }
}
