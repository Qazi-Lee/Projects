import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'Argument.dart';
import 'webrtc.dart';
import 'dart:async';
import 'WebSocketManager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'VirtualKeyLayout.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer';

/// 把 List<VirtualKeyConfig> 渲染为覆盖在屏幕上的虚拟按键
class FloatingVirtualKeys extends StatelessWidget {
  final List<VirtualKeyConfig> keys;
  final void Function(String key, String action) onKeyEvent;

  const FloatingVirtualKeys({
    super.key,
    required this.keys,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: keys.map((config) {
        return Positioned(
          left: config.position.dx,
          top: config.position.dy,
          width: config.size.width,
          height: config.size.height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onKeyEvent(config.key, 'down'),
            onPointerUp: (_) => onKeyEvent(config.key, 'up'),
            onPointerCancel: (_) => onKeyEvent(config.key, 'up'),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                config.key,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class VideoControlPage extends StatefulWidget {
  const VideoControlPage({super.key});
  @override
  State<VideoControlPage> createState() => _VideoControlPageState();
}

//主界面
class _VideoControlPageState extends State<VideoControlPage> {
  String _currentLayoutName = '';

  // 所有可用布局的名字列表
   List<String> _layoutNames = [];

  // 布局 -> 普通按键列表
   Map<String, List<VirtualKeyConfig>> _layoutMap = {};

  // 布局 -> 摇杆占位列表
   Map<String, List<JoystickPlaceholder>> _joystickMap = {};
  //初始化布局
  bool _islayoutinit=false;
  //layout文件
  late File _layoutsFile;

  Future<void> _initLayouts() async {

    final dir = await getApplicationDocumentsDirectory();
    log('保存路径为: $dir', name: 'layout');
    _layoutsFile = File('${dir.path}/layouts.json');

    if (await _layoutsFile.exists()) {
      try {
        final content = await _layoutsFile.readAsString();
        final Map<String, dynamic> data = json.decode(content);

        _layoutNames = data.keys.toList();
        for (var name in _layoutNames) {
          final entry = data[name] as Map<String, dynamic>;
          final keysJson = entry['keys'] as List<dynamic>;
          final joysJson = entry['joysticks'] as List<dynamic>;

          _layoutMap[name] = keysJson
              .map((e) => VirtualKeyConfig.fromJson(e as Map<String, dynamic>))
              .toList();

          _joystickMap[name] = joysJson
              .map((e) => JoystickPlaceholder.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        if (_layoutNames.isNotEmpty) {
          _currentLayoutName = _layoutNames.first;
        }
      } catch (_) {
        // 如果 JSON 解析失败，则初始化为空
        _layoutNames = [];
        _layoutMap = {};
        _joystickMap = {};
      }
    } else {
      // 文件不存在，写入空结构
      await _saveLayouts();
    }

    setState(() {
      _islayoutinit = true;
    });
  }

  //写入文件
  Future<void> _saveLayouts() async {
    final Map<String, dynamic> data = {};
    for (var name in _layoutNames) {
      data[name] = {
        'keys': _layoutMap[name]!.map((k) => k.toJson()).toList(),
        'joysticks': _joystickMap[name]!.map((j) => j.toJson()).toList(),
      };
    }
    final content = json.encode(data);
    await _layoutsFile.writeAsString(content);
  }

  // 用于触发“输入设置”弹窗并更新布局
  void _showInputSettingsDialog(BuildContext context) {
    String tempSelected = _currentLayoutName;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('输入设置', style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1) 下拉列表，选已有布局
                  DropdownButton<String>(
                    dropdownColor: Colors.grey[850],
                    value: tempSelected,
                    items: _layoutNames.map((layout) {
                      return DropdownMenuItem(
                        value: layout,
                        child: Text(layout, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateSB(() {
                          tempSelected = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 2) 编辑布局按钮
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _editLayout(tempSelected);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('编辑布局', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  // 3) 添加布局按钮
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _createNewLayout();
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('添加布局', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 取消，什么都不做
                  },
                  child: const Text('取消', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    // 确认：把临时选择的布局写入 _currentLayoutName 并关闭弹窗
                    setState(() {
                      _currentLayoutName = tempSelected;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('确认', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 跳转到编辑页面，传入布局名
  Future<void> _editLayout(String layoutName) async {
    final originalKeys = _layoutMap[layoutName]!.map((e) => e.copy()).toList();
    final originalJoys = (_joystickMap[layoutName] ?? []).map((e) => e.copy()).toList();

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LayoutEditorPage(
          layoutName: layoutName,
          existingNames: _layoutNames,
          initialKeyConfig: originalKeys,
          initialJoystickPlaceholder: originalJoys,
        ),
      ),
    );

    if (result != null) {
      final newName = result['name'] as String;
      final updatedKeys = List<VirtualKeyConfig>.from(result['keys']);
      final updatedJoys = List<JoystickPlaceholder>.from(result['joysticks']);

      setState(() {
        // 如果名称变了，先移除旧的，再插入新的
        if (newName != layoutName) {
          _layoutNames.remove(layoutName);
          _layoutNames.add(newName);

          _layoutMap.remove(layoutName);
          _joystickMap.remove(layoutName);
        }
        // 更新数据
        _layoutMap[newName] = updatedKeys;
        _joystickMap[newName] = updatedJoys;
        _currentLayoutName = newName;
      });

      await _saveLayouts();
    }
  }

  // 跳转到新建布局页面
  Future<void> _createNewLayout() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LayoutCreatePage(
          existingNames: _layoutNames,
        ),
      ),
    );

    if (result != null) {
      final newName = result['name'] as String;
      final newKeys = List<VirtualKeyConfig>.from(result['keys']);
      final newJoys = List<JoystickPlaceholder>.from(result['joysticks']);

      setState(() {
        _layoutNames.add(newName);
        _layoutMap[newName] = newKeys;
        _joystickMap[newName] = newJoys;
        _currentLayoutName = newName;
      });

      await _saveLayouts();
    }
  }

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
      }
  }
  //帮助界面
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('帮助'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '手势说明：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 单指点击：模拟鼠标左键点击'),
              Text('• 单指双击：模拟鼠标左键双击'),
              Text('• 单指拖动：模拟鼠标左键按住并拖动'),
              Text('• 双指滑动：模拟鼠标移动（不点击）'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
  // void _toggleMicrophone() {
  //   if (webrtc?.localStream.getAudioTracks().first != null) {
  //     webrtc?.localStream
  //         .getAudioTracks()
  //         .first
  //         .enabled = _microphoneOn;
  //   }
  //   setState(() {
  //     _microphoneOn = !_microphoneOn;
  //   });
  // }
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
  //摇杆
  void _onJoystickDrag(double x, double y) {
    final message = {
      'type':'joystick',
      'x': x,
      'y':y,
    };
    final jsonString = jsonEncode(message);
    debugPrint('发送按键信息: $message');
    if (webrtc?.dataChannel != null) {
      webrtc?.dataChannel .send(RTCDataChannelMessage(jsonString));
    } else {
      debugPrint('DataChannel 未连接');
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
    _initLayouts();
    super.initState();
    // 进入页面时设置为横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    //设置为全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
            if(message['status']=='200'||message['status']=='100')
            {
              setState(() {
                _isControlling=!_isControlling;
              });
            }
            else
            {
              if(!_isControlling)
                Fluttertoast.cancel();
              Fluttertoast.showToast(msg: "申请操控失败");
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
Widget build(BuildContext context)
  {
    //加载布局时转圈
    if (!_islayoutinit) {
      // 正在加载时显示空白或加载指示器
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    return  WillPopScope(
      onWillPop: () async {
        final result = await showGeneralDialog<String>(
          context: context,
          barrierDismissible: true,
          barrierLabel: "菜单",
          transitionDuration: Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.grey[900],
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ListTile(
                        leading: Icon(_showKeyboard?Icons.keyboard_hide:Icons.keyboard, color: Colors.white),
                        title: Text(_showKeyboard?'收起键盘':'呼出键盘', style: TextStyle(color: Colors.white)),
                        onTap: () => Navigator.pop(context, 'keyboard'),
                      ),
                      ListTile(
                        leading: Icon(_isControlling?Icons.cancel:Icons.touch_app, color: Colors.white),
                        title: Text(_isControlling?'取消操控':'申请操控', style: TextStyle(color: Colors.white)),
                        onTap: () => Navigator.pop(context, 'control'),
                      ),
                      ListTile(
                        leading: Icon(Icons.settings, color: Colors.white),
                        title: Text('输入设置', style: TextStyle(color: Colors.white)),
                        onTap: () => Navigator.pop(context, 'input_settings'),
                      ),
                      ListTile(
                        leading: Icon(Icons.help_outline, color: Colors.white),
                        title: Text('帮助', style: TextStyle(color: Colors.white)),
                        onTap: () => Navigator.pop(context, 'help'),
                      ),
                      ListTile(
                        leading: Icon(Icons.exit_to_app, color: Colors.red),
                        title: Text('退出', style: TextStyle(color: Colors.red)),
                        onTap: () => Navigator.pop(context, 'exit'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final offsetAnimation = Tween<Offset>(
              begin: Offset(1, 0),
              end: Offset(0, 0),
            ).animate(animation);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        );

        switch (result) {
          case 'keyboard':
            setState(() {
              _showKeyboard = !_showKeyboard;
            });
            break;
          case 'control':
            _toggleControl();
            break;
          case 'input_settings':
            _showInputSettingsDialog(context);
            break;
          case 'help':
            _showHelpDialog(context);
            break;
          case 'exit':
            webrtc?.close();
            Navigator.pop(context);
            break;
        }
        return false;
    },
    child:Scaffold(
    body: Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: 0,
          left: 0,
          right: 0,
          height: screenHeight,
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
        if (_showKeyboard)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260, // 根据你键盘组件的高度自行调整
            child: Container(
              color: Colors.black.withOpacity(0.25),
              child: VirtualKeyboard(
                onKeyEvent: _onKeyEvent,
               // activeKeys: _pressedKeys,
              ),
            ),
          ),
        // 渲染普通虚拟按键
        if (_layoutMap.containsKey(_currentLayoutName))
          ..._layoutMap[_currentLayoutName]!.map((config) {
            return Positioned(
              left: config.position.dx,
              top: config.position.dy,
              width: config.size.width,
              height: config.size.height,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _onKeyEvent(config.key, 'down'),
                onPointerUp: (_) => _onKeyEvent(config.key, 'up'),
                onPointerCancel: (_) => _onKeyEvent(config.key, 'up'),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    config.key,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }),

        // 渲染摇杆（仅一个）
        if (_joystickMap.containsKey(_currentLayoutName))
          ..._joystickMap[_currentLayoutName]!.map((ph) {
            final half = ph.size / 2;
            return Positioned(
              left: ph.position.dx - half,
              top: ph.position.dy - half,
              width: ph.size,
              height: ph.size,
              child: Joystick(
                listener: (details) {
                  _onJoystickDrag(details.x, details.y);
                },
              ),
            );
          }),
      ],
    ),
    )
    );
  }

  //原版UI
  // @override
  // Widget build(BuildContext context) {
  //   final media = MediaQuery.of(context);
  //   final screenHeight = media.size.height;
  //   final screenWidth = media.size.width;
  //   final isLandscape = media.orientation == Orientation.landscape;
  //
  //   // 竖屏时，视频高度根据状态变化
  //   double videoHeight;
  //   if (isLandscape) {
  //     // 横屏视频高度始终填满屏幕高
  //     videoHeight = screenHeight;
  //   } else {
  //     // 竖屏保持之前逻辑
  //     videoHeight = _isFullscreen
  //         ? screenHeight
  //         : _showKeyboard
  //         ? screenHeight * 0.4
  //         : screenHeight * 0.6;
  //   }
  //
  //   return  WillPopScope(
  //       onWillPop: () async {
  //         //发送一条关闭消息
  //         // webrtc?.webSocket?.sink.add(
  //         //   jsonEncode({
  //         //     'type': 'message',
  //         //     'target_uuid': args?.target,
  //         //     'from':args?.Uuid,
  //         //     'payload':jsonEncode({
  //         //       'cmd':'closertc',
  //         //       'data':jsonEncode({
  //         //         'jwt': args?.jwt,
  //         //         'uuid': args?.Uuid,
  //         //         'device_serial': args?.device_serial,
  //         //       })
  //         //     })
  //         //   }),
  //         // );
  //        webrtc?.close();
  //        Navigator.pop(context);
  //        return false;
  //       },
  //     child:Scaffold(
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
  //             child: LayoutBuilder(
  //               builder: (context, constraints) {
  //                 final containerSize =
  //                 Size(constraints.maxWidth, constraints.maxHeight);
  //                 final aspectRatio = getRemoteVideoAspectRatio() ?? (16 / 9); // 动态获取或默认
  //
  //                 Size videoSize;
  //                 double offsetX = 0, offsetY = 0;
  //
  //                 if (containerSize.width / containerSize.height > aspectRatio) {
  //                   // 左右黑边
  //                   videoSize = Size(containerSize.height * aspectRatio, containerSize.height);
  //                   offsetX = (containerSize.width - videoSize.width) / 2;
  //                 } else {
  //                   // 上下黑边
  //                   videoSize = Size(containerSize.width, containerSize.width / aspectRatio);
  //                   offsetY = (containerSize.height - videoSize.height) / 2;
  //                 }
  //                 Offset normalize(Offset pos) {
  //                   final x = (pos.dx - offsetX).clamp(0, videoSize.width);
  //                   final y = (pos.dy - offsetY).clamp(0, videoSize.height);
  //                   return Offset(x / videoSize.width, y / videoSize.height);
  //                 }
  //
  //                 Offset calcDelta(Offset current, Offset last) {
  //                   return Offset(
  //                     (current.dx - last.dx) / videoSize.width,
  //                     (current.dy - last.dy) / videoSize.height,
  //                   );
  //                 }
  //                 // 在 build 中构造各个手势识别器工厂
  //                 final Map<Type, GestureRecognizerFactory>
  //                 gestureFactories = {
  //                   // 单指点击
  //                   TapGestureRecognizer:
  //                   GestureRecognizerFactoryWithHandlers<
  //                       TapGestureRecognizer>(
  //                         () => TapGestureRecognizer(debugOwner: this),
  //                         (TapGestureRecognizer instance) {
  //                       instance.onTapDown = (TapDownDetails details) {
  //                         _lastTapDownDetails = details;
  //                         final pos = normalize(details.localPosition);
  //                         _sendTouchpadMessage({
  //                           "type": "touchpad",
  //                           "event": "click",
  //                           "position": {"x": pos.dx, "y": pos.dy},
  //                           "button": "left",
  //                         });
  //                       };
  //                     },
  //                   ),
  //                   // 双击
  //                   DoubleTapGestureRecognizer:
  //                   GestureRecognizerFactoryWithHandlers<
  //                       DoubleTapGestureRecognizer>(
  //                         () => DoubleTapGestureRecognizer(debugOwner: this),
  //                         (DoubleTapGestureRecognizer instance) {
  //                           instance.onDoubleTapDown = (TapDownDetails details) {
  //                             _lastTapDownDetails = details;
  //                           };
  //                           instance.onDoubleTap = () {
  //                         if (_lastTapDownDetails != null) {
  //                           final pos = normalize(
  //                               _lastTapDownDetails!.localPosition);
  //                           _sendTouchpadMessage({
  //                             "type": "touchpad",
  //                             "event": "click",
  //                             "position": {"x": pos.dx, "y": pos.dy},
  //                             "button": "left",
  //                             "doubleTap": true,
  //                           });
  //                         }
  //                       };
  //                     },
  //                   ),
  //                   // 拖动（单指） & 滑动/滚动（双指及以上）
  //                   ScaleGestureRecognizer:
  //                   GestureRecognizerFactoryWithHandlers<
  //                       ScaleGestureRecognizer>(
  //                         () => ScaleGestureRecognizer(debugOwner: this),
  //                         (ScaleGestureRecognizer instance) {
  //                       instance
  //                         ..onStart = (ScaleStartDetails details) {
  //                           _lastFocalPoint = details.focalPoint;
  //                           final pos = normalize(details.focalPoint);
  //                           if(details.pointerCount == 1)
  //                             {
  //                               _sendTouchpadMessage({
  //                                 "type": "touchpad",
  //                                 "event": "drag_start",
  //                                 "position": {
  //                                   "x": pos.dx ,
  //                                   "y": pos.dy ,
  //                                 },
  //                                 "button": "left",
  //                               });
  //                             }
  //                         }
  //                         ..onUpdate = (ScaleUpdateDetails details) {
  //                           if (_lastFocalPoint == null) {
  //                             _lastFocalPoint = details.focalPoint;
  //                             return;
  //                           }
  //
  //                           final delta = calcDelta(details.focalPoint, _lastFocalPoint!);
  //                           _lastFocalPoint = details.focalPoint;
  //
  //                           if (details.pointerCount == 1) {
  //                             // 单指拖动
  //                             _sendTouchpadMessage({
  //                               "type": "touchpad",
  //                               "event": "drag_update",
  //                               "delta": {
  //                                 "dx": delta.dx ,
  //                                 "dy": delta.dy ,
  //                               },
  //                               "button": "left",
  //                             });
  //                           } else if (details.pointerCount >= 2) {
  //                             // 双指或多指滑动/滚动
  //                             _sendTouchpadMessage({
  //                               "type": "touchpad",
  //                               "event": "scroll",
  //                               "delta": {
  //                                 "dx": delta.dx ,
  //                                 "dy": delta.dy ,
  //                               },
  //                             });
  //                           }
  //                         }
  //                         ..onEnd = (ScaleEndDetails details) {
  //                           // 拖动结束
  //                           _sendTouchpadMessage({
  //                             "type": "touchpad",
  //                             "event": "drag_end",
  //                             "button": "left",
  //                           });
  //                           _lastFocalPoint = null;
  //                         };
  //                     },
  //                   ),
  //                 };
  //                 return Listener(
  //                   // onPointerDown: (_) => _pointerCount++,
  //                   // onPointerUp: (_) => _pointerCount = (_pointerCount - 1).clamp(0, 10),
  //                   // onPointerCancel: (_) => _pointerCount = (_pointerCount - 1).clamp(0, 10),
  //                    onPointerSignal: (event) {
  //                      if (event is PointerScrollEvent) {
  //                        final delta = event.scrollDelta;
  //                        _sendTouchpadMessage({
  //                          "type": "touchpad",
  //                          "event": "scroll",
  //                          "delta": {
  //                            "dx": delta.dx / videoSize.width,
  //                            "dy": delta.dy / videoSize.height,
  //                          },
  //                        });
  //                      }
  //                    },
  //                   child: RawGestureDetector(
  //                     gestures: gestureFactories,
  //                     behavior: HitTestBehavior.opaque,
  //                     child: Container(
  //                   color: Colors.black,
  //                   child: (webrtc != null && webrtc!.remoteRenderer.textureId != null)
  //                       ? RTCVideoView(
  //                     webrtc!.remoteRenderer,
  //                     objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
  //                   )
  //                       : const Center(
  //                     child: Text(
  //                       '视频展示区域',
  //                       style: TextStyle(color: Colors.white),
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //
  //           // 竖屏且非全屏时显示所有按键区域（视频下方）
  //           if (!_isFullscreen && !isLandscape)
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
  //                             // ElevatedButton(
  //                             //   onPressed: _switchMode,
  //                             //   child: Text('模式: $_mode'),
  //                             // ),
  //                             ElevatedButton(
  //                               onPressed: _toggleControl,
  //                               child: Text(_isControlling ? '停止操控' : '申请操控'),
  //                             ),
  //                             if (_showKeyboard)
  //                               ElevatedButton(
  //                                 onPressed: _toggleCombinationMode,
  //                                 style: ElevatedButton.styleFrom(
  //                                   backgroundColor: _combinationMode ? Colors.orange : null,
  //                                 ),
  //                                 child: Text(_combinationMode ? '完成' : '组合键'),
  //                               ),
  //                           ],
  //                         ),
  //                         // const SizedBox(height: 8),
  //                         // Row(
  //                         //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                         //   children: [
  //                         //
  //                         //     ElevatedButton(
  //                         //       onPressed: _toggleMicrophone,
  //                         //       child: Text(_microphoneOn ? '关闭麦克风' : '打开麦克风'),
  //                         //     ),
  //                         //   ],
  //                         // ),
  //                       ],
  //                     ),
  //                   ),
  //                   if (_showKeyboard)
  //                     Expanded(
  //                       child: VirtualKeyboard(
  //                         onKeyEvent: _onKeyEvent,
  //                         activeKeys: _pressedKeys,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //
  //           // 横屏且非全屏时按键叠加显示在视频底部覆盖区域（固定高度）
  //           if (!_isFullscreen && isLandscape)
  //             Positioned(
  //               left: 0,
  //               right: 0,
  //               bottom: 0,
  //               height: _showKeyboard? 300:60                                                                                                                                ,
  //               child: Container(
  //                 color: Colors.black.withOpacity(0.25),
  //                 child: Column(
  //                   children: [
  //                     Padding(
  //                         padding: const EdgeInsets.symmetric(vertical: 6),
  //                         child: Column(
  //                             children: [
  //                               Row(
  //                                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                                 children: [
  //                                   ElevatedButton(
  //                                     style: ElevatedButton.styleFrom(
  //                                       minimumSize: const Size(80, 36), // 宽:100，高:40
  //                                     ),
  //                                     onPressed: _toggleKeyboard,
  //                                     child: Text(_showKeyboard ? '关闭键盘' : '打开键盘'),
  //                                   ),
  //                                   ElevatedButton(
  //                                     style: ElevatedButton.styleFrom(
  //                                       minimumSize: const Size(80, 36), // 宽:100，高:40
  //                                     ),
  //                                     onPressed: _toggleFullscreen,
  //                                     child: const Text('全屏'),
  //                                   ),
  //                                   // ElevatedButton(
  //                                   //   style: ElevatedButton.styleFrom(
  //                                   //     minimumSize: const Size(80, 36), // 宽:100，高:40
  //                                   //   ),
  //                                   //   onPressed: _switchMode,
  //                                   //   child: Text('模式: $_mode'),
  //                                   // ),
  //                                   ElevatedButton(
  //                                     style: ElevatedButton.styleFrom(
  //                                       minimumSize: const Size(80, 36), // 宽:100，高:40
  //                                     ),
  //                                     onPressed: _toggleControl,
  //                                     child: Text(_isControlling ? '停止操控' : '申请操控'),
  //                                   ),
  //                                   // ElevatedButton(
  //                                   //   style: ElevatedButton.styleFrom(
  //                                   //     minimumSize: const Size(80, 36), // 宽:100，高:40
  //                                   //   ),
  //                                   //   onPressed: _toggleMicrophone,
  //                                   //   child: Text(_microphoneOn ? '关闭麦克风' : '打开麦克风'),
  //                                   // ),
  //                                   if (_showKeyboard)
  //                                     ElevatedButton(
  //                                       onPressed: _toggleCombinationMode,
  //                                       style: ElevatedButton.styleFrom(
  //                                         backgroundColor: _combinationMode ? Colors.orange : null,
  //                                       ),
  //                                       child: Text(_combinationMode ? '完成' : '组合键'),
  //                                     ),
  //                                 ],
  //                               ),
  //                             ]),),
  //                     if (_showKeyboard)
  //                     Expanded(
  //                       child: VirtualKeyboard(
  //                         onKeyEvent: _onKeyEvent,
  //                         activeKeys: _pressedKeys,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //
  //           // 全屏时显示退出按钮（横竖屏均显示）
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
  //     ),
  //   );
  // }

  @override
  void dispose()
  {
    // 离开页面时恢复为允许所有方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    //取消全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

class VirtualKeyboard extends StatefulWidget {
  final void Function(String key, String action) onKeyEvent;

  const VirtualKeyboard({
    super.key,
    required this.onKeyEvent,
  });

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  // 记录 pointerId -> key 的映射
  final Map<int, String> _pointerToKey = {};

  // 当前处于按下状态的所有键
  Set<String> get _activeKeys => _pointerToKey.values.toSet();

  void _handlePointerDown(PointerDownEvent event, String key) {
    if (_pointerToKey.containsKey(event.pointer)) return;
    setState(() {
      _pointerToKey[event.pointer] = key;
    });
    widget.onKeyEvent(key, 'down');
  }

  void _handlePointerUp(PointerUpEvent event) {
    final key = _pointerToKey.remove(event.pointer);
    if (key != null) {
      setState(() {});
      widget.onKeyEvent(key, 'up');
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    final key = _pointerToKey.remove(event.pointer);
    if (key != null) {
      setState(() {});
      widget.onKeyEvent(key, 'up');
    }
  }

  static const List<List<String>> _keyboardLayout = [
    ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
    ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Backspace'],
    ['Tab', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '\\'],
    ['Caps', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', 'Enter'],
    ['Shift', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', 'Shift'],
    ['Ctrl', 'Alt', 'Space', 'Alt', 'Ctrl'],
  ];

  // @override
  // Widget build(BuildContext context) {
  //   return SingleChildScrollView(
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: _keyboardLayout.map((row) {
  //         return Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 2),
  //           child: SingleChildScrollView(
  //             scrollDirection: Axis.horizontal,
  //             child: Row(
  //               children: row.map((key) {
  //                 return Padding(
  //                   padding: const EdgeInsets.all(2),
  //                   child: _buildKeyButton(key),
  //                 );
  //               }).toList(),
  //             ),
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _keyboardLayout.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: row.map((key) {
              return Expanded(
                flex: key == 'Space' ? 5 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: _buildKeyButton(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
  Widget _buildKeyButton(String key) {
    double width = 40;
    if (key == 'Backspace' || key == 'Enter' || key == 'Shift' || key == 'Space') {
      width = key == 'Space' ? 200 : 80;
    } else if (key == 'Tab' || key == 'Caps' || key == 'Ctrl' || key == 'Alt') {
      width = 60;
    }

    final isActive = _activeKeys.contains(key);

    return SizedBox(
      width: width,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _handlePointerDown(e, key),
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent : Colors.white,
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
            style: TextStyle(
              fontSize: 14,
              color: isActive ? Colors.white : Colors.black,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
// class VirtualKeyboard extends StatelessWidget {
//   final void Function(String key, String action) onKeyEvent;
//   final List<String> activeKeys;
//
//   const VirtualKeyboard({
//     super.key,
//     required this.onKeyEvent,
//     required this.activeKeys,
//   });
//
//
//   static const List<List<String>> _keyboardLayout = [
//     ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
//     ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'Backspace'],
//     ['Tab', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '\\'],
//     ['Caps', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', 'Enter'],
//     ['Shift', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', 'Shift'],
//     ['Ctrl', 'Alt', 'Space', 'Alt', 'Ctrl'],
//   ];
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView( // 允许整个键盘上下滚动
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: _keyboardLayout.map((row) {
//           return Padding(
//             padding: const EdgeInsets.symmetric(vertical: 2),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: row
//                     .map((key) => Padding(
//                   padding: const EdgeInsets.all(2),
//                   child: _buildKeyButton(key),
//                 ))
//                     .toList(),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildKeyButton(String key) {
//     double width = 40;
//     if (key == 'Backspace' || key == 'Enter' || key == 'Shift' || key == 'Space') {
//       width = key == 'Space' ? 200 : 80;
//     } else if (key == 'Tab' || key == 'Caps' || key == 'Ctrl' || key == 'Alt') {
//       width = 60;
//     }
//     final isActive = activeKeys.contains(key);
//     return SizedBox(
//       width: width,
//       child: Listener(
//         onPointerDown: (_) => onKeyEvent(key, 'down'),
//         onPointerUp: (_) => onKeyEvent(key, 'up'),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 100),
//           padding: const EdgeInsets.all(8),
//           alignment: Alignment.center,
//           decoration: BoxDecoration(
//             color: isActive ? Colors.blue :Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 offset: const Offset(0, 2),
//                 blurRadius: 2,
//               )
//             ],
//           ),
//           child: Text(
//             key,
//             style: const TextStyle(fontSize: 14, color: Colors.black),
//           ),
//         ),
//       ),
//     );
//   }
// }