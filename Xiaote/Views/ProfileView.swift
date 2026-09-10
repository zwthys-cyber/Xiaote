import SwiftUI

struct ProfileView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(FleetAccountController.self) private var account
    @State private var showingAccount = false
    @State private var showingSecurity = false
    @State private var showingAlerts = false
    @State private var showingPairing = false

    var body: some View {
        List {
            Section {
                Button {
                    account.errorMessage = nil
                    showingAccount = true
                } label: {
                    HStack(spacing: 14) {
                        TeslaAccountAvatar(profile: account.profile, size: 52)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(account.profile?.displayName ?? NSLocalizedString("Tesla 账号", comment: ""))
                                .font(.headline)
                            Text(account.isSignedIn ? "管理账号" : "连接 Tesla 账号")
                                .font(.subheadline).foregroundStyle(AppTheme.muted)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
                    }.padding(.vertical, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-account")
            }.listRowBackground(AppTheme.surface)

            Section("车辆与钥匙") {
                if vehicle.isPaired {
                    NavigationLink { VehicleDetailView() } label: {
                        Label("车辆详情", systemImage: "car.side").frame(minHeight: 44)
                    }
                    Button { showingSecurity = true } label: {
                        Label("Face ID 保护", systemImage: "faceid").frame(minHeight: 44)
                    }.accessibilityIdentifier("profile-security")
                    Button { showingAlerts = true } label: {
                        Label("车辆提醒", systemImage: "bell").frame(minHeight: 44)
                    }
                    NavigationLink { VehicleDiagnosticsView() } label: {
                        Label("诊断", systemImage: "waveform.path.ecg").frame(minHeight: 44)
                    }
                }
                Button {
                    vehicle.prepareForVehicleAddition()
                    showingPairing = true
                } label: {
                    Label("添加蓝牙钥匙", systemImage: "plus.circle").frame(minHeight: 44)
                }.accessibilityIdentifier("profile-add-key")
            }.listRowBackground(AppTheme.surface)

            Section("关于小特") {
                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .frame(minHeight: 44)
            }.listRowBackground(AppTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .appDestinationPage(title: NSLocalizedString("我的", comment: ""))
        .fullScreenCover(isPresented: $showingAccount) { TeslaAccountView() }
        .sheet(isPresented: $showingSecurity) { SecuritySettingsView() }
        .fullScreenCover(isPresented: $showingAlerts) { VehicleAlertsView() }
        .fullScreenCover(isPresented: $showingPairing, onDismiss: {
            Task { await vehicle.finishVehicleAdditionSheet() }
        }) {
            NavigationStack { PairVehicleView(showsCloseButton: true) }
        }
    }
}
