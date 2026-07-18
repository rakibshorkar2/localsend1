import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TransferWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransferAttributes.self) { context in
            TransferLiveActivity(
                state: context.state,
                direction: context.attributes.direction,
                fileName: context.attributes.fileName
            )
        } dynamicIsland: { context in
            let state = context.state
            let direction = context.attributes.direction
            let fileName = context.attributes.fileName
            let percent = "\(Int(state.progress * 100))%"
            let transferred = "\(byteCountFormatter.string(fromByteCount: state.transferredBytes)) / \(byteCountFormatter.string(fromByteCount: state.totalBytes))"
            let speed = state.speed > 0 ? "\(byteCountFormatter.string(fromByteCount: Int64(state.speed)))/s" : ""
            let remaining: String = {
                let m = Int(state.remainingSeconds) / 60
                let s = Int(state.remainingSeconds) % 60
                return m > 0 ? "\(m)m \(s)s left" : "\(s)s left"
            }()

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: direction == "send" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption)
                        Text(fileName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: max(0, min(state.progress, 1)))
                        .tint(.green)
                        .padding(.horizontal, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(transferred)
                            .font(.caption2)
                        Spacer()
                        if state.speed > 0 {
                            Text(speed)
                                .font(.caption2)
                        }
                        Spacer()
                        if state.remainingSeconds > 0 {
                            Text(remaining)
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(percent)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            } compactLeading: {
                Image(systemName: direction == "send" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(percent)
                    .font(.caption2)
                    .fontWeight(.bold)
            } minimal: {
                ZStack {
                    ProgressView(value: max(0, min(state.progress, 1)))
                        .progressViewStyle(.circular)
                        .tint(.green)
                        .scaleEffect(0.7)
                }
            }
        }
    }
}

private let byteCountFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f
}()
