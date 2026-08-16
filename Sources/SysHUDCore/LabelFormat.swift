import Foundation

/// Pure composition of the menu bar label, and the heat decision that colors
/// it.
///
/// Heat is signalled by color alone and never by the string. A hot marker in
/// the text (the 🔥 this replaced) widened the label by ~20pt, which was
/// enough to push even the compact item into the menu bar's overflow exactly
/// when the reading mattered most.
public enum LabelFormat {
    public static func title(cpuPercent: Double, usedMemory: UInt64, compact: Bool) -> String {
        let cpu = String(format: "%.0f%%", cpuPercent)
        guard !compact else { return cpu }
        return cpu + " " + ByteFormat.tiny(usedMemory)
    }

    public static func isHot(cpuPercent: Double, usedMemory: UInt64, totalMemory: UInt64) -> Bool {
        cpuPercent > 80 || Double(usedMemory) > Double(totalMemory) * 0.9
    }
}
