import UIKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private var activeActivities: [String: Any] = [:]

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "ios-delegate-channel",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            switch call.method {

            case "isReduceMotionEnabled":
                result(UIAccessibility.isReduceMotionEnabled)

            case "startLiveActivity":
                if let args = call.arguments as? [String: Any] {
                    self.startLiveActivity(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                }

            case "updateLiveActivity":
                if let args = call.arguments as? [String: Any] {
                    self.updateLiveActivity(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                }

            case "endLiveActivity":
                if let args = call.arguments as? [String: Any] {
                    self.endLiveActivity(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    // MARK: - Live Activity Methods

    private func startLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(false)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(false)
            return
        }

        let sessionId = args["sessionId"] as? String ?? UUID().uuidString
        let direction = args["direction"] as? String ?? "sending"
        let peerName = args["peerName"] as? String ?? "Unknown"
        let totalBytes = args["totalBytes"] as? Int64 ?? 0
        let totalFiles = args["totalFiles"] as? Int ?? 1

        let attributes = TransferActivityAttributes(sessionId: sessionId)
        let initialState = TransferActivityAttributes.ContentState(
            progress: 0.0,
            bytesTransferred: 0,
            totalBytes: totalBytes,
            direction: direction,
            peerName: peerName,
            filesCompleted: 0,
            totalFiles: totalFiles,
            transferState: "active"
        )

        do {
            let activity = try Activity<TransferActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activeActivities[sessionId] = activity
            result(true)
        } catch {
            print("Live Activity start error: \(error)")
            result(false)
        }
    }

    private func updateLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(false)
            return
        }

        let sessionId = args["sessionId"] as? String ?? ""
        guard let activity = activeActivities[sessionId] as? Activity<TransferActivityAttributes> else {
            result(false)
            return
        }

        let progress = args["progress"] as? Double ?? 0.0
        let bytesTransferred = args["bytesTransferred"] as? Int64 ?? 0
        let totalBytes = args["totalBytes"] as? Int64 ?? 0
        let direction = args["direction"] as? String ?? "sending"
        let peerName = args["peerName"] as? String ?? ""
        let filesCompleted = args["filesCompleted"] as? Int ?? 0
        let totalFiles = args["totalFiles"] as? Int ?? 1
        let transferState = args["transferState"] as? String ?? "active"

        let updatedState = TransferActivityAttributes.ContentState(
            progress: progress,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            direction: direction,
            peerName: peerName,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles,
            transferState: transferState
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
            result(true)
        }
    }

    private func endLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(false)
            return
        }

        let sessionId = args["sessionId"] as? String ?? ""
        guard let activity = activeActivities[sessionId] as? Activity<TransferActivityAttributes> else {
            result(false)
            return
        }

        let transferState = args["transferState"] as? String ?? "finished"
        let progress = args["progress"] as? Double ?? 1.0
        let bytesTransferred = args["bytesTransferred"] as? Int64 ?? 0
        let totalBytes = args["totalBytes"] as? Int64 ?? 0
        let direction = args["direction"] as? String ?? "sending"
        let peerName = args["peerName"] as? String ?? ""
        let filesCompleted = args["filesCompleted"] as? Int ?? 0
        let totalFiles = args["totalFiles"] as? Int ?? 1

        let finalState = TransferActivityAttributes.ContentState(
            progress: progress,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            direction: direction,
            peerName: peerName,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles,
            transferState: transferState
        )

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(4))
            )
            self.activeActivities.removeValue(forKey: sessionId)
            result(true)
        }
    }
}
