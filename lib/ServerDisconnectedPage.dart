import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'WebSocketManager.dart';

class ServerDisconnectedPage extends StatelessWidget {
  const ServerDisconnectedPage({super.key});

  void _exitApp() {
    // Android/iOS 的安全退出方式
    WebSocketManager().dispose();
    if (Platform.isAndroid) {
      SystemNavigator.pop(); // 推荐方式
    } else if (Platform.isIOS) {
      exit(0); // iOS 上没有 SystemNavigator.pop()
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 100, color: Colors.redAccent),
                const SizedBox(height: 20),
                const Text(
                  '服务器连接已断开',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '请检查网络或稍后再试。',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: Icon(Icons.exit_to_app),
                  label: const Text('退出应用'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _exitApp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}