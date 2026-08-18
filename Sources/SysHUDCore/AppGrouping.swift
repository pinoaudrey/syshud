import Foundation

/// Processes rolled up under the app macOS holds responsible for them, so
/// the panel can show "Cursor 240%" instead of fifteen anonymous node
/// workers.
public struct AppGroup: Identifiable, Sendable {
    public let responsiblePid: Int32
    public let name: String
    /// Sums across members, Activity Monitor style.
    public let cpuPercent: Double
    public let memoryBytes: UInt64
    /// Whether killing the responsible process is allowed: it must have been
    /// sampled and belong to the current user. Members stay individually
    /// killable regardless.
    public let ownedByMe: Bool
    public let members: [ProcessSample]

    public var id: Int32 { responsiblePid }
    public var isSolo: Bool { members.count == 1 }
}

public enum AppGrouping {
    /// Groups by responsible pid and sorts groups and members by the chosen
    /// key, descending. The group is named after the responsible process
    /// itself; when that process wasn't sampled (already exited, or not
    /// visible to us), the heaviest member lends its name.
    public static func groups(from processes: [ProcessSample], sortByMemory: Bool) -> [AppGroup] {
        let groups = Dictionary(grouping: processes, by: \.responsiblePid).map { rpid, members in
            let leader = members.first { $0.pid == rpid }
            let sortedMembers = sorted(members, byMemory: sortByMemory)
            return AppGroup(
                responsiblePid: rpid,
                name: leader?.name ?? sortedMembers[0].name,
                cpuPercent: members.reduce(0) { $0 + $1.cpuPercent },
                memoryBytes: members.reduce(0) { $0 + $1.memoryBytes },
                ownedByMe: leader?.ownedByMe ?? false,
                members: sortedMembers
            )
        }
        return sortByMemory
            ? groups.sorted { $0.memoryBytes > $1.memoryBytes }
            : groups.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Reorders `groups` to match `order` so panel rows hold still between
    /// ticks: ids already in `order` keep their slot, new ids append in
    /// their sorted rank and join `order`. Vanished ids stay in `order` and
    /// reclaim their slot if the app returns.
    public static func pinned(_ groups: [AppGroup], to order: inout [Int32]) -> [AppGroup] {
        let byId = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        var result = order.compactMap { byId[$0] }
        let known = Set(order)
        for group in groups where !known.contains(group.id) {
            result.append(group)
            order.append(group.id)
        }
        return result
    }

    private static func sorted(_ members: [ProcessSample], byMemory: Bool) -> [ProcessSample] {
        byMemory
            ? members.sorted { $0.memoryBytes > $1.memoryBytes }
            : members.sorted { $0.cpuPercent > $1.cpuPercent }
    }
}
