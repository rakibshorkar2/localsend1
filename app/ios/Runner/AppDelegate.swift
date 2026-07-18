import UIKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
        switch call.method {
        case "isReduceMotionEnabled":
            result(UIAccessibility.isReduceMotionEnabled)
        case "liveActivityStart":
            self?.handleLiveActivityStart(call: call, result: result)
        case "liveActivityUpdate":
            self?.handleLiveActivityUpdate(call: call, result: result)
        case "liveActivityEnd":
            self?.handleLiveActivityEnd(call: call, result: result)
        case "liveActivityCancel":
            self?.handleLiveActivityCancel(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - Live Activity Handlers

  private func handleLiveActivityStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let transferId = args["transferId"] as? String,
          let direction = args["direction"] as? String,
          let fileName = args["fileName"] as? String,
          let totalBytes = args["totalBytes"] as? Int64 else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityStart", details: nil))
      return
    }
    LiveActivityManager.shared.start(
      transferId: transferId,
      direction: direction,
      fileName: fileName,
      totalBytes: totalBytes
    )
    result(nil)
  }

  private func handleLiveActivityUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let progress = args["progress"] as? Double,
          let transferredBytes = args["transferredBytes"] as? Int64,
          let totalBytes = args["totalBytes"] as? Int64,
          let speed = args["speed"] as? Double,
          let remainingSeconds = args["remainingSeconds"] as? TimeInterval,
          let status = args["status"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityUpdate", details: nil))
      return
    }
    LiveActivityManager.shared.update(
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
      speed: speed,
      remainingSeconds: remainingSeconds,
      status: status
    )
    result(nil)
  }

  private func handleLiveActivityEnd(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let status = args["status"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityEnd", details: nil))
      return
    }
    LiveActivityManager.shared.end(status: status)
    result(nil)
  }

  private func handleLiveActivityCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    LiveActivityManager.shared.end()
    result(nil)
  }
}
