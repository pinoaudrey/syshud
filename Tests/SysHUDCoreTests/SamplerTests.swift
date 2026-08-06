import XCTest
@testable import SysHUDCore

final class SamplerTests: XCTestCase {
    func testSampleReturnsPlausibleSystemStats() {
        let sampler = Sampler()
        let (system, processes) = sampler.sample()
        XCTAssertGreaterThan(system.totalMemory, 0)
        XCTAssertGreaterThan(system.usedMemory, 0)
        XCTAssertLessThan(system.usedMemory, system.totalMemory)
        XCTAssertGreaterThan(processes.count, 20)
    }

    func testSampleFindsOwnProcess() {
        let sampler = Sampler()
        let (_, processes) = sampler.sample()
        let me = processes.first { $0.pid == getpid() }
        XCTAssertNotNil(me)
        XCTAssertEqual(me?.ownedByMe, true)
        XCTAssertGreaterThan(me?.memoryBytes ?? 0, 0)
        XCTAssertFalse(me?.name.isEmpty ?? true)
    }

    func testRepeatedSamplesProduceCPUPercents() {
        let sampler = Sampler()
        _ = sampler.sample()
        // A single short window can catch the kernel's tick counters before
        // they advance, so burn CPU and resample a few times; the invariant
        // is that deltas eventually produce nonzero percentages.
        var systemPercent = 0.0
        var myPercent = 0.0
        for _ in 0..<5 {
            var x = 0.0
            let until = Date().addingTimeInterval(0.4)
            while Date() < until { x += .pi.squareRoot() }
            XCTAssertGreaterThan(x, 0)
            let (system, processes) = sampler.sample()
            systemPercent = system.cpuPercent
            myPercent = processes.first { $0.pid == getpid() }?.cpuPercent ?? 0
            if systemPercent > 0, myPercent > 0 { break }
        }
        XCTAssertGreaterThan(systemPercent, 0)
        XCTAssertGreaterThan(myPercent, 0)
    }
}
