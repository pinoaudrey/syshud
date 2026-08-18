import AppKit
import SwiftUI

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--sample") {
            SampleCLI.run()
            return
        }
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        SysHUDApp.main()
    }
}

struct SysHUDApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            HUDView(monitor: monitor)
        } label: {
            MenuBarLabelView(model: monitor.labelModel)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var model: LabelModel

    var body: some View {
        // Drawn text, not `Text` (whose color this scene strips) and not
        // a `Label` (which would render icon-only here, and an SF Symbol
        // icon costs ~30pt of width on an already crowded menu bar).
        Image(nsImage: model.image)
    }
}
