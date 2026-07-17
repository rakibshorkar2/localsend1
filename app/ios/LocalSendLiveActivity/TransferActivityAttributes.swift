import ActivityKit
import Foundation

struct TransferActivityAttributes: ActivityAttributes {
    public typealias TransferStatus = ContentState

    public struct ContentState: Codable, Hashable {
        var progress: Double
        var bytesTransferred: Int64
        var totalBytes: Int64
        var direction: String
        var peerName: String
        var filesCompleted: Int
        var totalFiles: Int
        var transferState: String
    }

    var sessionId: String
}
