import ActivityKit
import Foundation

/// Transfer direction for Live Activity display
enum TransferDirection: String, Codable {
    case send
    case receive
}

/// Transfer status for Live Activity state
enum TransferStatus: String, Codable {
    case preparing
    case connecting
    case sending
    case receiving
    case finishing
    case completed
    case cancelled
    case failed
}

/// Static attributes that do not change during a transfer
struct TransferAttributes: ActivityAttributes {
    public typealias TransferState = ContentState

    public struct ContentState: Codable, Hashable {
        var progress: Double
        var transferredBytes: Int64
        var totalBytes: Int64
        var speed: Double
        var remainingSeconds: TimeInterval
        var status: String
    }

    var transferId: String
    var direction: String
    var fileName: String
}
