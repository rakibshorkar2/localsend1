import ActivityKit
import Foundation
import UIKit

@available(iOS 16.1, *)
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    private var activity: Activity<TransferAttributes>?
    private var currentTransferId: String?

    private init() {}

    func start(
        transferId: String,
        direction: String,
        fileName: String,
        totalBytes: Int64
    ) {
        end()

        let attributes = TransferAttributes(
            transferId: transferId,
            direction: direction,
            fileName: fileName
        )

        let initialState = TransferAttributes.ContentState(
            progress: 0,
            transferredBytes: 0,
            totalBytes: totalBytes,
            speed: 0,
            remainingSeconds: 0,
            status: TransferStatus.preparing.rawValue
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            self.activity = activity
            currentTransferId = transferId
        } catch {
            self.activity = nil
            currentTransferId = nil
        }
    }

    func update(
        progress: Double,
        transferredBytes: Int64,
        totalBytes: Int64,
        speed: Double,
        remainingSeconds: TimeInterval,
        status: String
    ) {
        guard let activity = activity else { return }

        let contentState = TransferAttributes.ContentState(
            progress: progress,
            transferredBytes: transferredBytes,
            totalBytes: totalBytes,
            speed: speed,
            remainingSeconds: remainingSeconds,
            status: status
        )

        Task {
            await activity.update(using: contentState)
        }
    }

    func end(status: String) {
        guard let activity = activity else { return }

        let finalState = TransferAttributes.ContentState(
            progress: activity.contentState.progress,
            transferredBytes: activity.contentState.transferredBytes,
            totalBytes: activity.contentState.totalBytes,
            speed: 0,
            remainingSeconds: 0,
            status: status
        )

        let dismissalPolicy: ActivityUIDismissalPolicy
        switch status {
        case TransferStatus.completed.rawValue,
             TransferStatus.failed.rawValue:
            dismissalPolicy = .after(Date.now.addingTimeInterval(5))
        default:
            dismissalPolicy = .immediate
        }

        Task {
            await activity.end(using: finalState, dismissalPolicy: dismissalPolicy)
        }

        self.activity = nil
        currentTransferId = nil
    }

    func end() {
        guard let activity = activity else { return }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        self.activity = nil
        currentTransferId = nil
    }

    var isActive: Bool {
        activity != nil
    }
}
