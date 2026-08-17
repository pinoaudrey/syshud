import XCTest
@testable import SysHUDCore

final class LabelFormatTests: XCTestCase {
    private let gb: UInt64 = 1_073_741_824

    func testCompactTitleIsCPUOnly() {
        XCTAssertEqual(LabelFormat.title(cpuPercent: 12, usedMemory: 8 * gb, compact: true), "12%")
    }

    func testFullTitleAddsMemory() {
        XCTAssertEqual(LabelFormat.title(cpuPercent: 12, usedMemory: 8 * gb, compact: false), "12% 8G")
    }

    func testHotCompactTitleMatchesCoolShape() {
        let cool = LabelFormat.title(cpuPercent: 12, usedMemory: 8 * gb, compact: true)
        let hot = LabelFormat.title(cpuPercent: 96, usedMemory: 8 * gb, compact: true)
        XCTAssertEqual(hot, "96%")
        XCTAssertEqual(hot.count, cool.count, "heat is signalled by color; it must not change the label's width")
    }

    func testHotFullTitleMatchesCoolShape() {
        let cool = LabelFormat.title(cpuPercent: 12, usedMemory: 8 * gb, compact: false)
        let hot = LabelFormat.title(cpuPercent: 96, usedMemory: 8 * gb, compact: false)
        XCTAssertEqual(hot, "96% 8G")
        XCTAssertEqual(hot.count, cool.count, "heat is signalled by color; it must not change the label's width")
    }

    func testTitleStaysASCIIUnderLoad() {
        let hot = LabelFormat.title(cpuPercent: 99, usedMemory: 60 * gb, compact: false)
        XCTAssertTrue(hot.allSatisfy(\.isASCII), "an emoji or other wide glyph would widen the label exactly when it is least affordable")
    }

    func testCPUThresholdIsExclusive() {
        XCTAssertFalse(LabelFormat.isHot(cpuPercent: 80, usedMemory: 0, totalMemory: 16 * gb))
        XCTAssertTrue(LabelFormat.isHot(cpuPercent: 80.1, usedMemory: 0, totalMemory: 16 * gb))
    }

    func testMemoryThresholdIsExclusive() {
        let total = 16 * gb
        XCTAssertFalse(LabelFormat.isHot(cpuPercent: 0, usedMemory: total * 9 / 10, totalMemory: total))
        XCTAssertTrue(LabelFormat.isHot(cpuPercent: 0, usedMemory: total * 9 / 10 + 1, totalMemory: total))
    }

    func testIdleIsNotHot() {
        XCTAssertFalse(LabelFormat.isHot(cpuPercent: 3, usedMemory: 4 * gb, totalMemory: 16 * gb))
    }
}
