# AI Agent Implementation Prompt
## Feature: Live Activity + Dynamic Island for File Transfers — LocalSend Pro (iOS Only)

---

## CONTEXT & CONSTRAINTS

You are implementing **iOS Live Activity with Dynamic Island support** for the LocalSend Pro app — a Flutter-based local file sharing app. The feature must show transfer progress in the Dynamic Island and Lock Screen while the app is backgrounded.

**Hard constraints (do not violate):**
- iOS deployment target: **minimum iOS 16.1** (Live Activities require 16.1+; do NOT go above iOS 18)
- Dynamic Island UI requires **iOS 16.2+** at runtime (guard with `#available(iOS 16.2, *)`)
- The Podfile currently sets `platform :ios, '13.0'` — you must raise this to `'16.1'`
- This app builds an **unsigned IPA** via GitHub Actions (`flutter build ios --release --no-codesign`) — do NOT add any entitlements that require Apple Developer signing beyond what already exists
- This is a **Flutter app** — all bridge communication must go through `FlutterMethodChannel` using the existing channel pattern already in `AppDelegate.swift`
- Do NOT modify any Android, macOS, Windows, or Linux files
- The Live Activity extension uses `ActivityKit` + `WidgetKit` — no third-party Swift packages needed

---

## CODEBASE OVERVIEW (read before touching any file)

```
app/
├── ios/
│   ├── Runner/
│   │   ├── AppDelegate.swift          ← Main Swift entry point; already has MethodChannel for 'ios-delegate-channel'
│   │   ├── Info.plist                 ← App metadata; needs NSSupportsLiveActivities key
│   │   ├── Runner.entitlements        ← Already has aps-environment + multicast + app-group
│   │   └── Runner-Bridging-Header.h   ← Bridging header (currently empty)
│   ├── Podfile                        ← Sets platform :ios, '13.0'; must be raised
│   └── Runner.xcodeproj/
│       └── project.pbxproj            ← Xcode project; needs new Extension target added
├── lib/
│   ├── util/native/ios_channel.dart   ← Dart-side MethodChannel helper (only 'isReduceMotionEnabled' exists)
│   ├── model/state/send/
│   │   ├── send_session_state.dart    ← SendSessionState: sessionId, status, target.alias, files map, startTime
│   │   └── sending_file.dart         ← SendingFile: file.fileSize, status (FileStatus enum), file.fileName
│   ├── model/state/server/
│   │   └── receive_session_state.dart ← ReceiveSessionState: sessionId, status, sender.alias, files map
│   ├── isolate/model/
│   │   ├── session_status.dart        ← SessionStatus enum: waiting, sending, finished, finishedWithErrors, canceledBySender, canceledByReceiver, declined
│   │   └── file_status.dart           ← FileStatus enum (check for: sending, finished, failed, skipped)
│   └── pages/progress_page.dart       ← The UI page shown during active transfer (send + receive)
```

**Existing MethodChannel name:** `ios-delegate-channel`  
**App Group ID:** `group.com.dirxplorerakib.pro`  
**Bundle ID:** `com.dirxplorerakib.pro`

---

## WHAT TO BUILD

### Architecture Summary

```
Flutter (Dart)                     Native iOS (Swift)
─────────────────                  ──────────────────────────────────────
ios_channel.dart  ←MethodChannel→  AppDelegate.swift
  startLiveActivity()               ├── startTransferActivity(...)
  updateLiveActivity()              ├── updateTransferActivity(...)
  endLiveActivity()                 └── endTransferActivity(...)
                                         │
                                         ↓
                              TransferActivityAttributes (ActivityKit)
                                         │
                              LocalSendLiveActivityExtension/
                              ├── TransferActivityAttributes.swift
                              └── TransferLiveActivityWidget.swift (WidgetKit)
```

---

## STEP-BY-STEP IMPLEMENTATION

---

### STEP 1 — Raise iOS Deployment Target

**File:** `app/ios/Podfile`

Change:
```ruby
platform :ios, '13.0'
```
To:
```ruby
platform :ios, '16.1'
```

Also update the `post_install` block to propagate the deployment target:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.1'
    end
  end
end
```

---

### STEP 2 — Update Info.plist

**File:** `app/ios/Runner/Info.plist`

Add the following key inside the root `<dict>`, before the closing `</dict>`:

```xml
<!-- Live Activities -->
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

---

### STEP 3 — Create the Live Activity Extension

Create a new folder: `app/ios/LocalSendLiveActivity/`

#### 3a. TransferActivityAttributes.swift

**File:** `app/ios/LocalSendLiveActivity/TransferActivityAttributes.swift`

```swift
import ActivityKit
import Foundation

struct TransferActivityAttributes: ActivityAttributes {
    public typealias TransferStatus = ContentState

    public struct ContentState: Codable, Hashable {
        // 0.0 to 1.0
        var progress: Double
        // Number of bytes transferred
        var bytesTransferred: Int64
        // Total bytes to transfer
        var totalBytes: Int64
        // "sending" or "receiving"
        var direction: String
        // Name of peer device
        var peerName: String
        // Number of files completed
        var filesCompleted: Int
        // Total number of files
        var totalFiles: Int
        // "active", "finished", "failed", "canceled"
        var transferState: String
    }

    // Static attributes (set at start, never change)
    var sessionId: String
}
```

#### 3b. TransferLiveActivityWidget.swift

**File:** `app/ios/LocalSendLiveActivity/TransferLiveActivityWidget.swift`

```swift
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Compact / Minimal (Dynamic Island)

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

// MARK: - Expanded Dynamic Island

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
        "→ \(context.state.peerName)"
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

// MARK: - Lock Screen / Notification Banner

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

// MARK: - Widget Bundle

@main
struct TransferLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TransferLiveActivityWidget()
    }
}

struct TransferLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransferActivityAttributes.self) { context in
            // Lock screen / banner
            TransferLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
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
```

#### 3c. Info.plist for the Extension

**File:** `app/ios/LocalSendLiveActivity/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>LocalSendLiveActivity</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

---

### STEP 4 — Update AppDelegate.swift

**File:** `app/ios/Runner/AppDelegate.swift`

Replace the entire file with the following (preserves all existing logic and adds Live Activity bridge):

```swift
import UIKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    // Track active activity by sessionId
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
            // Show final state for 4 seconds, then dismiss
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(4))
            )
            self.activeActivities.removeValue(forKey: sessionId)
            result(true)
        }
    }
}
```

---

### STEP 5 — Add Dart-Side Bridge

**File:** `app/lib/util/native/ios_channel.dart`

Replace the entire file with the following:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('ios-delegate-channel');

/// Returns true if iOS Reduce Motion accessibility setting is enabled.
Future<bool> isReduceMotionEnabledIOS() async {
  return await _methodChannel.invokeMethod('isReduceMotionEnabled') ?? false;
}

/// Starts a Live Activity for a file transfer session.
/// Only executes on iOS 16.2+; silently no-ops on other platforms/versions.
///
/// [sessionId]   Unique ID for this transfer session (maps to SendSessionState.sessionId)
/// [direction]   "sending" or "receiving"
/// [peerName]    Display name of the remote device
/// [totalBytes]  Total bytes to transfer across all files
/// [totalFiles]  Total number of files in this session
Future<bool> startTransferLiveActivity({
  required String sessionId,
  required String direction,
  required String peerName,
  required int totalBytes,
  required int totalFiles,
}) async {
  if (!Platform.isIOS) return false;
  try {
    final result = await _methodChannel.invokeMethod<bool>('startLiveActivity', {
      'sessionId': sessionId,
      'direction': direction,
      'peerName': peerName,
      'totalBytes': totalBytes,
      'totalFiles': totalFiles,
    });
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Updates the Live Activity with the latest transfer progress.
///
/// [progress]         0.0 to 1.0 fraction of transfer complete
/// [bytesTransferred] Bytes sent/received so far
/// [filesCompleted]   Number of files fully transferred
/// [transferState]    "active", "finished", "failed", or "canceled"
Future<bool> updateTransferLiveActivity({
  required String sessionId,
  required double progress,
  required int bytesTransferred,
  required int totalBytes,
  required String direction,
  required String peerName,
  required int filesCompleted,
  required int totalFiles,
  String transferState = 'active',
}) async {
  if (!Platform.isIOS) return false;
  try {
    final result = await _methodChannel.invokeMethod<bool>('updateLiveActivity', {
      'sessionId': sessionId,
      'progress': progress,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'direction': direction,
      'peerName': peerName,
      'filesCompleted': filesCompleted,
      'totalFiles': totalFiles,
      'transferState': transferState,
    });
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Ends the Live Activity and shows a final state for ~4 seconds.
Future<bool> endTransferLiveActivity({
  required String sessionId,
  required String transferState,
  required double progress,
  required int bytesTransferred,
  required int totalBytes,
  required String direction,
  required String peerName,
  required int filesCompleted,
  required int totalFiles,
}) async {
  if (!Platform.isIOS) return false;
  try {
    final result = await _methodChannel.invokeMethod<bool>('endLiveActivity', {
      'sessionId': sessionId,
      'transferState': transferState,
      'progress': progress,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'direction': direction,
      'peerName': peerName,
      'filesCompleted': filesCompleted,
      'totalFiles': totalFiles,
    });
    return result ?? false;
  } catch (_) {
    return false;
  }
}
```

---

### STEP 6 — Create the Live Activity Controller (Dart)

Create a new file that owns the logic for starting/updating/ending activities based on session state changes.

**File:** `app/lib/util/native/ios_live_activity_controller.dart`

```dart
import 'dart:io';

import 'package:localsend_app/isolate/model/file_status.dart';
import 'package:localsend_app/isolate/model/session_status.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/util/native/ios_channel.dart';

/// Manages the lifecycle of a Live Activity for a single transfer session.
///
/// Usage (in a Refena provider or widget that watches session state):
///   final controller = IOSLiveActivityController();
///   await controller.onSendSessionUpdate(state);
///   // or
///   await controller.onReceiveSessionUpdate(state);
class IOSLiveActivityController {
  bool _started = false;

  // ── SEND SESSION ─────────────────────────────────────────────────────────

  Future<void> onSendSessionUpdate(SendSessionState state) async {
    if (!Platform.isIOS) return;

    final totalBytes = _totalBytesFromSendState(state);
    final bytesTransferred = _bytesTransferredFromSendState(state);
    final filesCompleted = state.files.values
        .where((f) => f.status == FileStatus.finished)
        .length;
    final totalFiles = state.files.length;
    final progress = totalBytes > 0
        ? (bytesTransferred / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final peerName = state.target.alias;

    switch (state.status) {
      case SessionStatus.sending:
        if (!_started) {
          _started = true;
          await startTransferLiveActivity(
            sessionId: state.sessionId,
            direction: 'sending',
            peerName: peerName,
            totalBytes: totalBytes,
            totalFiles: totalFiles,
          );
        } else {
          await updateTransferLiveActivity(
            sessionId: state.sessionId,
            progress: progress,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            direction: 'sending',
            peerName: peerName,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles,
            transferState: 'active',
          );
        }

      case SessionStatus.finished:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'finished',
          progress: 1.0,
          bytesTransferred: totalBytes,
          totalBytes: totalBytes,
          direction: 'sending',
          peerName: peerName,
          filesCompleted: totalFiles,
          totalFiles: totalFiles,
        );

      case SessionStatus.finishedWithErrors:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'failed',
          progress: progress,
          bytesTransferred: bytesTransferred,
          totalBytes: totalBytes,
          direction: 'sending',
          peerName: peerName,
          filesCompleted: filesCompleted,
          totalFiles: totalFiles,
        );

      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'canceled',
          progress: progress,
          bytesTransferred: bytesTransferred,
          totalBytes: totalBytes,
          direction: 'sending',
          peerName: peerName,
          filesCompleted: filesCompleted,
          totalFiles: totalFiles,
        );

      default:
        // waiting, recipientBusy, declined, tooManyAttempts — do nothing
        break;
    }
  }

  // ── RECEIVE SESSION ───────────────────────────────────────────────────────

  Future<void> onReceiveSessionUpdate(ReceiveSessionState state) async {
    if (!Platform.isIOS) return;

    final totalBytes = state.files.values
        .fold<int>(0, (sum, f) => sum + (f.file.size ?? 0));
    final bytesTransferred = state.files.values
        .where((f) => f.status == FileStatus.finished)
        .fold<int>(0, (sum, f) => sum + (f.file.size ?? 0));
    final filesCompleted = state.files.values
        .where((f) => f.status == FileStatus.finished)
        .length;
    final totalFiles = state.files.length;
    final progress = totalBytes > 0
        ? (bytesTransferred / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final peerName = state.senderAlias;

    switch (state.status) {
      case SessionStatus.sending: // receiving side uses 'sending' status too while in progress
        if (!_started) {
          _started = true;
          await startTransferLiveActivity(
            sessionId: state.sessionId,
            direction: 'receiving',
            peerName: peerName,
            totalBytes: totalBytes,
            totalFiles: totalFiles,
          );
        } else {
          await updateTransferLiveActivity(
            sessionId: state.sessionId,
            progress: progress,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            direction: 'receiving',
            peerName: peerName,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles,
            transferState: 'active',
          );
        }

      case SessionStatus.finished:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'finished',
          progress: 1.0,
          bytesTransferred: totalBytes,
          totalBytes: totalBytes,
          direction: 'receiving',
          peerName: peerName,
          filesCompleted: totalFiles,
          totalFiles: totalFiles,
        );

      case SessionStatus.finishedWithErrors:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'failed',
          progress: progress,
          bytesTransferred: bytesTransferred,
          totalBytes: totalBytes,
          direction: 'receiving',
          peerName: peerName,
          filesCompleted: filesCompleted,
          totalFiles: totalFiles,
        );

      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        await endTransferLiveActivity(
          sessionId: state.sessionId,
          transferState: 'canceled',
          progress: progress,
          bytesTransferred: bytesTransferred,
          totalBytes: totalBytes,
          direction: 'receiving',
          peerName: peerName,
          filesCompleted: filesCompleted,
          totalFiles: totalFiles,
        );

      default:
        break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _totalBytesFromSendState(SendSessionState state) {
    return state.files.values
        .fold<int>(0, (sum, f) => sum + (f.file.size ?? 0));
  }

  int _bytesTransferredFromSendState(SendSessionState state) {
    return state.files.values
        .where((f) => f.status == FileStatus.finished)
        .fold<int>(0, (sum, f) => sum + (f.file.size ?? 0));
  }
}
```

---

### STEP 7 — Wire the Controller into progress_page.dart

**File:** `app/lib/pages/progress_page.dart`

Open the file and make the following changes:

**7a.** Add the import at the top of the file (after existing imports):
```dart
import 'package:localsend_app/util/native/ios_live_activity_controller.dart';
```

**7b.** Inside the State class (the `_ProgressPageState` or equivalent stateful widget class), add a controller field:
```dart
final _liveActivityController = IOSLiveActivityController();
```

**7c.** Locate the place in the widget where the session state is consumed (look for `ref.watch` or `context.watch` on `sendSessionProvider` or `serverProvider`). After each state update that carries `SendSessionState` or `ReceiveSessionState`, add a `didUpdateWidget` / listener call:

For the **send** side — find where `SendSessionState` changes are handled (usually in a `Consumer` or `ref.listen`). Add:
```dart
// Immediately after obtaining the updated sendState:
_liveActivityController.onSendSessionUpdate(sendState);
```

For the **receive** side — find where `ReceiveSessionState` changes are handled. Add:
```dart
// Immediately after obtaining the updated receiveState:
_liveActivityController.onReceiveSessionUpdate(receiveState);
```

**7d.** Override `dispose` (or add to existing `dispose`) to ensure cleanup:
```dart
@override
void dispose() {
  // Live Activity cleanup is handled by its dismissal policy;
  // no explicit Dart-side dispose needed.
  super.dispose();
}
```

**Important:** Do not restructure the existing UI or state management of `progress_page.dart` — only add the controller calls alongside the existing session-state consumption.

---

### STEP 8 — Register the Extension Target in Xcode Project

**File:** `app/ios/Runner.xcodeproj/project.pbxproj`

This is the most complex step. Add a new App Extension target for the Live Activity widget.

You must add the following sections to the `project.pbxproj`. Use `ruby` or `sed` carefully, or open the file in a text editor. The structure follows the existing `ShareExtension` pattern already present in the file.

Add these PBX sections (generate real UUIDs using `uuidgen` for each placeholder marked `[UUID_X]`):

**PBXBuildFile entries** (add inside the existing `/* Begin PBXBuildFile section */`):
```
[UUID_1] /* TransferActivityAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = [UUID_2] /* TransferActivityAttributes.swift */; };
[UUID_3] /* TransferLiveActivityWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = [UUID_4] /* TransferLiveActivityWidget.swift */; };
[UUID_5] /* LocalSendLiveActivity.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = [UUID_6] /* LocalSendLiveActivity.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
```

**PBXFileReference entries** (add inside the existing `/* Begin PBXFileReference section */`):
```
[UUID_2] /* TransferActivityAttributes.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = TransferActivityAttributes.swift; path = LocalSendLiveActivity/TransferActivityAttributes.swift; sourceTree = "<group>"; };
[UUID_4] /* TransferLiveActivityWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = TransferLiveActivityWidget.swift; path = LocalSendLiveActivity/TransferLiveActivityWidget.swift; sourceTree = "<group>"; };
[UUID_6] /* LocalSendLiveActivity.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = LocalSendLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; };
[UUID_7] /* Info.plist (extension) */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = LocalSendLiveActivity/Info.plist; sourceTree = "<group>"; };
```

**PBXGroup** — add a new group for the extension (find the main Children group and add):
```
[UUID_8] /* LocalSendLiveActivity */ = {
    isa = PBXGroup;
    children = (
        [UUID_2] /* TransferActivityAttributes.swift */,
        [UUID_4] /* TransferLiveActivityWidget.swift */,
        [UUID_7] /* Info.plist */,
    );
    name = LocalSendLiveActivity;
    sourceTree = "<group>";
};
```

**PBXNativeTarget** for the extension:
```
[UUID_9] /* LocalSendLiveActivity */ = {
    isa = PBXNativeTarget;
    buildConfigurationList = [UUID_10] /* Build configuration list for PBXNativeTarget "LocalSendLiveActivity" */;
    buildPhases = (
        [UUID_11] /* Sources */,
        [UUID_12] /* Frameworks */,
        [UUID_13] /* Resources */,
    );
    buildRules = ();
    dependencies = ();
    name = LocalSendLiveActivity;
    productName = LocalSendLiveActivity;
    productReference = [UUID_6] /* LocalSendLiveActivity.appex */;
    productType = "com.apple.product-type.app-extension";
};
```

**Build Configuration** for the extension target (add two: Debug and Release):
```
[UUID_14] /* Debug */ = {
    isa = XCBuildConfiguration;
    buildSettings = {
        ARCHS = "$(ARCHS_STANDARD)";
        CODE_SIGN_STYLE = Automatic;
        CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
        GENERATE_INFOPLIST_FILE = NO;
        INFOPLIST_FILE = LocalSendLiveActivity/Info.plist;
        IPHONEOS_DEPLOYMENT_TARGET = 16.1;
        MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";
        PRODUCT_BUNDLE_IDENTIFIER = com.dirxplorerakib.pro.LiveActivity;
        PRODUCT_NAME = "$(TARGET_NAME)";
        SKIP_INSTALL = YES;
        SWIFT_VERSION = 5.0;
        TARGETED_DEVICE_FAMILY = 1;
    };
    name = Debug;
};
[UUID_15] /* Release */ = {
    isa = XCBuildConfiguration;
    buildSettings = {
        ARCHS = "$(ARCHS_STANDARD)";
        CODE_SIGN_STYLE = Automatic;
        CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
        GENERATE_INFOPLIST_FILE = NO;
        INFOPLIST_FILE = LocalSendLiveActivity/Info.plist;
        IPHONEOS_DEPLOYMENT_TARGET = 16.1;
        MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";
        PRODUCT_BUNDLE_IDENTIFIER = com.dirxplorerakib.pro.LiveActivity;
        PRODUCT_NAME = "$(TARGET_NAME)";
        SKIP_INSTALL = YES;
        SWIFT_VERSION = 5.0;
        TARGETED_DEVICE_FAMILY = 1;
    };
    name = Release;
};
```

**Add the extension to the Runner target's Embed Extensions build phase.**  
Find the `CopyFilesBuildPhase` (named "Embed Foundation Extensions") under Runner's target. Add `[UUID_5]` to its `files` array.

**Add the extension target to the PBXProject's `targets` array.**

> **Recommended approach:** Rather than hand-editing `project.pbxproj`, use a Ruby script or add the target via `xcodebuild` in the GitHub Actions workflow. See Step 9 for the GitHub Actions approach.

---

### STEP 9 — Update GitHub Actions Workflow

**File:** `.github/workflows/build-ios.yml`

Replace the file with the following updated version that adds the extension target via `xcodebuild` before the Flutter build:

```yaml
name: Build iOS (unsigned)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build-ios:
    name: Build iOS IPA
    runs-on: macos-latest

    defaults:
      run:
        working-directory: app

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: 1.93.1
          targets: aarch64-apple-ios

      - name: Flutter pub get
        run: flutter pub get

      - name: Install CocoaPods
        run: |
          cd ios
          pod install

      - name: Build Flutter iOS (release, no codesign)
        run: flutter build ios --release --no-codesign

      - name: Build Live Activity Extension
        run: |
          xcodebuild \
            -workspace ios/Runner.xcworkspace \
            -scheme LocalSendLiveActivity \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO \
            SKIP_INSTALL=YES \
            build

      - name: Package IPA
        run: |
          mkdir -p build/ipa/Payload
          cp -r build/ios/iphoneos/Runner.app build/ipa/Payload/
          # Copy extension into the app bundle
          APPEX_PATH=$(find build -name "LocalSendLiveActivity.appex" | head -1)
          if [ -n "$APPEX_PATH" ]; then
            mkdir -p build/ipa/Payload/Runner.app/PlugIns
            cp -r "$APPEX_PATH" build/ipa/Payload/Runner.app/PlugIns/
          fi
          cd build/ipa
          zip -r ../LocalSendPro.ipa Payload/

      - uses: actions/upload-artifact@v4
        with:
          name: LocalSendPro-iOS
          path: app/build/LocalSendPro.ipa
          retention-days: 30
```

---

### STEP 10 — Final Integration Checklist

Before committing, verify each of the following:

#### Dart
- [ ] `app/lib/util/native/ios_channel.dart` — three new async functions: `startTransferLiveActivity`, `updateTransferLiveActivity`, `endTransferLiveActivity`
- [ ] `app/lib/util/native/ios_live_activity_controller.dart` — new file created
- [ ] `app/lib/pages/progress_page.dart` — controller imported, instantiated, and called on every send/receive state update

#### Swift / Xcode
- [ ] `app/ios/LocalSendLiveActivity/TransferActivityAttributes.swift` — new file
- [ ] `app/ios/LocalSendLiveActivity/TransferLiveActivityWidget.swift` — new file
- [ ] `app/ios/LocalSendLiveActivity/Info.plist` — new file
- [ ] `app/ios/Runner/AppDelegate.swift` — updated with `startLiveActivity`, `updateLiveActivity`, `endLiveActivity` cases
- [ ] `app/ios/Runner/Info.plist` — `NSSupportsLiveActivities` and `NSSupportsLiveActivitiesFrequentUpdates` keys added
- [ ] `app/ios/Podfile` — platform raised to `'16.1'`, deployment target set in `post_install`
- [ ] `app/ios/Runner.xcodeproj/project.pbxproj` — extension target registered (see Step 8)

#### GitHub Actions
- [ ] `.github/workflows/build-ios.yml` — extension build step + copy into PlugIns folder added

---

## RUNTIME BEHAVIOR SPECIFICATION

| Trigger | Live Activity Action |
|---|---|
| `SessionStatus.sending` fires for first time | `startLiveActivity` — show 0% |
| `SessionStatus.sending` fires again (progress update) | `updateLiveActivity` — update progress |
| `SessionStatus.finished` | `endLiveActivity(transferState: "finished")` — green, show 4s then dismiss |
| `SessionStatus.finishedWithErrors` | `endLiveActivity(transferState: "failed")` — red |
| `SessionStatus.canceledBySender` / `canceledByReceiver` | `endLiveActivity(transferState: "canceled")` — red |
| App comes to foreground | Live Activity still shown; dismissal is fine (iOS handles it) |
| Device does not have Dynamic Island (iPhone 13 and earlier) | Lock Screen banner shown instead; Dynamic Island code is `#available` guarded |

---

## IMPORTANT NOTES FOR THE AI AGENT

1. **DO NOT** change the Xcode deployment target inside `project.pbxproj` for the Runner target above iOS 16.1 — the unsigned IPA must remain compatible.

2. **DO NOT** add any entitlement to `Runner.entitlements` that isn't already there — no push notifications, no `com.apple.developer.live-activities` key needed (ActivityKit does not require a special entitlement for local activities as of iOS 16).

3. **DO NOT** use `@available(iOS 16.1, *)` on the `Activity` import itself — use `#available(iOS 16.2, *)` guards at runtime in `AppDelegate.swift` and simply return `false` on lower versions.

4. The `FileStatus` enum import path is `package:localsend_app/isolate/model/file_status.dart` — verify the exact variant names by reading `app/lib/isolate/model/file_status.dart` before writing the controller.

5. The `ReceivingFile` model's file size field may be `f.file.size` or `f.file.fileSize` — verify by reading `app/lib/model/state/server/receiving_file.dart` and `app/lib/isolate/model/dto/file_dto.dart`.

6. The `SendSessionState.target` is of type `Device` — the alias field is `Device.alias`. Verify by reading `app/lib/isolate/model/device.dart`.

7. Progress updates in `progress_page.dart` may fire very frequently. Throttle `updateLiveActivity` calls to no more than **once per second** to avoid overwhelming ActivityKit. Add a timestamp check in `IOSLiveActivityController`.

8. The extension's `PRODUCT_BUNDLE_IDENTIFIER` must be a sub-bundle of the app: `com.dirxplorerakib.pro.LiveActivity`.

9. After editing `project.pbxproj`, run `pod install` again in `app/ios/` to regenerate the workspace and verify no syntax errors in the pbxproj by running `plutil -lint Runner.xcodeproj/project.pbxproj`.

10. Test on **iOS Simulator 16.2+** first with the Dynamic Island simulator (iPhone 14 Pro simulator).