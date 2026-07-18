import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('ios-delegate-channel');

/// Status values matching TransferStatus in TransferAttributes.swift
enum LiveActivityStatus {
  preparing,
  connecting,
  sending,
  receiving,
  finishing,
  completed,
  cancelled,
  failed;

  String get rawValue => name;
}

/// Dart-side service that bridges to the native iOS Live Activity implementation.
/// All calls are no-ops on non-iOS platforms or when ActivityKit is unavailable.
class IosLiveActivityService {
  IosLiveActivityService._();

  /// Starts a Live Activity for the given transfer.
  /// [direction] should be 'send' or 'receive'.
  static Future<void> start({
    required String transferId,
    required String direction,
    required String fileName,
    required int totalBytes,
  }) async {
    if (!defaultTargetPlatform.isIOS) return;
    try {
      await _channel.invokeMethod('liveActivityStart', {
        'transferId': transferId,
        'direction': direction,
        'fileName': fileName,
        'totalBytes': totalBytes,
      });
    } catch (_) {}
  }

  /// Updates the active Live Activity with current progress.
  /// [progress] is 0.0 to 1.0.
  /// [speed] is in bytes per second.
  /// [remainingSeconds] is the estimated remaining time.
  static Future<void> update({
    required double progress,
    required int transferredBytes,
    required int totalBytes,
    required double speed,
    required double remainingSeconds,
    required String status,
  }) async {
    if (!defaultTargetPlatform.isIOS) return;
    try {
      await _channel.invokeMethod('liveActivityUpdate', {
        'progress': progress,
        'transferredBytes': transferredBytes,
        'totalBytes': totalBytes,
        'speed': speed,
        'remainingSeconds': remainingSeconds,
        'status': status,
      });
    } catch (_) {}
  }

  /// Ends the Live Activity with the given final [status].
  static Future<void> end({required String status}) async {
    if (!defaultTargetPlatform.isIOS) return;
    try {
      await _channel.invokeMethod('liveActivityEnd', {
        'status': status,
      });
    } catch (_) {}
  }

  /// Immediately ends and removes any active Live Activity.
  static Future<void> cancel() async {
    if (!defaultTargetPlatform.isIOS) return;
    try {
      await _channel.invokeMethod('liveActivityCancel');
    } catch (_) {}
  }
}

extension _PlatformCheck on TargetPlatform {
  bool get isIOS => this == TargetPlatform.iOS;
}
