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
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .retrying)
        XCTAssertFalse(machine.isCompact, "retrying renders the full label to test whether it now fits")
        XCTAssertTrue(machine.needsProbe)
    }

    func testBeginRetryIsNoOpWhenAlreadyFull() {
        var machine = AutoCompactMachine()
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .full)
    }

    func testBeginRetryIsNoOpWhenAlreadyRetrying() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: Date())
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .retrying, "timer and topology-change triggers may overlap; the second must not disturb the retry in flight")
    }

    func testRetryingHiddenReCompacts() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .compact)
    }

    func testRetryingFittingExpands() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .full)
    }

    func testRetryWithinCooldownIsNoOp() {
        var machine = AutoCompactMachine()
        let t0 = Date(timeIntervalSince1970: 0)
        machine.recordProbe(hidden: true)                        // .compact
        machine.beginRetry(at: t0)                               // .retrying
        machine.recordProbe(hidden: true)                        // still hidden, back to .compact
        machine.beginRetry(at: t0.addingTimeInterval(30))        // 30s later, inside the 60s cooldown
        XCTAssertEqual(machine.phase, .compact, "a retry attempt inside the cooldown window must not re-render the full label")
    }

    func testRetryAfterCooldownWorks() {
        var machine = AutoCompactMachine()
        let t0 = Date(timeIntervalSince1970: 0)
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: t0)
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: t0.addingTimeInterval(61))        // past the 60s cooldown
        XCTAssertEqual(machine.phase, .retrying, "a retry attempt after the cooldown window should proceed")
    }

    func testFullCycleThenReCompactsIfStillCrowded() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)     // compacts
        machine.beginRetry(at: Date())        // retrying
        machine.recordProbe(hidden: false)    // fits now, expands
        XCTAssertEqual(machine.phase, .full)
        machine.recordProbe(hidden: true)   // crowded again, compacts unconditionally
        XCTAssertEqual(machine.phase, .compact)
    }
}
