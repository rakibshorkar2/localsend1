import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('ios-delegate-channel');

Future<bool> isReduceMotionEnabledIOS() async {
  return await _methodChannel.invokeMethod('isReduceMotionEnabled') ?? false;
}

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
