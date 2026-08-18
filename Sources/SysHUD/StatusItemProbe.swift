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
///
/// Known limitation: another item whose window width matches ours and is
/// onscreen masks our hidden state, leaving the label full (the pre-feature
/// status quo). Accepted; disambiguating would need `kCGWindowName` and
/// therefore Screen Recording access.
enum StatusItemProbe {
    /// The label's rendered width, read cheaply from our own window without
    /// touching CGWindowList. Nil when the window can't be located yet
    /// (e.g. still laying out right after launch). Exposed separately so the
    /// caller can rate-limit the expensive probe on it.
    static func labelWidth() -> CGFloat? {
        ourStatusWindow()?.frame.width
    }

    /// Returns nil when the window list doesn't contain a candidate for
    /// `width` yet, in which case the caller should skip this probe rather
    /// than guess.
    ///
    /// Multi-display: Control Center mirrors every item onto every display's
    /// menu bar, and the copies on a wide external bar stay onscreen while
    /// the notched built-in bar overflow-hides ours. Candidates are therefore
    /// limited to the screen our own status window sits on; a copy that is
    /// visible elsewhere must not mask the hidden state here. CG and AppKit
    /// global coordinates agree on x (only y is flipped), so the screen test
    /// compares x alone.
    static func isHidden(width: CGFloat) -> Bool? {
        guard let screenX = ourScreenXRange() else { return nil }
        guard let rows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let candidates = rows.filter { row in
            (row[kCGWindowLayer as String] as? Int) == 25
                && (row[kCGWindowOwnerName as String] as? String) == "Control Center"
                && windowBounds(of: row).map {
                    abs($0.width - width) < 0.5 && screenX.contains($0.origin.x)
                } ?? false
        }
        guard !candidates.isEmpty else { return nil }
        let onscreen = candidates.contains { ($0[kCGWindowIsOnscreen as String] as? Bool) == true }
        return !onscreen
    }

    private static func windowBounds(of row: [String: Any]) -> CGRect? {
        guard let bounds = row[kCGWindowBounds as String] as? [String: Any] else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    /// Our MenuBarExtra's window, distinguished from AppKit's other
    /// NSStatusBarWindow instance (an offscreen helper parked at y < 0) by
    /// being positioned at the real menu bar.
    private static func ourStatusWindow() -> NSWindow? {
        NSApp.windows
            .first { String(describing: type(of: $0)) == "NSStatusBarWindow" && $0.frame.origin.y > 0 }
    }

    private static func ourScreenXRange() -> Range<CGFloat>? {
        guard let window = ourStatusWindow() else { return nil }
        guard let screen = window.screen ?? NSScreen.main else { return nil }
        return screen.frame.minX ..< screen.frame.maxX
    }
}
