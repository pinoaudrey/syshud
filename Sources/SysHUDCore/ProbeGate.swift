import Foundation

/// Rate-limits the visibility probe, whose CGWindowList call copies metadata
/// for every window on the system and therefore scales with total window
/// count. Probing every tick made SysHUD's own CPU climb exactly when the
/// machine was busiest.
///
/// The hidden state only changes when the label's width changes or the menu
/// bar's composition does, so a probe is allowed when:
/// - the label width differs from the last probed width,
/// - the auto-compact machine is retrying (already rate-limited upstream),
/// - or `recheckInterval` has passed, as a safety net for composition
///   changes that arrive with no width change and no notification.
public struct ProbeGate: Equatable, Sendable {
    public static let recheckInterval: TimeInterval = 60

    private var lastWidth: Double?
    private var lastProbeAt: Date?

    public init() {}

    /// Decides whether to probe now, and records the attempt when it says
    /// yes. The caller supplies the clock; this stays pure.
    public mutating func shouldProbe(width: Double, retrying: Bool, now: Date) -> Bool {
        let due = retrying
            || lastWidth != width
            || lastProbeAt.map { now.timeIntervalSince($0) >= Self.recheckInterval } ?? true
        guard due else { return false }
        lastWidth = width
        lastProbeAt = now
        return true
    }

    /// The probe it approved came back inconclusive; forget the attempt so
    /// the next tick tries again instead of waiting out the interval.
    public mutating func probeFailed() {
        lastWidth = nil
        lastProbeAt = nil
    }
}
