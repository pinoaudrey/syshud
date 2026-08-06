import XCTest
@testable import SysHUDCore

final class CPUMathTests: XCTestCase {
    func testHostPercent() {
        XCTAssertEqual(CPUMath.hostPercent(busyDelta: 50, totalDelta: 200), 25)
        XCTAssertEqual(CPUMath.hostPercent(busyDelta: 0, totalDelta: 200), 0)
        XCTAssertEqual(CPUMath.hostPercent(busyDelta: 200, totalDelta: 200), 100)
    }

    func testHostPercentZeroTotal() {
        XCTAssertEqual(CPUMath.hostPercent(busyDelta: 10, totalDelta: 0), 0)
    }

    func testHostPercentClamps() {
        XCTAssertEqual(CPUMath.hostPercent(busyDelta: 300, totalDelta: 200), 100)
    }

    func testProcessPercent() {
        XCTAssertEqual(
            CPUMath.processPercent(cpuNsDelta: 1_000_000_000, wallNsDelta: 2_000_000_000),
            50
        )
    }

    func testProcessPercentZeroWall() {
        XCTAssertEqual(CPUMath.processPercent(cpuNsDelta: 1_000, wallNsDelta: 0), 0)
    }

    func testProcessPercentCanExceed100() {
        // Multi-threaded process: 4s of CPU over 2s of wall clock = 200% of one core.
        XCTAssertEqual(
            CPUMath.processPercent(cpuNsDelta: 4_000_000_000, wallNsDelta: 2_000_000_000),
            200
        )
    }
}
