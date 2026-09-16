import XCTest
@testable import TeslaBLEKeyKit

// MARK: - TeslaVehicleConfiguration

final class VehicleConfigurationXCTests: XCTestCase {

    func testStandardConfiguration() {
        let config = TeslaVehicleConfiguration.standard
        XCTAssertEqual(config.nonceMode, .standard12Byte)
        XCTAssertEqual(config.commandTimeout, 10)
        XCTAssertEqual(config.sessionTimeout, 15)
    }

    func testFourByteNonceBLE() {
        let config = TeslaVehicleConfiguration.fourByteNonceBLE
        XCTAssertEqual(config.nonceMode, .teslaBLE4Byte)
        // Other fields retain their defaults.
        XCTAssertEqual(config.commandTimeout, 10)
        XCTAssertEqual(config.sessionTimeout, 15)
    }

    func testCustomConfiguration() {
        let config = TeslaVehicleConfiguration(
            nonceMode: .custom(8),
            commandTimeout: 30,
            sessionTimeout: 60
        )
        XCTAssertEqual(config.nonceMode, .custom(8))
        XCTAssertEqual(config.nonceMode.length, 8)
        XCTAssertEqual(config.commandTimeout, 30)
        XCTAssertEqual(config.sessionTimeout, 60)
    }

    func testEquatable() {
        let a = TeslaVehicleConfiguration.standard
        let b = TeslaVehicleConfiguration.standard
        XCTAssertEqual(a, b)

        let c = TeslaVehicleConfiguration.fourByteNonceBLE
        XCTAssertNotEqual(a, c)

        let d = TeslaVehicleConfiguration(nonceMode: .standard12Byte, commandTimeout: 99, sessionTimeout: 15)
        XCTAssertNotEqual(a, d)
    }
}

// MARK: - TeslaClosure

final class TeslaClosureXCTests: XCTestCase {

    func testAllCases() {
        let allCases: [TeslaClosure] = [.trunk, .frunk, .tonneau, .chargePort]

        // Each case is equal to itself.
        for closure in allCases {
            XCTAssertEqual(closure, closure)
        }

        // All four cases are distinct from each other.
        XCTAssertNotEqual(TeslaClosure.trunk, .frunk)
        XCTAssertNotEqual(TeslaClosure.trunk, .tonneau)
        XCTAssertNotEqual(TeslaClosure.trunk, .chargePort)
        XCTAssertNotEqual(TeslaClosure.frunk, .tonneau)
        XCTAssertNotEqual(TeslaClosure.frunk, .chargePort)
        XCTAssertNotEqual(TeslaClosure.tonneau, .chargePort)

        // Verify that the set contains exactly 4 unique values.
        XCTAssertEqual(Set(allCases.map { "\($0)" }).count, 4)
    }
}
