import 'dart:io';

import 'package:localsend_app/isolate/model/file_status.dart';
import 'package:localsend_app/isolate/model/session_status.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/util/native/ios_channel.dart';

class IOSLiveActivityController {
  bool _started = false;
  int _lastUpdateTime = 0;

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
          _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
          await startTransferLiveActivity(
            sessionId: state.sessionId,
            direction: 'sending',
            peerName: peerName,
            totalBytes: totalBytes,
            totalFiles: totalFiles,
          );
        } else {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastUpdateTime < 1000) return;
          _lastUpdateTime = now;
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
        break;
    }
  }

  Future<void> onReceiveSessionUpdate(ReceiveSessionState state) async {
    if (!Platform.isIOS) return;

    final totalBytes = state.files.values
        .fold<int>(0, (sum, f) => sum + (f.file.size));
    final bytesTransferred = state.files.values
        .where((f) => f.status == FileStatus.finished)
        .fold<int>(0, (sum, f) => sum + (f.file.size));
    final filesCompleted = state.files.values
        .where((f) => f.status == FileStatus.finished)
        .length;
    final totalFiles = state.files.length;
    final progress = totalBytes > 0
        ? (bytesTransferred / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final peerName = state.senderAlias;

    switch (state.status) {
      case SessionStatus.sending:
        if (!_started) {
          _started = true;
          _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
          await startTransferLiveActivity(
            sessionId: state.sessionId,
            direction: 'receiving',
            peerName: peerName,
            totalBytes: totalBytes,
            totalFiles: totalFiles,
          );
        } else {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastUpdateTime < 1000) return;
          _lastUpdateTime = now;
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

  int _totalBytesFromSendState(SendSessionState state) {
    return state.files.values
        .fold<int>(0, (sum, f) => sum + (f.file.size));
  }

  int _bytesTransferredFromSendState(SendSessionState state) {
    return state.files.values
        .where((f) => f.status == FileStatus.finished)
        .fold<int>(0, (sum, f) => sum + (f.file.size));
  }
}
