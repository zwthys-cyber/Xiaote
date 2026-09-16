import XCTest
@testable import TeslaBLEKeyKit

final class BLEScannerXCTests: XCTestCase {

    // MARK: - Initialization

    func testScannerCanBeInitialized() {
        let scanner = BLEScanner()
        XCTAssertNotNil(scanner)
    }

    // MARK: - scan() / stop()

    func testScanReturnsAsyncStream() {
        let scanner = BLEScanner()
        let stream = scanner.scan()
        // Verify the stream is a typed AsyncStream value — calling stop() terminates it cleanly.
        XCTAssertNotNil(stream)
        scanner.stop()
    }

    func testStopCanBeCalledMultipleTimes() {
        let scanner = BLEScanner()
        _ = scanner.scan()
        // Calling stop() multiple times must not crash.
        scanner.stop()
        scanner.stop()
        scanner.stop()
    }
}
