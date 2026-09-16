import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - TeslaVehicleConfiguration Tests

@Suite("TeslaVehicleConfiguration")
struct TeslaVehicleConfigurationTests {
    @Test(".standard has expected default values")
    func standardDefaults() {
        let config = TeslaVehicleConfiguration.standard
        #expect(config.nonceMode == .standard12Byte)
        #expect(config.commandTimeout == 10)
        #expect(config.sessionTimeout == 15)
    }

    @Test(".fourByteNonceBLE uses teslaBLE4Byte nonce mode")
    func fourByteNonceBLEDefaults() {
        let config = TeslaVehicleConfiguration.fourByteNonceBLE
        #expect(config.nonceMode == .teslaBLE4Byte)
        #expect(config.commandTimeout == 10)
        #expect(config.sessionTimeout == 15)
    }

    @Test("Custom configuration stores all provided values")
    func customConfiguration() {
        let config = TeslaVehicleConfiguration(
            nonceMode: .custom(8),
            commandTimeout: 30,
            sessionTimeout: 60
        )
        #expect(config.nonceMode == .custom(8))
        #expect(config.commandTimeout == 30)
        #expect(config.sessionTimeout == 60)
    }

    @Test("Equatable: same configurations are equal")
    func equatableSame() {
        let a = TeslaVehicleConfiguration.standard
        let b = TeslaVehicleConfiguration.standard
        #expect(a == b)
    }

    @Test("Equatable: configurations differing in nonceMode are not equal")
    func equatableDifferentNonceMode() {
        let a = TeslaVehicleConfiguration.standard
        let b = TeslaVehicleConfiguration.fourByteNonceBLE
        #expect(a != b)
    }

    @Test("Equatable: configurations differing in commandTimeout are not equal")
    func equatableDifferentCommandTimeout() {
        let a = TeslaVehicleConfiguration(commandTimeout: 10)
        let b = TeslaVehicleConfiguration(commandTimeout: 20)
        #expect(a != b)
    }

    @Test("Equatable: configurations differing in sessionTimeout are not equal")
    func equatableDifferentSessionTimeout() {
        let a = TeslaVehicleConfiguration(sessionTimeout: 15)
        let b = TeslaVehicleConfiguration(sessionTimeout: 30)
        #expect(a != b)
    }
}

// MARK: - TeslaClosure Tests

@Suite("TeslaClosure")
struct TeslaClosureTests {
    @Test("Equatable: same cases are equal")
    func equatableSameCases() {
        #expect(TeslaClosure.trunk == .trunk)
        #expect(TeslaClosure.frunk == .frunk)
        #expect(TeslaClosure.tonneau == .tonneau)
        #expect(TeslaClosure.chargePort == .chargePort)
    }

    @Test("Equatable: different cases are not equal")
    func equatableDifferentCases() {
        #expect(TeslaClosure.trunk != .frunk)
        #expect(TeslaClosure.trunk != .tonneau)
        #expect(TeslaClosure.trunk != .chargePort)
        #expect(TeslaClosure.frunk != .tonneau)
        #expect(TeslaClosure.frunk != .chargePort)
        #expect(TeslaClosure.tonneau != .chargePort)
    }

    @Test("All four closure cases are distinct")
    func allCasesDistinct() {
        let allCases: [TeslaClosure] = [.trunk, .frunk, .tonneau, .chargePort]
        for i in allCases.indices {
            for j in allCases.indices where i != j {
                #expect(allCases[i] != allCases[j])
            }
        }
    }
}
