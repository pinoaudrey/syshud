import Foundation

/// Pure state machine for auto-compacting the menu bar label when the OS
/// overflow-hides the status item, independent of the manual "Compact
/// label" toggle (that toggle wins outright; callers only feed this machine
/// while it's off).
///
/// Compaction is a means, not a goal: after compacting, the next probe
/// verifies the compact label actually became visible. When it did not
/// (the bar has no room at any width, e.g. on a crowded notched display),
/// the machine falls back to the full label so the other displays keep the
/// whole reading. Re-expansion and re-attempts are rate-limited: they only
/// start via `beginRetry()`, which callers fire on a topology change or a
/// slow timer, never on every sample tick. That keeps the label from
/// flapping faster than the retry cadence.
public enum AutoCompactPhase: Equatable, Sendable {
    /// Rendering the full label; probed on every allowed tick.
    case full
    /// Compacted after a hidden verdict; the next probe checks whether
    /// compacting actually made the item visible.
    case compactProbing
    /// Compacted and verified visible; not probed until a retry trigger.
    case compact
    /// Compacting did not help, so the full label is back for the displays
    /// that do show it; not probed until a retry trigger.
    case fullFallback
    /// Rendering the full label again to test whether it now fits, after a
    /// retry trigger. Resolves on the next probe.
    case retrying
}

public struct AutoCompactMachine: Equatable, Sendable {
    /// Screen-parameter-change notifications fire on far more than real
    /// display topology changes (menu bar composition, spaces, wallpaper),
    /// so retry attempts are throttled to this cadence regardless of trigger.
    public static let retryCooldown: TimeInterval = 60

    public private(set) var phase: AutoCompactPhase = .full
    private var lastRetryAttempt: Date?

    public init() {}

    public var isCompact: Bool {
        phase == .compact || phase == .compactProbing
    }

    /// Whether the caller should probe on this tick. The settled phases
    /// (`.compact`, `.fullFallback`) rest until a retry trigger; the others
    /// are waiting on a verdict about the label currently rendered.
    public var needsProbe: Bool {
        phase == .full || phase == .compactProbing || phase == .retrying
    }

    /// Feed the result of probing the label currently on screen.
    public mutating func recordProbe(hidden: Bool) {
        switch phase {
        case .full, .retrying:
            if hidden {
                phase = .compactProbing
            } else if phase == .retrying {
                phase = .full
            }
        case .compactProbing:
            phase = hidden ? .fullFallback : .compact
        case .compact, .fullFallback:
            break
        }
    }

    /// A retry trigger fired at `now`: render the full label and let the
    /// next probes settle where it lands. No-op unless currently settled,
    /// and rate-limited to `retryCooldown` since the last attempt (whether
    /// or not it changed anything) so a notification storm can't flap the
    /// label faster than that. The caller supplies the clock; this stays pure.
    public mutating func beginRetry(at now: Date) {
        guard phase == .compact || phase == .fullFallback else { return }
        if let last = lastRetryAttempt, now.timeIntervalSince(last) < Self.retryCooldown { return }
        lastRetryAttempt = now
        phase = .retrying
    }
}
