import Foundation

public enum ByteFormat {
    /// Narrowest useful form, for the menu bar label: whole gigabytes.
    public static func tiny(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.0fG", gb) }
        return String(format: "%.0fM", Double(bytes) / 1_048_576)
    }

    public static func short(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 { return String(format: "%.0fG", gb) }
        if gb >= 1 { return String(format: "%.1fG", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0fM", mb) }
        let kb = Double(bytes) / 1024
        if kb >= 1 { return String(format: "%.0fK", kb) }
        return "\(bytes)B"
    }
}
