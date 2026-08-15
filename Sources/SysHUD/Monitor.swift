import AppKit
import Combine
import Foundation
import ServiceManagement
import SysHUDCore

final class Monitor: ObservableObject {
    @Published var system = SystemSample()
    @Published var processes: [ProcessSample] = []
    @Published var sortByMemory = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var compactLabel = UserDefaults.standard.bool(forKey: "compactLabel") {
        didSet {
            UserDefaults.standard.set(compactLabel, forKey: "compactLabel")
            // Manual always wins; starting the auto machine fresh means it
            // re-probes from scratch if the user ever turns manual back off.
            if compactLabel { autoCompact = AutoCompactMachine() }
        }
    }
    @Published private var autoCompact = AutoCompactMachine()

    private let sampler = Sampler()
    private let queue = DispatchQueue(label: "syshud.sampler", qos: .utility)
    private var timer: Timer?
    private var retryTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init() {
        tick()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Re-expansion is deliberately rare: a topology change or this slow
        // timer, never every sample tick (see AutoCompactMachine).
        let retry = Timer(timeInterval: 300, repeats: true) { [weak self] _ in self?.retryFullLabel() }
        retry.tolerance = 30
        RunLoop.main.add(retry, forMode: .common)
        retryTimer = retry

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.retryFullLabel() }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // Kept deliberately narrow: every point of width raises the chance the
    // item is overflow-hidden on a crowded notched menu bar. Compact mode
    // (CPU only, ~40pt) exists so the item can coexist with wide neighbors,
    // manually or automatically when the full label doesn't fit.
    var menuTitle: String {
        let cpu = String(format: "%.0f%%", system.cpuPercent)
        let base = effectiveCompact ? cpu : cpu + " " + ByteFormat.tiny(system.usedMemory)
        return isHot ? "🔥" + base : base
    }

    var effectiveCompact: Bool {
        compactLabel || autoCompact.isCompact
    }

    var isHot: Bool {
        system.cpuPercent > 80 || Double(system.usedMemory) > Double(system.totalMemory) * 0.9
    }

    var memoryFraction: Double {
        guard system.totalMemory > 0 else { return 0 }
        return Double(system.usedMemory) / Double(system.totalMemory)
    }

    var topProcesses: [ProcessSample] {
        let sorted = sortByMemory
            ? processes.sorted { $0.memoryBytes > $1.memoryBytes }
            : processes.sorted { $0.cpuPercent > $1.cpuPercent }
        return Array(sorted.prefix(10))
    }

    func terminate(_ process: ProcessSample) {
        let force = NSEvent.modifierFlags.contains(.option)
        kill(process.pid, force ? SIGKILL : SIGTERM)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration only works from a real .app bundle; revert to actual state.
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func tick() {
        queue.async { [weak self] in
            guard let self else { return }
            let (system, processes) = self.sampler.sample()
            DispatchQueue.main.async {
                self.system = system
                self.processes = processes
                self.probeIfNeeded()
            }
        }
    }

    private func probeIfNeeded() {
        guard !compactLabel, autoCompact.needsProbe else { return }
        guard let hidden = StatusItemProbe.isHidden() else { return }
        autoCompact.recordProbe(hidden: hidden)
    }

    private func retryFullLabel() {
        guard !compactLabel else { return }
        autoCompact.beginRetry()
    }
}
