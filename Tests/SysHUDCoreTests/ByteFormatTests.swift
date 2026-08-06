import XCTest
@testable import SysHUDCore

final class ByteFormatTests: XCTestCase {
    func testBytes() {
        XCTAssertEqual(ByteFormat.short(0), "0B")
        XCTAssertEqual(ByteFormat.short(512), "512B")
    }

    func testKilobytes() {
        XCTAssertEqual(ByteFormat.short(2048), "2K")
    }

    func testMegabytes() {
        XCTAssertEqual(ByteFormat.short(5 * 1_048_576), "5M")
        XCTAssertEqual(ByteFormat.short(512 * 1_048_576), "512M")
    }

    func testGigabytes() {
        XCTAssertEqual(ByteFormat.short(1_073_741_824), "1.0G")
        XCTAssertEqual(ByteFormat.short(3 * 1_073_741_824), "3.0G")
        XCTAssertEqual(ByteFormat.short(UInt64(18.6 * 1_073_741_824)), "18.6G")
    }

    func testLargeGigabytesDropDecimal() {
        XCTAssertEqual(ByteFormat.short(128 * 1_073_741_824), "128G")
    }
}
