import Foundation

public enum CPUMath {
    public static func hostPercent(busyDelta: UInt64, totalDelta: UInt64) -> Double {
        guard totalDelta > 0 else { return 0 }
        return min(100, max(0, Double(busyDelta) / Double(totalDelta) * 100))
    }

    public static func processPercent(cpuNsDelta: UInt64, wallNsDelta: UInt64) -> Double {
        guard wallNsDelta > 0 else { return 0 }
        return max(0, Double(cpuNsDelta) / Double(wallNsDelta) * 100)
    }
}
