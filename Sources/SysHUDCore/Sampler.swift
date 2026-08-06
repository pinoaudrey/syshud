import Darwin
import Foundation

/// Samples system-wide CPU/memory and per-process CPU/memory.
/// Stateful: CPU percentages are deltas against the previous call, so the
/// first sample() reports 0% CPU everywhere. Not thread-safe; call from one queue.
public final class Sampler {
    private var prevHostTicks: (busy: UInt64, total: UInt64)?
    private var prevProcCPUNs: [Int32: UInt64] = [:]
    private var prevSampleAt: UInt64 = 0
    private var nameCache: [Int32: String] = [:]
    private let myUID = getuid()
    private let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    public init() {}

    public func sample() -> (system: SystemSample, processes: [ProcessSample]) {
        let now = mach_absolute_time()
        let wallNsDelta = prevSampleAt == 0 ? 0 : machToNs(now &- prevSampleAt)

        var system = SystemSample()
        if let ticks = hostTicks() {
            if let prev = prevHostTicks {
                system.cpuPercent = CPUMath.hostPercent(
                    busyDelta: ticks.busy &- prev.busy,
                    totalDelta: ticks.total &- prev.total
                )
            }
            prevHostTicks = ticks
        }
        system.usedMemory = usedMemory()

        var processes: [ProcessSample] = []
        var nextProcCPUNs: [Int32: UInt64] = [:]
        var nextNameCache: [Int32: String] = [:]
        for pid in allPids() {
            guard let usage = rusage(pid) else { continue }
            let cpuNs = machToNs(usage.cpuMach)
            nextProcCPUNs[pid] = cpuNs
            var percent = 0.0
            if wallNsDelta > 0, let prev = prevProcCPUNs[pid], cpuNs >= prev {
                percent = CPUMath.processPercent(cpuNsDelta: cpuNs - prev, wallNsDelta: wallNsDelta)
            }
            let name = nameCache[pid] ?? lookupName(pid)
            nextNameCache[pid] = name
            processes.append(ProcessSample(
                pid: pid,
                name: name,
                cpuPercent: percent,
                memoryBytes: usage.footprint,
                ownedByMe: uid(of: pid) == myUID
            ))
        }
        prevProcCPUNs = nextProcCPUNs
        nameCache = nextNameCache
        prevSampleAt = now
        return (system, processes)
    }

    private func machToNs(_ t: UInt64) -> UInt64 {
        t &* UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private func hostTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0)
        let sys = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        return (busy: user + sys + nice, total: user + sys + nice + idle)
    }

    /// App memory (internal minus purgeable) + wired + compressed, matching
    /// Activity Monitor's "Memory Used".
    private func usedMemory() -> UInt64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_page_size)
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let appPages = internalPages >= purgeable ? internalPages - purgeable : 0
        return (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }

    private func allPids() -> [Int32] {
        let needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(needed) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.stride))
        guard filled > 0 else { return [] }
        return pids.prefix(Int(filled)).filter { $0 > 0 }
    }

    private func rusage(_ pid: Int32) -> (cpuMach: UInt64, footprint: UInt64)? {
        var info = rusage_info_current()
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0) == 0
            }
        }
        guard ok else { return nil }
        return (info.ri_user_time &+ info.ri_system_time, info.ri_phys_footprint)
    }

    private func lookupName(_ pid: Int32) -> String {
        var pathBuf = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        if proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count)) > 0 {
            let path = String(cString: pathBuf)
            if let last = path.split(separator: "/").last, !last.isEmpty {
                return String(last)
            }
        }
        var nameBuf = [CChar](repeating: 0, count: 64)
        if proc_name(pid, &nameBuf, UInt32(nameBuf.count)) > 0 {
            return String(cString: nameBuf)
        }
        return "pid \(pid)"
    }

    private func uid(of pid: Int32) -> uid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info.pbi_uid
    }
}
