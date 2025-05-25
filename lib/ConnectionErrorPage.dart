import 'package:flutter/material.dart';
import 'package:projecc/WebSocketManager.dart';

class ConnectionErrorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = ModalRoute.of(context)!.settings.arguments as String? ??'未知错误！';
    return Scaffold(
      appBar: AppBar(title: Text('连接失败')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('连接服务器失败：', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text(error, style: TextStyle(color: Colors.red)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 重新尝试连接
                WebSocketManager().disconnect();
                Navigator.pushReplacementNamed(context, '/',
                );
              },
              child: Text('重新连接'),
            ),
          ],
        ),
      ),
    );
  }
}