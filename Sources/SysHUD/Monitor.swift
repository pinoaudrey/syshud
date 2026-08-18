import AppKit
import Combine
import Foundation
import ServiceManagement
import SysHUDCore

/// The menu bar label's only observable state. Separate from Monitor so a
/// label update re-renders just the label view, and Monitor's per-tick data
/// can stay unpublished while the panel is closed.
final class LabelModel: ObservableObject {
    @Published var image = MenuBarLabel.image(
        title: LabelFormat.title(cpuPercent: 0, usedMemory: 0, compact: false),
        hot: false
    )
}

final class Monitor: ObservableObject {
    let labelModel = LabelModel()

    // Ticks mutate these silently; `objectWillChange` fires only while the
    // panel is open (the sole reader). The label goes through `labelModel`.
    private(set) var system = SystemSample()
    private(set) var processes: [ProcessSample] = []
    /// What the panel shows: top groups in a pinned order, so rows don't
    /// jump between the user's glance and their click on a kill button.
    /// The pin resets while the panel is closed and on a sort change.
    private(set) var displayGroups: [AppGroup] = []
    private var pinnedOrder: [Int32] = []

    @Published var sortByMemory = false {
        didSet {
            pinnedOrder = []
            updateDisplayGroups()
        }
    }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var compactLabel = UserDefaults.standard.bool(forKey: "compactLabel") {
        didSet {
            UserDefaults.standard.set(compactLabel, forKey: "compactLabel")
            // Manual always wins; starting the auto machine fresh means it
            // re-probes from scratch if the user ever turns manual back off.
            if compactLabel { autoCompact = AutoCompactMachine() }
            probeGate = ProbeGate()
            refreshLabel()
        }
    }
    private var autoCompact = AutoCompactMachine()
    private var probeGate = ProbeGate()

    private struct LabelState: Equatable {
        let title: String
        let hot: Bool
    }

    private var lastLabel: LabelState?

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
        LabelFormat.title(
            cpuPercent: system.cpuPercent,
            usedMemory: system.usedMemory,
            compact: effectiveCompact
        )
    }

    var effectiveCompact: Bool {
        compactLabel || autoCompact.isCompact
    }

    var isHot: Bool {
        LabelFormat.isHot(
            cpuPercent: system.cpuPercent,
            usedMemory: system.usedMemory,
            totalMemory: system.totalMemory
        )
    }

    var memoryFraction: Double {
        guard system.totalMemory > 0 else { return 0 }
        return Double(system.usedMemory) / Double(system.totalMemory)
    }

    func terminate(pid: Int32) {
        let force = NSEvent.modifierFlags.contains(.option)
        kill(pid, force ? SIGKILL : SIGTERM)
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
                let panelVisible = self.panelWindowVisible()
                if panelVisible { self.objectWillChange.send() }
                self.system = system
                self.processes = processes
                if !panelVisible { self.pinnedOrder = [] }
                self.updateDisplayGroups()
                self.probeIfNeeded()
                self.refreshLabel()
            }
        }
    }

    /// The dropdown's window exists only after the first open and reports
    /// `isVisible` honestly (unlike NSStatusBarWindow). SwiftUI's
    /// onAppear/onDisappear don't re-fire per open on a MenuBarExtra window,
    /// so this is the reliable signal.
    private func panelWindowVisible() -> Bool {
        NSApp.windows.contains {
            $0.isVisible && String(describing: type(of: $0)).hasPrefix("MenuBarExtraWindow")
        }
    }

    private func updateDisplayGroups() {
        let sorted = AppGrouping.groups(from: processes, sortByMemory: sortByMemory)
        displayGroups = Array(AppGrouping.pinned(sorted, to: &pinnedOrder).prefix(10))
    }

    private func refreshLabel() {
        let state = LabelState(title: menuTitle, hot: isHot)
        guard state != lastLabel else { return }
        lastLabel = state
        labelModel.image = MenuBarLabel.image(title: state.title, hot: state.hot)
    }

    private func probeIfNeeded() {
        guard !compactLabel, autoCompact.needsProbe else { return }
        guard let width = StatusItemProbe.labelWidth() else { return }
        let retrying = autoCompact.phase == .retrying
        guard probeGate.shouldProbe(width: Double(width), retrying: retrying, now: Date()) else { return }
        guard let hidden = StatusItemProbe.isHidden(width: width) else {
            probeGate.probeFailed()
            return
        }
        autoCompact.recordProbe(hidden: hidden)
    }

    private func retryFullLabel() {
        guard !compactLabel else { return }
        autoCompact.beginRetry(at: Date())
        refreshLabel()
    }
}
