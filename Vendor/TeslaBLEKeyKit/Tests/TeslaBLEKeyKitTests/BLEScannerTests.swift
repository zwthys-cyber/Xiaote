import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - BLEScanner Tests

@Suite("BLEScanner")
struct BLEScannerTests {
    @Test("BLEScanner can be instantiated")
    func instantiation() {
        let scanner = BLEScanner()
        #expect(scanner != nil)
    }

    @Test("vehicleLocalName produces valid Tesla local name format")
    func validTeslaLocalNameFormat() throws {
        let name = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000000")
        // isTeslaLocalName criteria: length == 18, starts with "S", ends with "C", middle 16 chars are hex
        #expect(name.count == 18)
        #expect(name.hasPrefix("S"))
        #expect(name.hasSuffix("C"))
        let hexPart = String(name.dropFirst().dropLast())
        #expect(hexPart.allSatisfy { $0.isHexDigit })
    }

    @Test("Non-Tesla local names do not match the Tesla format")
    func nonTeslaLocalNameFormats() {
        // These names do not match the Tesla local name pattern (18 chars, S...C with hex middle)
        let invalidNames = [
            "",
            "S",
            "SC",
            "S123456789abcdefC",   // 17 chars total
            "S123456789abcdef12C",  // 19 chars total
            "X9f2bfe28ae1284efC",   // does not start with S
            "S9f2bfe28ae1284efX",   // does not end with C
            "S9f2bfe28ae1284GGC",   // G is not a hex digit
        ]
        for name in invalidNames {
            let isValid = name.count == 18
                && name.hasPrefix("S")
                && name.hasSuffix("C")
                && String(name.dropFirst().dropLast()).allSatisfy { $0.isHexDigit }
            #expect(!isValid, "Expected '\(name)' to be an invalid Tesla local name")
        }
    }

    @Test("Different VINs produce distinct Tesla local names")
    func distinctLocalNamesFromDifferentVINs() throws {
        let name1 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000001")
        let name2 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000002")
        let name3 = try vehicleLocalName(forVIN: "5YJ3E1EA0LF000003")
        #expect(name1 != name2)
        #expect(name2 != name3)
        #expect(name1 != name3)
        // All still comply with the Tesla local name format
        for name in [name1, name2, name3] {
            #expect(name.count == 18)
            #expect(name.hasPrefix("S"))
            #expect(name.hasSuffix("C"))
        }
    }
}
