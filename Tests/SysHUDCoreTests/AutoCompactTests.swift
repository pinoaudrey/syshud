import XCTest
@testable import SysHUDCore

final class AutoCompactTests: XCTestCase {
    func testStartsExpandedAndProbing() {
        let machine = AutoCompactMachine()
        XCTAssertEqual(machine.phase, .full)
        XCTAssertFalse(machine.isCompact)
        XCTAssertTrue(machine.needsProbe)
    }

    func testHiddenProbeCompactsImmediately() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .compact)
        XCTAssertTrue(machine.isCompact)
        XCTAssertFalse(machine.needsProbe)
    }

    func testFittingProbeStaysFull() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .full)
        XCTAssertFalse(machine.isCompact)
    }

    func testCompactIgnoresFurtherProbesUntilRetry() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .compact, "compact must not self-expand from a stray probe; only beginRetry() may")
    }

    func testBeginRetryFromCompactStartsRetrying() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry()
        XCTAssertEqual(machine.phase, .retrying)
        XCTAssertFalse(machine.isCompact, "retrying renders the full label to test whether it now fits")
        XCTAssertTrue(machine.needsProbe)
    }

    func testBeginRetryIsNoOpWhenAlreadyFull() {
        var machine = AutoCompactMachine()
        machine.beginRetry()
        XCTAssertEqual(machine.phase, .full)
    }

    func testRetryingHiddenReCompacts() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry()
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .compact)
    }

    func testRetryingFittingExpands() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry()
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .full)
    }

    func testFullCycleThenReCompactsIfStillCrowded() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)   // compacts
        machine.beginRetry()                // retrying
        machine.recordProbe(hidden: false)  // fits now, expands
        XCTAssertEqual(machine.phase, .full)
        machine.recordProbe(hidden: true)   // crowded again, compacts unconditionally
        XCTAssertEqual(machine.phase, .compact)
    }
}
