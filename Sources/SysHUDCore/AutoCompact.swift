import Foundation

/// Pure state machine for auto-compacting the menu bar label when the OS
/// overflow-hides the status item, independent of the manual "Compact
/// label" toggle (that toggle wins outright; callers only feed this machine
/// while it's off).
///
/// Compaction is unconditional: any probe taken while `.full` that finds the
/// item hidden compacts immediately. Re-expansion is rate-limited: it only
/// starts via `beginRetry()`, which callers fire on a topology change or a
/// slow timer, never on every sample tick. That keeps the label from
/// flapping faster than the retry cadence.
public enum AutoCompactPhase: Equatable, Sendable {
    /// Rendering the full label; probed on every tick.
    case full
    /// Auto-compacted; not probed until a retry trigger fires.
    case compact
    /// Rendering the full label again to test whether it now fits, after a
    /// retry trigger. Resolves back to `.compact` or `.full` on next probe.
    case retrying
}

public struct AutoCompactMachine: Equatable, Sendable {
    public private(set) var phase: AutoCompactPhase = .full

    public init() {}

    public var isCompact: Bool { phase == .compact }

    /// Whether the caller should probe on this tick: `.full` and `.retrying`
    /// render the full label and need to know if it fits; `.compact`
    /// doesn't render it, so there's nothing to check.
    public var needsProbe: Bool { phase != .compact }

    /// Feed the result of probing the label currently on screen.
    public mutating func recordProbe(hidden: Bool) {
        switch phase {
        case .full:
            if hidden { phase = .compact }
        case .retrying:
            phase = hidden ? .compact : .full
        case .compact:
            break
        }
    }

    /// A retry trigger fired: switch back to full and let the next probe
    /// settle whether it fits. No-op unless currently compacted.
    public mutating func beginRetry() {
        guard phase == .compact else { return }
        phase = .retrying
    }
}
