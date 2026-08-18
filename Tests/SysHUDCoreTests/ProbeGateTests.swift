import XCTest
@testable import SysHUDCore

final class ProbeGateTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testFirstCallProbes() {
        var gate = ProbeGate()
        XCTAssertTrue(gate.shouldProbe(width: 75, retrying: false, now: t0))
    }

    func testSameWidthWithinIntervalSkips() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        XCTAssertFalse(gate.shouldProbe(width: 75, retrying: false, now: t0.addingTimeInterval(2)))
        XCTAssertFalse(gate.shouldProbe(width: 75, retrying: false, now: t0.addingTimeInterval(58)))
    }

    func testWidthChangeProbesImmediately() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        XCTAssertTrue(gate.shouldProbe(width: 95, retrying: false, now: t0.addingTimeInterval(2)))
    }

    func testRetryingAlwaysProbes() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        XCTAssertTrue(gate.shouldProbe(width: 75, retrying: true, now: t0.addingTimeInterval(2)))
    }

    func testRecheckIntervalElapsedProbes() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        XCTAssertTrue(gate.shouldProbe(
            width: 75,
            retrying: false,
            now: t0.addingTimeInterval(ProbeGate.recheckInterval)
        ))
    }

    func testApprovedProbeRearmsTheInterval() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        _ = gate.shouldProbe(width: 95, retrying: false, now: t0.addingTimeInterval(30))
        XCTAssertFalse(gate.shouldProbe(width: 95, retrying: false, now: t0.addingTimeInterval(60)))
        XCTAssertTrue(gate.shouldProbe(width: 95, retrying: false, now: t0.addingTimeInterval(90)))
    }

    func testProbeFailedAllowsImmediateRetry() {
        var gate = ProbeGate()
        _ = gate.shouldProbe(width: 75, retrying: false, now: t0)
        gate.probeFailed()
        XCTAssertTrue(gate.shouldProbe(width: 75, retrying: false, now: t0.addingTimeInterval(2)))
    }
}
