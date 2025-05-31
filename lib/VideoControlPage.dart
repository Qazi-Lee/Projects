import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:projecc/Argument.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'webrtc.dart';
import 'dart:async';
import 'WebSocketManager.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoControlPage extends StatefulWidget {
  const VideoControlPage({super.key});
  @override
  State<VideoControlPage> createState() => _VideoControlPageState();
}

class _VideoControlPageState extends State<VideoControlPage> {
  bool _showKeyboard = false;
  bool _isFullscreen = false;
  String _mode = '普通';
  final List<String> _modes = ['性能', '均衡', '普通'];

  // 新增状态变量
  bool _isControlling = false;
  bool _microphoneOn = false;

  bool _combinationMode = false;
  final List<String> _pressedKeys = [];

  //WebRtc
  WebRTCClient? webrtc;
  //listen
  late StreamSubscription _msgSub;
  //init
  bool _initialized=false;

  void _toggleCombinationMode() {
    setState(() {
      _combinationMode = !_combinationMode;
      if (!_combinationMode && _pressedKeys.isNotEmpty) {
        final comboJson = {
          'type': 'keycombine',
          'key': List.from(_pressedKeys),
        };
        final jsonString = jsonEncode(comboJson);
        debugPrint('组合键发送: $comboJson');
        if (_dataChannel != null) {
          _dataChannel.send(RTCDataChannelMessage(jsonString));
        } else {
          debugPrint('DataChannel 未连接');
        }
        _pressedKeys.clear();
        // TODO: send comboJson to server
      }
    });
  }
  void _toggleKeyboard() {
    setState(() {
      _showKeyboard = !_showKeyboard;
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) setState(() {});
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _switchMode() {
    setState(() {
      int current = _modes.indexOf(_mode);
      _mode = _modes[(current + 1) % _modes.length];
    });
  }

  void _onKeyTap(String key) {
    if (_combinationMode) {
      if (!_pressedKeys.contains(key)) {
        setState(() {
          _pressedKeys.add(key);
        });
      }
    } else {
      debugPrint('单独按键发送: $key');
      // TODO: send {'type': 'singleKey', 'key': key} to server
    }
  }

  // 新增控制逻辑
  void _toggleControl() {
    setState(() {
      _isControlling = !_isControlling;
    });
  }

  void _toggleMicrophone() {
    setState(() {
      _microphoneOn = !_microphoneOn;
    });
  }
  //key
  void _onKeyEvent(String key, String action) {
    if (_combinationMode) {
      if (action == 'down' && !_pressedKeys.contains(key)) {
        setState(() {
          _pressedKeys.add(key);
        });
      }
    } else {
      final message = {
        'type': action == 'down' ? 'keydown' : 'keyup',
        'key': key,
      };
      final jsonString = jsonEncode(message);
      debugPrint('发送按键信息: $message');
      if (_dataChannel != null) {
        _dataChannel.send(RTCDataChannelMessage(jsonString));
      } else {
        debugPrint('DataChannel 未连接');
      }
      // TODO: 通过 WebSocket 或 DataChannel 发送 message

    }
  }
  //触摸板
  void _sendTouchpadMessage(Map<String, dynamic> message) {
    final jsonString = jsonEncode(message);
    debugPrint('发送触摸板消息: $message');
    if (_dataChannel != null) {
      _dataChannel.send(RTCDataChannelMessage(jsonString));
    } else {
      debugPrint('DataChannel 未连接');
    }
    // TODO: 这里替换成你的消息发送逻辑
  }

  @override
  void initState() {
    super.initState();
    _msgSub = WebSocketManager().messageStream.listen((msg){
      Map<String, dynamic> data=jsonDecode(msg);
      if(data.containsKey('payload'))
      {
        Map<String, dynamic> message=data['payload'];
        dynamic msg=message['value'];
        webrtc?.onSignalMessage(msg);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final args=ModalRoute.of(context)?.settings.arguments as WebRtcData?;
    webrtc=WebRTCClient(args?.channel,args?.Uuid,args?.target,args?.jwt);
    webrtc?.onRendererReady = () {
      setState(() {});
    };
    webrtc?.init();
    _initialized=true;
  }
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final isLandscape = media.orientation == Orientation.landscape;

    // 竖屏时，视频高度根据状态变化
    double videoHeight;
    if (isLandscape) {
      // 横屏视频高度始终填满屏幕高
      videoHeight = screenHeight;
    } else {
      // 竖屏保持之前逻辑
      videoHeight = _isFullscreen
          ? screenHeight
          : _showKeyboard
          ? screenHeight * 0.4
          : screenHeight * 0.6;
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 视频区域
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: 0,
              left: 0,
              right: 0,
              height: videoHeight,
              child: Container(
                color: Colors.black,
                child: (webrtc != null && webrtc!.remoteRenderer.textureId != null)
                    ? RTCVideoView(
                  webrtc!.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                )
                    : const Center(
                  child: Text(
                    '视频展示区域',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),

            // 竖屏且非全屏时显示所有按键区域（视频下方）
            if (!_isFullscreen && !isLandscape)
              Positioned(
                top: videoHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _toggleKeyboard,
                                child: Text(_showKeyboard ? '关闭键盘' : '打开键盘'),
                              ),
                              ElevatedButton(
                                onPressed: _toggleFullscreen,
                                child: const Text('全屏'),
                              ),
                              ElevatedButton(
                                onPressed: _switchMode,
                                child: Text('模式: $_mode'),
                              ),
                              if (_showKeyboard)
                                ElevatedButton(
                                  onPressed: _toggleCombinationMode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _combinationMode ? Colors.orange : null,
                                  ),
                                  child: Text(_combinationMode ? '完成' : '组合键'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _toggleControl,
                                child: Text(_isControlling ? '停止操控' : '申请操控'),
                              ),
                              ElevatedButton(
                                onPressed: _toggleMicrophone,
                                child: Text(_microphoneOn ? '关闭麦克风' : '打开麦克风'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_showKeyboard)
                      Expanded(
                        child: VirtualKeyboard(
                          onKeyTap: _onKeyTap,
                          activeKeys: _pressedKeys,
                        ),
                      ),
                  ],
                ),
              ),

            // 横屏且非全屏时按键叠加显示在视频底部覆盖区域（固定高度）
            if (!_isFullscreen && isLandscape)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _showKeyboard? 300:60                                                                                                                                ,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: Column(
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 36), // 宽:100，高:40
                                      ),
                                      onPressed: _toggleKeyboard,
                                      child: Text(_showKeyboard ? '关闭键盘' : '打开键盘'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 36), // 宽:100，高:40
                                      ),
                                      onPressed: _toggleFullscreen,
                                      child: const Text('全屏'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 36), // 宽:100，高:40
                                      ),
                                      onPressed: _switchMode,
                                      child: Text('模式: $_mode'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 36), // 宽:100，高:40
                                      ),
                                      onPressed: _toggleControl,
                                      child: Text(_isControlling ? '停止操控' : '申请操控'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 36), // 宽:100，高:40
                                      ),
                                      onPressed: _toggleMicrophone,
                                      child: Text(_microphoneOn ? '关闭麦克风' : '打开麦克风'),
                                    ),
                                    if (_showKeyboard)
                                      ElevatedButton(
                                        onPressed: _toggleCombinationMode,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _combinationMode ? Colors.orange : null,
                                        ),
                                        child: Text(_combinationMode ? '完成' : '组合键'),
                                      ),
                                  ],
                                ),
                              ]),),
                      if (_showKeyboard)
                      Expanded(
                        child: VirtualKeyboard(
                          onKeyTap: _onKeyTap,
                          activeKeys: _pressedKeys,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 全屏时显示退出按钮（横竖屏均显示）
            if (_isFullscreen)
              Positioned(
                top: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: _toggleFullscreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white70,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("退出全屏"),
                ),
              ),
          ],
        ),
      ),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   final screenHeight = MediaQuery.of(context).size.height;
  //   final videoHeight = _isFullscreen
  //       ? screenHeight
  //       : _showKeyboard
  //       ? screenHeight * 0.4
  //       : screenHeight * 0.6;
  //
  //   return Scaffold(
  //     body: SafeArea(
  //       child: Stack(
  //         children: [
  //           // 视频区域
  //           AnimatedPositioned(
  //             duration: const Duration(milliseconds: 200),
  //             top: 0,
  //             left: 0,
  //             right: 0,
  //             height: videoHeight,
  //             child: Container(
  //               color: Colors.black,
  //               child: (webrtc != null && webrtc!.remoteRenderer.textureId != null)
  //                   ? RTCVideoView(
  //                 webrtc!.remoteRenderer,
  //                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
  //               )
  //                   : const Center(
  //                 child: Text(
  //                   '视频展示区域',
  //                   style: TextStyle(color: Colors.white),
  //                 ),
  //               ),
  //             ),
  //           ),
  //
  //           // UI 区域（非全屏时显示）
  //           if (!_isFullscreen)
  //             Positioned(
  //               top: videoHeight,
  //               left: 0,
  //               right: 0,
  //               bottom: 0,
  //               child: Column(
  //                 children: [
  //                   Padding(
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                     child: Column(
  //                       children: [
  //                         Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                           children: [
  //                             ElevatedButton(
  //                               onPressed: _toggleKeyboard,
  //                               child: Text(_showKeyboard ? '关闭键盘' : '打开键盘'),
  //                             ),
  //                             ElevatedButton(
  //                               onPressed: _toggleFullscreen,
  //                               child: const Text('全屏'),
  //                             ),
  //                             ElevatedButton(
  //                               onPressed: _switchMode,
  //                               child: Text('模式: $_mode'),
  //                             ),
  //                             if (_showKeyboard)
  //                               ElevatedButton(
  //                                 onPressed: _toggleCombinationMode,
  //                                 style: ElevatedButton.styleFrom(
  //                                   backgroundColor:
  //                                   _combinationMode ? Colors.orange : null,
  //                                 ),
  //                                 child: Text(_combinationMode ? '完成' : '组合键'),
  //                               ),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 8),
  //                         Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                           children: [
  //                             ElevatedButton(
  //                               onPressed: _toggleControl,
  //                               child: Text(_isControlling ? '停止操控' : '申请操控'),
  //                             ),
  //                             ElevatedButton(
  //                               onPressed: _toggleMicrophone,
  //                               child: Text(_microphoneOn ? '关闭麦克风' : '打开麦克风'),
  //                             ),
  //                           ],
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   if (_showKeyboard)
  //                     Expanded(
  //                       child: VirtualKeyboard(
  //                         onKeyTap: _onKeyTap,
  //                         activeKeys: _pressedKeys,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //
  //           // 全屏退出按钮
  //           if (_isFullscreen)
  //             Positioned(
  //               top: 20,
  //               right: 20,
  //               child: ElevatedButton(
  //                 onPressed: _toggleFullscreen,
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.white70,
  //                   foregroundColor: Colors.black,
  //                 ),
  //                 child: const Text("退出全屏"),
  //               ),
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

}

class VirtualKeyboard extends StatelessWidget {
  final void Function(String) onKeyTap;
  final List<String> activeKeys;

  const VirtualKeyboard({
    super.key,
    required this.onKeyTap,
    required this.activeKeys,
  });


  static const List<List<String>> _keyboardLayout = [
    ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
    ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Backspace'],
    ['Tab', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '\\'],
    ['Caps', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', 'Enter'],
    ['Shift', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', 'Shift'],
    ['Ctrl', 'Alt', 'Space', 'Alt', 'Ctrl'],
  ];
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView( // 允许整个键盘上下滚动
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _keyboardLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: row
                    .map((key) => Padding(
                  padding: const EdgeInsets.all(2),
                  child: _buildKeyButton(key),
                ))
                    .toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   return Column(
  //     children: _keyboardLayout.map((row) {
  //       return Expanded(
  //         child: SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             children: row
  //                 .map((key) => Padding(
  //               padding: const EdgeInsets.all(2),
  //               child: _buildKeyButton(key),
  //             ))
  //                 .toList(),
  //           ),
  //         ),
  //       );
  //     }).toList(),
  //   );
  // }

  Widget _buildKeyButton(String key) {
    double width = 40;
    if (key == 'Backspace' || key == 'Enter' || key == 'Shift' || key == 'Space') {
      width = key == 'Space' ? 200 : 80;
    } else if (key == 'Tab' || key == 'Caps' || key == 'Ctrl' || key == 'Alt') {
      width = 60;
    }
    final isActive = activeKeys.contains(key);
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: () => onKeyTap(key),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.blue : null,
          padding: const EdgeInsets.all(8),
        ),
        child: Text(key, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}