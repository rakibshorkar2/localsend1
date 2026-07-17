import ActivityKit
import WidgetKit
import SwiftUI

struct TransferLeadingView: View {
    let context: ActivityViewContext<TransferActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: directionIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            Text(context.state.peerName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.leading, 4)
    }

    private var directionIcon: String {
        context.state.direction == "sending" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
}

struct TransferTrailingView: View {
    let context: ActivityViewContext<TransferActivityAttributes>

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(context.state.progress * 100))%")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
        .padding(.trailing, 4)
    }

    private var progressColor: Color {
        switch context.state.transferState {
        case "finished": return .green
        case "failed", "canceled": return .red
        default: return .blue
        }
    }
}

struct TransferExpandedView: View {
    let context: ActivityViewContext<TransferActivityAttributes>

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: directionIcon)
                    .foregroundColor(accentColor)
                Text(headerText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
            }

            ProgressView(value: context.state.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: accentColor))
                .frame(height: 4)

            HStack {
                Text(peerLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(filesLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(bytesLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var directionIcon: String {
        context.state.direction == "sending" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var headerText: String {
        switch context.state.transferState {
        case "finished": return "Transfer Complete"
        case "failed": return "Transfer Failed"
        case "canceled": return "Transfer Canceled"
        default:
            return context.state.direction == "sending" ? "Sending Files" : "Receiving Files"
        }
    }

    private var peerLabel: String {
        "\u2192 \(context.state.peerName)"
    }

    private var filesLabel: String {
        "\(context.state.filesCompleted)/\(context.state.totalFiles) files"
    }

    private var bytesLabel: String {
        formatBytes(context.state.bytesTransferred) + " / " + formatBytes(context.state.totalBytes)
    }

    private var accentColor: Color {
        switch context.state.transferState {
        case "finished": return .green
        case "failed", "canceled": return .red
        default: return .blue
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }
}

struct TransferLockScreenView: View {
    let context: ActivityViewContext<TransferActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: context.state.direction == "sending" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(accentColor)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerText)
                        .font(.system(size: 14, weight: .semibold))
                    Text("with \(context.state.peerName)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(accentColor)
            }

            ProgressView(value: context.state.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: accentColor))

            HStack {
                Text("\(context.state.filesCompleted) of \(context.state.totalFiles) files")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(bytesLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var headerText: String {
        switch context.state.transferState {
        case "finished": return "Transfer Complete"
        case "failed": return "Transfer Failed"
        case "canceled": return "Transfer Canceled"
        default:
            return context.state.direction == "sending" ? "Sending Files" : "Receiving Files"
        }
    }

    private var accentColor: Color {
        switch context.state.transferState {
        case "finished": return .green
        case "failed", "canceled": return .red
        default: return .blue
        }
    }

    private var bytesLabel: String {
        formatBytes(context.state.bytesTransferred) + " / " + formatBytes(context.state.totalBytes)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }
}

@main
struct TransferLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TransferLiveActivityWidget()
    }
}

struct TransferLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransferActivityAttributes.self) { context in
            TransferLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.direction == "sending" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text(context.state.direction == "sending" ? "Sending" : "Receiving")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.peerName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        HStack {
                            Text("\(context.state.filesCompleted)/\(context.state.totalFiles) files")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatBytes(context.state.bytesTransferred) + " / " + formatBytes(context.state.totalBytes))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                TransferLeadingView(context: context)
            } compactTrailing: {
                TransferTrailingView(context: context)
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 22, height: 22)
            }
            .keylineTint(.blue)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }
}
