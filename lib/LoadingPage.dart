import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import'dart:convert';
import 'dart:async';
import'Argument.dart';
import'WebSocketManager.dart';
class LoadingPage extends StatefulWidget {
  final String serverUrl='ws://47.111.112.168:9876';

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {

  WebSocketChannel? _channel;
  String? Uuid;
  late StreamSubscription _msgSub;
  late StreamSubscription _errSub;
  late StreamSubscription _doneSub;
  //接收回信
  Completer<String>? _responseCompleter;

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }
  void _disconnect()
  {
 //   _channel?.sink.close();
    _msgSub.cancel();
    _errSub.cancel();
    _doneSub.cancel();
    super.dispose();
  }
  //WebSocket连接方法
  void _connectToServer() async
  {
    // 停留 1 秒以展示 LOGO 和名称
    await Future.delayed(Duration(seconds: 1));
      // _channel = WebSocketChannel.connect(
      //   Uri.parse('ws://47.111.112.168:9876'),
      // );
      // //测试连接是否成功
      // _channel!.stream.listen(
      //       (message) {
      //
      //     if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      //       _responseCompleter!.complete(message);
      //     }
      //   },
      //   onError: (error) {
      //     Navigator.pushReplacementNamed(
      //       context,
      //       '/error',
      //       arguments: error.toString(),
      //     );
      //   },
      //   onDone: () {
      //     _disconnect();
      //   },
      //   cancelOnError: true,
      // );
    WebSocketManager().Connect();
    _channel=WebSocketManager().channel;
    _msgSub = WebSocketManager().messageStream.listen((msg) {
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
              _responseCompleter!.complete(msg);
            }
    });

    _errSub = WebSocketManager().errorStream.listen((err) {
      Navigator.pushReplacementNamed(
                context,
                '/error',
                arguments:err.toString(),
              );
    });

    _doneSub = WebSocketManager().doneStream.listen((_) {
      _disconnect();
    });

      _responseCompleter = Completer<String>();
      //发送register
      _channel!.sink.add(
        jsonEncode({
          'type': 'register',
          'client_type': 'mobile',
        }),
      );
      //接收回信
      String response = await _responseCompleter!.future;
      Map<String, dynamic> message = jsonDecode(response);

      if (message.containsKey('type')) {
        if (message['type'] == 'register_ack') {
          Uuid=message['uuid'];
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: SocketData(channel: _channel, Uuid: Uuid),
          );
        }
        else {
          Navigator.pushReplacementNamed(
            context,
            '/error',
            arguments:message['reason'],
          );
        }
      }
      else {
        Navigator.pushReplacementNamed(
          context,
          '/error',
        arguments:'服务器回应异常！',
        );
      }
  }
  @override void dispose() {
    _disconnect();
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_circle,
              size: 120,
              color: Colors.lightBlue,
            ), // 使用 Flutter 自带 logo
            SizedBox(height: 20),
            Text(
              'LQMY远程操控',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}