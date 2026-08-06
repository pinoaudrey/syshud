import Foundation
import SysHUDCore

/// Headless one-shot mode (`SysHUD --sample`): takes two samples one second
/// apart and prints system stats plus the top processes by CPU.
enum SampleCLI {
    static func run() {
        let sampler = Sampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 1.0)
        let (system, processes) = sampler.sample()

        print(String(
            format: "CPU %.1f%%   MEM %@ / %@",
            system.cpuPercent,
            ByteFormat.short(system.usedMemory),
            ByteFormat.short(system.totalMemory)
        ))
        print("")
        print("\(pad("PID", 7))  \(pad("CPU%", 6))  \(pad("MEM", 7))  NAME")
        let top = processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(12)
        for p in top {
            let cpu = String(format: "%.1f", p.cpuPercent)
            print("\(pad(String(p.pid), 7))  \(pad(cpu, 6))  \(pad(ByteFormat.short(p.memoryBytes), 7))  \(p.name)")
        }
        print("")
        print("\(processes.count) processes sampled")
    }

    private static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
    }
}
