import SwiftUI
import SysHUDCore

struct HUDView: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            meter(
                label: "CPU",
                fraction: monitor.system.cpuPercent / 100,
                detail: String(format: "%.0f%%", monitor.system.cpuPercent),
                critical: monitor.system.cpuPercent > 80
            )
            meter(
                label: "MEM",
                fraction: monitor.memoryFraction,
                detail: "\(ByteFormat.short(monitor.system.usedMemory)) / \(ByteFormat.short(monitor.system.totalMemory))",
                critical: monitor.memoryFraction > 0.9
            )

            Divider()

            Picker("Sort", selection: $monitor.sortByMemory) {
                Text("By CPU").tag(false)
                Text("By Memory").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 5) {
                ForEach(monitor.topProcesses) { process in
                    row(process)
                }
            }

            Divider()

            HStack {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Toggle("Compact label", isOn: $monitor.compactLabel)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button("Quit SysHUD") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
            }
            Text("✕ quits the process (SIGTERM), ⌥-click force kills (SIGKILL)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 360)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { monitor.launchAtLogin },
            set: { monitor.setLaunchAtLogin($0) }
        )
    }

    private func meter(label: String, fraction: Double, detail: String, critical: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .frame(width: 34, alignment: .leading)
            ProgressView(value: min(max(fraction, 0), 1))
                .tint(critical ? .red : .accentColor)
            Text(detail)
                .font(.caption.monospacedDigit())
                .frame(width: 100, alignment: .trailing)
        }
    }

    private func row(_ process: ProcessSample) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(verbatim: String(process.pid))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 4)
            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.callout.monospacedDigit())
                .frame(width: 56, alignment: .trailing)
            Text(ByteFormat.short(process.memoryBytes))
                .font(.callout.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
            Button {
                monitor.terminate(process)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .opacity(process.ownedByMe ? 1 : 0.25)
            }
            .buttonStyle(.plain)
            .disabled(!process.ownedByMe)
            .help(process.ownedByMe
                ? "Quit \(process.name) (⌥-click to force kill)"
                : "Owned by another user")
        }
    }
}
