import XCTest
@testable import SysHUDCore

final class AppGroupingTests: XCTestCase {
    private func proc(
        pid: Int32,
        name: String,
        cpu: Double = 0,
        mem: UInt64 = 0,
        mine: Bool = true,
        responsible: Int32? = nil
    ) -> ProcessSample {
        ProcessSample(
            pid: pid,
            name: name,
            cpuPercent: cpu,
            memoryBytes: mem,
            ownedByMe: mine,
            responsiblePid: responsible ?? pid
        )
    }

    func testSumsCPUAndMemoryAcrossMembers() {
        let groups = AppGrouping.groups(from: [
            proc(pid: 1, name: "Cursor", cpu: 10, mem: 100),
            proc(pid: 2, name: "node", cpu: 30, mem: 200, responsible: 1),
            proc(pid: 3, name: "node", cpu: 20, mem: 300, responsible: 1),
        ], sortByMemory: false)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].cpuPercent, 60)
        XCTAssertEqual(groups[0].memoryBytes, 600)
        XCTAssertEqual(groups[0].members.count, 3)
    }

    func testGroupTakesResponsibleProcessName() {
        let groups = AppGrouping.groups(from: [
            proc(pid: 2, name: "Cursor Helper", cpu: 90, responsible: 1),
            proc(pid: 1, name: "Cursor", cpu: 1),
        ], sortByMemory: false)

        XCTAssertEqual(groups[0].name, "Cursor")
    }

    func testMissingLeaderFallsBackToHeaviestMember() {
        let groups = AppGrouping.groups(from: [
            proc(pid: 2, name: "small worker", cpu: 1, responsible: 99),
            proc(pid: 3, name: "big worker", cpu: 50, responsible: 99),
        ], sortByMemory: false)

        XCTAssertEqual(groups[0].name, "big worker")
        XCTAssertFalse(groups[0].ownedByMe, "no leader sampled means no group kill")
    }

    func testOwnedByMeComesFromLeaderNotMembers() {
        let groups = AppGrouping.groups(from: [
            proc(pid: 1, name: "root-app", mine: false),
            proc(pid: 2, name: "my worker", cpu: 5, mine: true, responsible: 1),
        ], sortByMemory: false)

        XCTAssertFalse(groups[0].ownedByMe)
    }

    func testGroupsSortByChosenKey() {
        let samples = [
            proc(pid: 1, name: "cpu-heavy", cpu: 90, mem: 10),
            proc(pid: 2, name: "mem-heavy", cpu: 10, mem: 900),
        ]

        XCTAssertEqual(AppGrouping.groups(from: samples, sortByMemory: false)[0].name, "cpu-heavy")
        XCTAssertEqual(AppGrouping.groups(from: samples, sortByMemory: true)[0].name, "mem-heavy")
    }

    func testMembersSortByChosenKeyWithinGroup() {
        let samples = [
            proc(pid: 1, name: "app", cpu: 1, mem: 1),
            proc(pid: 2, name: "cpu-worker", cpu: 50, mem: 10, responsible: 1),
            proc(pid: 3, name: "mem-worker", cpu: 5, mem: 500, responsible: 1),
        ]

        XCTAssertEqual(AppGrouping.groups(from: samples, sortByMemory: false)[0].members[0].name, "cpu-worker")
        XCTAssertEqual(AppGrouping.groups(from: samples, sortByMemory: true)[0].members[0].name, "mem-worker")
    }

    func testPinnedKeepsPriorOrderAsValuesShift() {
        var order: [Int32] = []
        let first = AppGrouping.groups(from: [
            proc(pid: 1, name: "a", cpu: 90),
            proc(pid: 2, name: "b", cpu: 10),
        ], sortByMemory: false)
        XCTAssertEqual(AppGrouping.pinned(first, to: &order).map(\.name), ["a", "b"])

        let second = AppGrouping.groups(from: [
            proc(pid: 1, name: "a", cpu: 5),
            proc(pid: 2, name: "b", cpu: 80),
        ], sortByMemory: false)
        XCTAssertEqual(AppGrouping.pinned(second, to: &order).map(\.name), ["a", "b"], "rows must not jump while pinned")
    }

    func testPinnedAppendsNewGroupsAndDropsVanished() {
        var order: [Int32] = [7, 8]
        let groups = AppGrouping.groups(from: [
            proc(pid: 9, name: "new", cpu: 99),
            proc(pid: 8, name: "kept", cpu: 1),
        ], sortByMemory: false)
        XCTAssertEqual(AppGrouping.pinned(groups, to: &order).map(\.name), ["kept", "new"])
        XCTAssertEqual(order, [7, 8, 9], "vanished ids keep their slot for a possible return")
    }

    func testSelfResponsibleProcessIsSoloGroup() {
        let groups = AppGrouping.groups(from: [proc(pid: 1, name: "standalone", cpu: 5)], sortByMemory: false)

        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].isSolo)
        XCTAssertEqual(groups[0].responsiblePid, 1)
    }
}
