import Foundation

public struct ProcessSample: Identifiable, Sendable {
    public let pid: Int32
    public let name: String
    /// Percent of a single core, Activity Monitor style (can exceed 100 for multi-threaded processes).
    public let cpuPercent: Double
    /// Physical footprint in bytes, the same number Activity Monitor's Memory column shows.
    public let memoryBytes: UInt64
    public let ownedByMe: Bool
    /// The pid macOS holds responsible for this process (Activity Monitor's
    /// app grouping). Self-responsible processes carry their own pid.
    public let responsiblePid: Int32

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        name: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        ownedByMe: Bool,
        responsiblePid: Int32
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.ownedByMe = ownedByMe
        self.responsiblePid = responsiblePid
    }
}

public struct SystemSample: Sendable {
    /// Percent of total capacity across all cores, 0-100.
    public var cpuPercent: Double
    public var usedMemory: UInt64
    public var totalMemory: UInt64

    public init(
        cpuPercent: Double = 0,
        usedMemory: UInt64 = 0,
        totalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) {
        self.cpuPercent = cpuPercent
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
    }
}
