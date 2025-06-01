import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'Argument.dart';
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
  WebRtcData? args;
  // 新增状态变量
  bool _isControlling = false;
  bool _microphoneOn = false;

  bool _combinationMode = false;
  final List<String> _pressedKeys = [];

  Offset? _lastFocalPoint;
  TapDownDetails? _lastTapDownDetails;

  //WebRtc
  WebRTCClient? webrtc;
  //listen
  late StreamSubscription _msgSub;
  //init
  bool _initialized=false;

  //获取渲染流比例
  double? getRemoteVideoAspectRatio() {
    final videoWidth = webrtc?.remoteRenderer.videoWidth;
    final videoHeight =webrtc?.remoteRenderer.videoHeight;
    if (videoWidth != 0 && videoHeight != 0) {
      return videoWidth!/videoHeight!;
    }
    return null;
  }
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
        if (webrtc?.dataChannel != null) {
          webrtc?.dataChannel .send(RTCDataChannelMessage(jsonString));
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

  // 新增控制逻辑
  void _toggleControl() {
    if(!_isControlling)
      {
        webrtc?.webSocket?.sink.add(
          jsonEncode({
            'type': 'message',
            'target_uuid': args?.target,
            'from':args?.Uuid,
            'payload':jsonEncode({
              'cmd':'control',
              'data':jsonEncode({
                'jwt': args?.jwt,
                'uuid': args?.Uuid,
                'device_serial': args?.device_serial,
              })
            })
          }),
        );
      }
    else
      {
        //停止操控
        webrtc?.webSocket?.sink.add(
          jsonEncode({
            'type': 'message',
            'target_uuid': args?.target,
            'from':args?.Uuid,
            'payload':jsonEncode({
              'cmd':'revokectrl',
              'data':jsonEncode({
                'jwt': args?.jwt,
                'uuid': args?.Uuid,
                'device_serial': args?.device_serial,
              })
            })
          }),
        );
        setState(() {
          _isControlling = !_isControlling;
        });
      }

  }
  void _toggleMicrophone() {
    if (webrtc?.localStream.getAudioTracks().first != null) {
      webrtc?.localStream
          .getAudioTracks()
          .first
          .enabled = _microphoneOn;
    }
    setState(() {
      _microphoneOn = !_microphoneOn;
    });
  }
  //keyEvent
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
      if (webrtc?.dataChannel != null) {
        webrtc?.dataChannel .send(RTCDataChannelMessage(jsonString));
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
    if (webrtc?.dataChannel  != null) {
      webrtc?.dataChannel .send(RTCDataChannelMessage(jsonString));
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
        if(message.containsKey('cmd'))
          {
            if(message['cmd']!='disconnect')
              {
                if(message.containsKey('value'))
                  {
                    dynamic msg=message['value'];
                    webrtc?.onSignalMessage(msg);
                  }
              }
          }
        else if(message.containsKey('body')&&message.containsKey('status'))
          {
            if(!_isControlling)
              {
                if(message['status']=='200')
                {
                  setState(() {
                    _isControlling=!_isControlling;
                  });
                }
                else
                {
                  Fluttertoast.cancel();
                  Fluttertoast.showToast(msg: "申请操控失败");
                }
              }
            else
              {
                if(message['status']=='100')
                  {
                    setState(() {
                      _isControlling=!_isControlling;
                    });
                  }
              }

          }
      }
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    args=ModalRoute.of(context)?.settings.arguments as WebRtcData?;
    webrtc=WebRTCClient(args?.channel,args?.Uuid,args?.target,args?.jwt,args?.mode);
    webrtc?.onRendererReady = () {
      setState(() {});
    };
    webrtc?.onConnectClosed=(){
      //返回上一级
      webrtc?.dispose();
      Navigator.pop(context);
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

    return  WillPopScope(
        onWillPop: () async {
          //发送一条关闭消息
          webrtc?.webSocket?.sink.add(
            jsonEncode({
              'type': 'message',
              'target_uuid': args?.target,
              'from':args?.Uuid,
              'payload':jsonEncode({
                'cmd':'closertc',
                'data':jsonEncode({
                  'jwt': args?.jwt,
                  'uuid': args?.Uuid,
                  'device_serial': args?.device_serial,
                })
              })
            }),
          );
         webrtc?.close();
         Navigator.pop(context);
         return false;
        },
      child:Scaffold(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final containerSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
                  final aspectRatio = getRemoteVideoAspectRatio() ?? (16 / 9); // 动态获取或默认

                  Size videoSize;
                  double offsetX = 0, offsetY = 0;

                  if (containerSize.width / containerSize.height > aspectRatio) {
                    // 左右黑边
                    videoSize = Size(containerSize.height * aspectRatio, containerSize.height);
                    offsetX = (containerSize.width - videoSize.width) / 2;
                  } else {
                    // 上下黑边
                    videoSize = Size(containerSize.width, containerSize.width / aspectRatio);
                    offsetY = (containerSize.height - videoSize.height) / 2;
                  }
                  Offset normalize(Offset pos) {
                    final x = (pos.dx - offsetX).clamp(0, videoSize.width);
                    final y = (pos.dy - offsetY).clamp(0, videoSize.height);
                    return Offset(x / videoSize.width, y / videoSize.height);
                  }

                  Offset calcDelta(Offset current, Offset last) {
                    return Offset(
                      (current.dx - last.dx) / videoSize.width,
                      (current.dy - last.dy) / videoSize.height,
                    );
                  }
                  // 在 build 中构造各个手势识别器工厂
                  final Map<Type, GestureRecognizerFactory>
                  gestureFactories = {
                    // 单指点击
                    TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        TapGestureRecognizer>(
                          () => TapGestureRecognizer(debugOwner: this),
                          (TapGestureRecognizer instance) {
                        instance.onTapDown = (TapDownDetails details) {
                          _lastTapDownDetails = details;
                          final pos = normalize(details.localPosition);
                          _sendTouchpadMessage({
                            "type": "touchpad",
                            "event": "click",
                            "position": {"x": pos.dx, "y": pos.dy},
                            "button": "left",
                          });
                        };
                      },
                    ),
                    // 双击
                    DoubleTapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        DoubleTapGestureRecognizer>(
                          () => DoubleTapGestureRecognizer(debugOwner: this),
                          (DoubleTapGestureRecognizer instance) {
                            instance.onDoubleTapDown = (TapDownDetails details) {
                              _lastTapDownDetails = details;
                            };
                            instance.onDoubleTap = () {
                          if (_lastTapDownDetails != null) {
                            final pos = normalize(
                                _lastTapDownDetails!.localPosition);
                            _sendTouchpadMessage({
                              "type": "touchpad",
                              "event": "click",
                              "position": {"x": pos.dx, "y": pos.dy},
                              "button": "left",
                              "doubleTap": true,
                            });
                          }
                        };
                      },
                    ),
                    // 拖动（单指） & 滑动/滚动（双指及以上）
                    ScaleGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        ScaleGestureRecognizer>(
                          () => ScaleGestureRecognizer(debugOwner: this),
                          (ScaleGestureRecognizer instance) {
                        instance
                          ..onStart = (ScaleStartDetails details) {
                            _lastFocalPoint = details.focalPoint;
                            final pos = normalize(details.focalPoint);
                            if(details.pointerCount == 1)
                              {
                                _sendTouchpadMessage({
                                  "type": "touchpad",
                                  "event": "drag_start",
                                  "position": {
                                    "x": pos.dx ,
                                    "y": pos.dy ,
                                  },
                                  "button": "left",
                                });
                              }
                          }
                          ..onUpdate = (ScaleUpdateDetails details) {
                            if (_lastFocalPoint == null) {
                              _lastFocalPoint = details.focalPoint;
                              return;
                            }

                            final delta = calcDelta(details.focalPoint, _lastFocalPoint!);
                            _lastFocalPoint = details.focalPoint;

                            if (details.pointerCount == 1) {
                              // 单指拖动
                              _sendTouchpadMessage({
                                "type": "touchpad",
                                "event": "drag_update",
                                "delta": {
                                  "dx": delta.dx ,
                                  "dy": delta.dy ,
                                },
                                "button": "left",
                              });
                            } else if (details.pointerCount >= 2) {
                              // 双指或多指滑动/滚动
                              _sendTouchpadMessage({
                                "type": "touchpad",
                                "event": "scroll",
                                "delta": {
                                  "dx": delta.dx ,
                                  "dy": delta.dy ,
                                },
                              });
                            }
                          }
                          ..onEnd = (ScaleEndDetails details) {
                            // 拖动结束
                            _sendTouchpadMessage({
                              "type": "touchpad",
                              "event": "drag_end",
                              "button": "left",
                            });
                            _lastFocalPoint = null;
                          };
                      },
                    ),
                  };
                  return Listener(
                    // onPointerDown: (_) => _pointerCount++,
                    // onPointerUp: (_) => _pointerCount = (_pointerCount - 1).clamp(0, 10),
                    // onPointerCancel: (_) => _pointerCount = (_pointerCount - 1).clamp(0, 10),
                     onPointerSignal: (event) {
                       if (event is PointerScrollEvent) {
                         final delta = event.scrollDelta;
                         _sendTouchpadMessage({
                           "type": "touchpad",
                           "event": "scroll",
                           "delta": {
                             "dx": delta.dx / videoSize.width,
                             "dy": delta.dy / videoSize.height,
                           },
                         });
                       }
                     },
                    child: RawGestureDetector(
                      gestures: gestureFactories,
                      behavior: HitTestBehavior.opaque,
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
                  );
                },
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
                          onKeyEvent: _onKeyEvent,
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
                          onKeyEvent: _onKeyEvent,
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
      ),
    );
  }

  @override
  void dispose()
  {
    super.dispose();
    //告知关闭
    webrtc?.webSocket?.sink.add(
      jsonEncode({
        'type': 'message',
        'target_uuid': args?.target,
        'from':args?.Uuid,
        'payload':jsonEncode({
          'cmd':'closertc',
          'data':jsonEncode({
            'jwt': args?.jwt,
            'uuid': args?.Uuid,
            'device_serial': args?.device_serial,
          })
        })
      }),
    );
    //释放资源
    _msgSub.cancel();
    webrtc?.close();
  }
}

class VirtualKeyboard extends StatelessWidget {
  final void Function(String key, String action) onKeyEvent;
  final List<String> activeKeys;

  const VirtualKeyboard({
    super.key,
    required this.onKeyEvent,
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
      child: Listener(
        onPointerDown: (_) => onKeyEvent(key, 'down'),
        onPointerUp: (_) => onKeyEvent(key, 'up'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue :Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 2),
                blurRadius: 2,
              )
            ],
          ),
          child: Text(
            key,
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
      ),
    );
  }
}