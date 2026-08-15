import AppKit
import CoreGraphics

/// Detects whether the menu bar status item is overflow-hidden behind the
/// notch, using CGWindowList.
///
/// On macOS 26, status items render as Control-Center-owned layer-25 window
/// pairs, and `kCGWindowIsOnscreen` on that pair is the truth. Identifying
/// *our* pair by name (`kCGWindowName`) isn't reliable permission-free: that
/// field is redacted for windows we don't own unless the app has Screen
/// Recording access, which SysHUD doesn't request. `kCGWindowOwnerPID` also
/// doesn't help, since every item's window is owned by Control Center, not
/// the item's own app.
///
/// Width is the reliable, permission-free signal instead: our own
/// `NSStatusBarWindow` reports the label's true rendered width via ordinary
/// AppKit (no CG access needed), and the CG window list rows carry that same
/// width. Matching on it needs no name and no ownership check.
enum StatusItemProbe {
    /// Returns nil when the current label's window can't be located yet
    /// (e.g. still laying out right after launch), in which case the caller
    /// should skip this probe rather than guess.
    static func isHidden() -> Bool? {
        guard let width = ourLabelWidth() else { return nil }
        guard let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let candidates = rows.filter { row in
            (row[kCGWindowLayer as String] as? Int) == 25
                && (row[kCGWindowOwnerName as String] as? String) == "Control Center"
                && windowWidth(of: row).map { abs($0 - width) < 0.5 } ?? false
        }
        guard !candidates.isEmpty else { return nil }
        let onscreen = candidates.contains { ($0[kCGWindowIsOnscreen as String] as? Bool) == true }
        return !onscreen
    }

    private static func windowWidth(of row: [String: Any]) -> CGFloat? {
        guard let bounds = row[kCGWindowBounds as String] as? [String: Any] else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)?.width
    }

    /// Our MenuBarExtra's window, distinguished from AppKit's other
    /// NSStatusBarWindow instance (an offscreen helper parked at y < 0) by
    /// being positioned at the real menu bar.
    private static func ourLabelWidth() -> CGFloat? {
        NSApp.windows
            .first { String(describing: type(of: $0)) == "NSStatusBarWindow" && $0.frame.origin.y > 0 }
            .map { $0.frame.width }
    }
}
