import XCTest
@testable import SysHUDCore

final class AutoCompactTests: XCTestCase {
    /// Drive a fresh machine to verified-compact: hidden while full, then
    /// the compact label probes visible.
    private func settledCompact() -> AutoCompactMachine {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: false)
        return machine
    }

    func testStartsExpandedAndProbing() {
        let machine = AutoCompactMachine()
        XCTAssertEqual(machine.phase, .full)
        XCTAssertFalse(machine.isCompact)
        XCTAssertTrue(machine.needsProbe)
    }

    func testHiddenProbeCompactsAndKeepsProbing() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .compactProbing)
        XCTAssertTrue(machine.isCompact)
        XCTAssertTrue(machine.needsProbe, "the compact label must be verified before settling")
    }

    func testFittingProbeStaysFull() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .full)
        XCTAssertFalse(machine.isCompact)
    }

    func testCompactVerifiedVisibleSettles() {
        let machine = settledCompact()
        XCTAssertEqual(machine.phase, .compact)
        XCTAssertTrue(machine.isCompact)
        XCTAssertFalse(machine.needsProbe)
    }

    func testCompactStillHiddenFallsBackToFull() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .fullFallback)
        XCTAssertFalse(machine.isCompact, "compacting bought nothing, keep the full reading where it does show")
        XCTAssertFalse(machine.needsProbe)
    }

    func testSettledCompactIgnoresStrayProbes() {
        var machine = settledCompact()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .compact, "settled compact must not move from a stray probe; only beginRetry() may")
    }

    func testFullFallbackIgnoresStrayProbes() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .fullFallback)
    }

    func testBeginRetryFromCompactStartsRetrying() {
        var machine = settledCompact()
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .retrying)
        XCTAssertFalse(machine.isCompact, "retrying renders the full label to test whether it now fits")
        XCTAssertTrue(machine.needsProbe)
    }

    func testBeginRetryFromFullFallbackStartsRetrying() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .retrying)
    }

    func testBeginRetryIsNoOpWhenAlreadyFull() {
        var machine = AutoCompactMachine()
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .full)
    }

    func testBeginRetryIsNoOpWhileCompactProbing() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .compactProbing, "a verdict is in flight; the trigger must not disturb it")
    }

    func testBeginRetryIsNoOpWhenAlreadyRetrying() {
        var machine = settledCompact()
        machine.beginRetry(at: Date())
        machine.beginRetry(at: Date())
        XCTAssertEqual(machine.phase, .retrying, "timer and topology-change triggers may overlap; the second must not disturb the retry in flight")
    }

    func testRetryingHiddenReCompactsAndVerifies() {
        var machine = settledCompact()
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: true)
        XCTAssertEqual(machine.phase, .compactProbing)
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .compact)
    }

    func testRetryingFittingExpands() {
        var machine = settledCompact()
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: false)
        XCTAssertEqual(machine.phase, .full)
    }

    func testRetryFromFallbackCanSettleCompactWhenRoomAppears() {
        var machine = AutoCompactMachine()
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: true)                        // .fullFallback
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: true)                        // full still hidden
        machine.recordProbe(hidden: false)                       // but compact now fits
        XCTAssertEqual(machine.phase, .compact)
    }

    func testRetryWithinCooldownIsNoOp() {
        var machine = settledCompact()
        let t0 = Date(timeIntervalSince1970: 0)
        machine.beginRetry(at: t0)                               // .retrying
        machine.recordProbe(hidden: true)                        // still hidden, verifying compact
        machine.recordProbe(hidden: false)                       // settled compact again
        machine.beginRetry(at: t0.addingTimeInterval(30))        // 30s later, inside the 60s cooldown
        XCTAssertEqual(machine.phase, .compact, "a retry attempt inside the cooldown window must not re-render the full label")
    }

    func testRetryAfterCooldownWorks() {
        var machine = settledCompact()
        let t0 = Date(timeIntervalSince1970: 0)
        machine.beginRetry(at: t0)
        machine.recordProbe(hidden: true)
        machine.recordProbe(hidden: false)
        machine.beginRetry(at: t0.addingTimeInterval(61))        // past the 60s cooldown
        XCTAssertEqual(machine.phase, .retrying, "a retry attempt after the cooldown window should proceed")
    }

    func testFullCycleThenReCompactsIfStillCrowded() {
        var machine = settledCompact()
        machine.beginRetry(at: Date())
        machine.recordProbe(hidden: false)    // fits now, expands
        XCTAssertEqual(machine.phase, .full)
        machine.recordProbe(hidden: true)     // crowded again, compacts unconditionally
        XCTAssertEqual(machine.phase, .compactProbing)
    }
}
