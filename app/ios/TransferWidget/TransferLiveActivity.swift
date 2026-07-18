import ActivityKit
import SwiftUI

/// Live Activity and Lock Screen view for file transfers.
@available(iOS 16.1, *)
struct TransferLiveActivity: View {

    let state: TransferAttributes.ContentState
    let direction: String
    let fileName: String

    var body: some View {
        lockScreenContent
            .activityBackgroundTint(.clear)
    }

    // MARK: - Lock Screen

    private var lockScreenContent: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: direction == "send" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(.green)
                Text(fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(percentString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }

            ProgressView(value: max(0, min(state.progress, 1)))
                .tint(.green)

            HStack {
                Text(transferredString)
                    .font(.caption)
                Spacer()
                if state.speed > 0 {
                    Text("\(speedString)/s")
                        .font(.caption)
                }
                Spacer()
                if state.remainingSeconds > 0 {
                    Text(remainingString)
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Helpers

    private var percentString: String {
        "\(Int(state.progress * 100))%"
    }

    private var transferredString: String {
        "\(byteCountFormatter.string(fromByteCount: state.transferredBytes)) / \(byteCountFormatter.string(fromByteCount: state.totalBytes))"
    }

    private var speedString: String {
        byteCountFormatter.string(fromByteCount: Int64(state.speed))
    }

    private var remainingString: String {
        let minutes = Int(state.remainingSeconds) / 60
        let seconds = Int(state.remainingSeconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s left"
        }
        return "\(seconds)s left"
    }

    private var byteCountFormatter: ByteCountFormatter {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }
}
