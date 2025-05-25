import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'navigator_service.dart';
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  //心跳
  Timer? _heartbeatTimer;
  final Duration heartbeatInterval = const Duration(seconds: 2);
  final Duration heartbeatTimeout = const Duration(seconds: 5);
  Completer<void>? _heartbeatCompleter;

  late WebSocketChannel? _channel;
  WebSocketChannel? get channel=>_channel;
  final StreamController _messageController = StreamController.broadcast();
  final StreamController _errorController = StreamController.broadcast();
  final StreamController _doneController = StreamController.broadcast();
  Stream get messageStream => _messageController.stream;
  Stream get errorStream => _errorController.stream;
  Stream get doneStream => _doneController.stream;

  void startHeartbeat(String? Uuid) {
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) async {
      try {
        // 发送 ping 消息
        _heartbeatCompleter = Completer<void>();
        _channel?.sink.add(jsonEncode({'type': 'ping','from':Uuid}));
        // 等待 pong
        await _waitForHeartbeatAck();
      } catch (e) {
        _handleDisconnected();
      }
    });
  }

  Future<void> _waitForHeartbeatAck() {
    return _heartbeatCompleter!
        .future
        .timeout(heartbeatTimeout, onTimeout: () {
      _heartbeatCompleter?.completeError('Timeout waiting for pong');
      throw TimeoutException('No pong response');
    });
  }

  //意外中止心跳
  void _handleDisconnected() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer=null;
    _heartbeatCompleter?.completeError('Disconnected');
    // 可触发重连或跳转错误页面
    navigatorKey.currentState?.pushReplacementNamed('/server');
  }
  //正常结束心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  WebSocketManager._internal();
  void Connect()
  {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://47.111.112.168:9876'),
    );
    _channel?.stream.listen(
          (msg) {
            //心跳检测
            final data=jsonDecode(msg);
            if(data['type']=='pong')
            {
              if(_heartbeatCompleter != null && !_heartbeatCompleter!.isCompleted) {
                _heartbeatCompleter?.complete();
              }
            }
            else
              {
                _messageController.add(msg); // 分发 message
              }

      },
      onError: (error) {
        _stopHeartbeat();
        _errorController.add(error); // 分发 error
      },
      onDone: () {
        _stopHeartbeat();
        _doneController.add(null); // 分发 done
      },
      cancelOnError: true,
    );
  }
  void disconnect()
  {
    _stopHeartbeat();
    _channel?.sink.close();
    _channel=null;
  }
  void dispose() {
    _channel?.sink.close();
    _channel=null;
    _messageController.close();
    _errorController.close();
    _doneController.close();
  }
}