import AuthenticationServices
import Observation
import Security
import UIKit

@MainActor
@Observable
final class FleetAccountController: NSObject {
    private(set) var session: FleetSession?
    private(set) var profile: FleetAccountProfile?
    private(set) var region: FleetAccountRegion?
    private(set) var energyProducts: [FleetEnergyProduct] = []
    private(set) var vehicleSpecs: [String: FleetVehicleSpecs] = [:]
    private(set) var releaseNotes: [String: FleetReleaseNotes] = [:]
    private(set) var driverCounts: [String: Int] = [:]
    private(set) var invitationCounts: [String: Int] = [:]
    private(set) var mobileAccess: [String: Bool] = [:]
    private(set) var recentAlerts: [String: [FleetVehicleAlert]] = [:]
    private(set) var nearbyChargingSites: [String: [FleetNearbyChargingSites.Site]] = [:]
    private(set) var vehicles: [FleetVehicle] = []
    private(set) var isWorking = false
    var errorMessage: String?

    enum ConnectionState {
        case notConnected, checking, available, unavailable, reauthorizationRequired
        var title: String {
            switch self {
            case .notConnected: "尚未连接 Tesla 账号"
            case .checking: "正在检查远程连接"
            case .available: "远程连接可用"
            case .unavailable: "远程连接暂不可用"
            case .reauthorizationRequired: "Tesla 授权已失效"
            }
        }
    }
    private(set) var connectionState: ConnectionState = .notConnected
    var needsReauthentication: Bool { connectionState == .reauthorizationRequired }
    private var accountGeneration = UUID()
    private let api: FleetAPIClient
    private var authenticationSession: ASWebAuthenticationSession?
    private let keychain = FleetSessionKeychain()

    init(api: FleetAPIClient = .shared) {
        self.api = api
        session = try? keychain.load()
        super.init()
        if let session {
            connectionState = session.expiresAt <= Date() ? .reauthorizationRequired : .checking
        }
    }

    var isSignedIn: Bool { session != nil }

    func signIn() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        let generation = UUID()
        accountGeneration = generation
        let previousState = connectionState
        connectionState = .checking
        defer {
            if accountGeneration == generation {
                authenticationSession = nil
                isWorking = false
                if connectionState == .checking { connectionState = previousState }
            }
        }
        do {
            let authorizationURL = try await api.authorizationURL()
            guard accountGeneration == generation, !Task.isCancelled else { return }
            let callbackURL = try await authenticate(at: authorizationURL)
            guard accountGeneration == generation, !Task.isCancelled else { return }
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                throw FleetAPIError.missingCallbackCode
            }
            if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                throw FleetAPIError.server("Tesla 授权失败：\(error)")
            }
            guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
                throw FleetAPIError.missingCallbackCode
            }
            let newSession = try await api.exchange(code: code)
            guard accountGeneration == generation, !Task.isCancelled else {
                try? await api.logout(token: newSession.token)
                return
            }
            try keychain.save(newSession)
            session = newSession
            let remoteVehicles = try await api.vehicles(token: newSession.token)
            guard accountGeneration == generation, !Task.isCancelled else { return }
            apply(remoteVehicles: remoteVehicles)
            connectionState = .available
            await loadAccountExtras()
        } catch {
            guard accountGeneration == generation else { return }
            if let authenticationError = error as? ASWebAuthenticationSessionError,
               authenticationError.code == .canceledLogin {
                // Cancellation is an intentional user action, not an app error.
            } else if !Self.isCancellation(error) {
                handleAccountError(error)
            }
        }
    }

    func refreshVehicles() async {
        await refreshAccount()
    }

    func refreshAccount() async {
        guard let session, !isWorking, !needsReauthentication else { return }
        guard session.expiresAt > Date() else {
            connectionState = .reauthorizationRequired
            return
        }
        let generation = accountGeneration
        isWorking = true
        connectionState = .checking
        defer {
            if generation == accountGeneration {
                isWorking = false
                if connectionState == .checking { connectionState = .unavailable }
            }
        }
        errorMessage = nil
        do {
            let remoteVehicles = try await api.vehicles(token: session.token)
            guard generation == accountGeneration, !Task.isCancelled else { return }
            apply(remoteVehicles: remoteVehicles)
            connectionState = .available
        } catch {
            if generation == accountGeneration, !Self.isCancellation(error) { handleAccountError(error) }
            return
        }
        await loadAccountExtras()
    }

    private func loadAccountExtras() async {
        let generation = accountGeneration
        if let value = await accountRequest({ try await self.api.profile(token: $0) }) { profile = value }
        guard generation == accountGeneration else { return }
        if let value = await accountRequest({ try await self.api.region(token: $0) }) { region = value }
        guard generation == accountGeneration else { return }
        if let value = await accountRequest({ try await self.api.energyProducts(token: $0) }) { energyProducts = value }
    }

    private func accountRequest<Value>(_ request: (String) async throws -> Value) async -> Value? {
        guard let session, !needsReauthentication, !Task.isCancelled else { return nil }
        guard session.expiresAt > Date() else { connectionState = .reauthorizationRequired; return nil }
        let generation = accountGeneration
        do {
            let value = try await request(session.token)
            guard generation == accountGeneration, !needsReauthentication, !Task.isCancelled else { return nil }
            return value
        } catch {
            if generation == accountGeneration, !Self.isCancellation(error) {
                // Optional endpoints may be unsupported; only a rejected
                // session changes the global authorization state.
                if (error as? FleetAPIError)?.requiresReauthentication == true { handleAccountError(error) }
            }
            return nil
        }
    }

    private func handleAccountError(_ error: Error) {
        connectionState = (error as? FleetAPIError)?.requiresReauthentication == true
            ? .reauthorizationRequired : .unavailable
        errorMessage = error.localizedDescription
    }

    func signOut() async {
        guard let current = session else { return }
        accountGeneration = UUID()
        authenticationSession?.cancel()
        authenticationSession = nil
        do { try keychain.delete() }
        catch { errorMessage = error.localizedDescription; isWorking = false; return }
        session = nil
        profile = nil
        region = nil
        energyProducts = []
        vehicleSpecs = [:]
        releaseNotes = [:]
        driverCounts = [:]
        invitationCounts = [:]
        mobileAccess = [:]
        recentAlerts = [:]
        nearbyChargingSites = [:]
        vehicles = []
        isWorking = false
        connectionState = .notConnected
        errorMessage = nil
        // Clear local state immediately, then attempt remote revocation.
        try? await api.logout(token: current.token)
    }

    func send(command: FleetCommandDefinition, to vehicle: FleetVehicle, payload: Data) async throws {
        guard let session, !needsReauthentication, session.expiresAt > Date() else {
            if session != nil { connectionState = .reauthorizationRequired }
            throw FleetAPIError.server("请重新登录 Tesla 账号。")
        }
        let generation = accountGeneration
        do {
            let result = try await api.command(token: session.token, vin: vehicle.vin.uppercased(), name: command.id, payload: payload)
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            guard result.response.result else {
                throw FleetAPIError.server(result.response.reason ?? "车辆拒绝了此命令。")
            }
        } catch {
            if generation == accountGeneration, (error as? FleetAPIError)?.requiresReauthentication == true { handleAccountError(error) }
            throw error
        }
    }

    func loadSpecs(for vin: String) async {
        let vin = vin.uppercased()
        guard vehicleSpecs[vin] == nil else { return }
        if let specs = await accountRequest({ try await self.api.vehicleSpecs(token: $0, vin: vin) }), !specs.rows.isEmpty {
            vehicleSpecs[vin] = specs
        }
    }

    func loadCloudDetails(for vin: String) async {
        let vin = vin.uppercased()
        guard session != nil else { return }
        let generation = accountGeneration

        if releaseNotes[vin] == nil,
           let notes = await accountRequest({ try await self.api.releaseNotes(token: $0, vin: vin) }),
           notes.displayVersion != nil || !notes.titledNotes.isEmpty {
            releaseNotes[vin] = notes
        }
        guard generation == accountGeneration else { return }
        if driverCounts[vin] == nil,
           let drivers = await accountRequest({ try await self.api.drivers(token: $0, vin: vin) }) {
            driverCounts[vin] = drivers.count
        }
        guard generation == accountGeneration else { return }
        if invitationCounts[vin] == nil,
           let invitations = await accountRequest({ try await self.api.shareInvitations(token: $0, vin: vin) }) {
            invitationCounts[vin] = invitations.count
        }
        guard generation == accountGeneration else { return }
        if mobileAccess[vin] == nil,
           let enabled = await accountRequest({ try await self.api.mobileEnabled(token: $0, vin: vin) }) {
            mobileAccess[vin] = enabled
        }
    }

    func loadRecentAlerts(for vin: String) async {
        let vin = vin.uppercased()
        guard session != nil else { return }
        if let alerts = await accountRequest({ try await self.api.recentAlerts(token: $0, vin: vin) }) {
            recentAlerts[vin] = Array(alerts.prefix(10))
        }
    }

    func loadNearbyChargingSites(for vin: String) async {
        let vin = vin.uppercased()
        guard session != nil else { return }
        if let response = await accountRequest({ try await self.api.nearbyChargingSites(token: $0, vin: vin) }) {
            nearbyChargingSites[vin] = (response.superchargers ?? []).sorted {
                ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
            }
        }
    }

    private func apply(remoteVehicles: [FleetVehicle]) {
        vehicles = remoteVehicles
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isCancellation(underlying)
        }
        return false
    }

    private func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: url, callbackURLScheme: "teslablekey") { callback, error in
                if let error { continuation.resume(throwing: error) }
                else if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: FleetAPIError.missingCallbackCode) }
            }
            auth.presentationContextProvider = self
            auth.prefersEphemeralWebBrowserSession = false
            authenticationSession = auth
            if !auth.start() {
                authenticationSession = nil
                continuation.resume(throwing: FleetAPIError.invalidResponse)
            }
        }
    }
}

extension FleetAccountController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct FleetSessionKeychain {
    private let service = "com.local.teslablekey.fleet"
    private let account = "backend-session"

    func save(_ session: FleetSession) throws {
        let data = try JSONEncoder().encode(session)
        try delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw FleetAPIError.server("无法安全保存登录状态。") }
    }

    func load() throws -> FleetSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw FleetAPIError.server("无法读取登录状态。")
        }
        return try JSONDecoder().decode(FleetSession.self, from: data)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FleetAPIError.server("无法清除登录状态。")
        }
    }
}
