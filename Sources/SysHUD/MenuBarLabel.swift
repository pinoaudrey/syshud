import AppKit

/// Draws the menu bar label into an image so it can carry a color.
///
/// SwiftUI strips `foregroundStyle` from a `MenuBarExtra` label: the system
/// takes the rendered `Text` as a template mask and tints it itself (proven
/// by capturing the rendered label's pixels, which came back pure black with
/// only alpha varying). An image is the one path that keeps a color.
///
/// Cold stays a template so macOS keeps tinting it for light/dark and
/// inverting it while the panel is open. Hot opts out of that to hold the
/// red. Both branches measure the same string in the same font, so heat
/// cannot change the label's width.
enum MenuBarLabel {
    static func image(title: String, hot: Bool) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
            weight: .regular
        )
        let string = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: hot ? NSColor.systemRed : NSColor.black]
        )
        let size = string.size()
        let image = NSImage(
            size: NSSize(width: ceil(size.width), height: ceil(size.height)),
            flipped: false
        ) { rect in
            string.draw(in: rect)
            return true
        }
        image.isTemplate = !hot
        return image
    }
}
