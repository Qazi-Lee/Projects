import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import'dart:io';
import'dart:convert';
import 'dart:async';

import'WebSocketManager.dart';
import'Argument.dart';
import 'SelectMode.dart';
import 'device_info.dart';

//裁剪器
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
        size.width * 0.25, size.height,
        size.width * 0.5, size.height * 0.8
    );
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.6,
        size.width, size.height * 0.8
    );
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  WebSocketChannel? _channel;
  late StreamSubscription _msgSub;
  late StreamSubscription _errSub;
  late StreamSubscription _doneSub;


  String? deviceName;
  String? serialNumber;
  String? Message;
  String? Uuid;
  String? Jwt;
  //接收回信
  Completer<String>? _responseCompleter;



  //获取设备信息
  Future<void> loadDeviceInfo() async {
    final name = await DeviceInfo.getDeviceName();
    final serial = await DeviceInfo.getSerialNumber();
    setState(() {
      deviceName = name;
      serialNumber = serial;
    });
  }

  //WebSocket连接方法
  void _connectToServer()
  {
      final args =  ModalRoute.of(context)?.settings.arguments as SocketData ?;
      if(args!=null)
        {
          _channel=args.channel;
          Uuid=args.Uuid;

          _msgSub = WebSocketManager().messageStream.listen((msg) {
            final data=jsonDecode(msg);
            if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
              _responseCompleter!.complete(msg);
            }
          });

          _errSub = WebSocketManager().errorStream.listen((err) {
            Navigator.pushReplacementNamed(
              context,
              '/error',
              arguments: err.toString(),

            );
          });

          _doneSub = WebSocketManager().doneStream.listen((_) {
            Navigator.pushReplacementNamed(
              context,
              '/server',
            );
          });

          //开始心跳
          //   Fluttertoast.cancel();
          //   Fluttertoast.showToast(msg: "ping");
          WebSocketManager().startHeartbeat(Uuid);
        }

  }

  //初始话过程中获取设备信息
  @override
  void initState() {
    super.initState();
    //启动时连接到服务器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToServer();
    });
    loadDeviceInfo();
  }
  //通知电脑端断开连接,服务器连接不断开
  void _disconnect()
  {
    _responseCompleter=null;
    _channel!.sink.add(
      jsonEncode({
        'type': 'message',
        'target_uuid': _targetController.text,
        'from':Uuid,
        'payload':jsonEncode({
          'cmd':'disconnect',
          'data':jsonEncode({
            'device_name': deviceName,
            'device_serial': serialNumber,
            'password': _tokenController.text,
          })
        })
      }),
    );
  }

  //服务器连接断开
  void _closeConnect()
  {
    //发送消息后会接收到关闭帧
    _responseCompleter=null;
    _channel?.sink.add(jsonEncode({'type':'close'}));
    _close();
  }

  void _close()
  {
   // _channel?.sink.close();
    _msgSub.cancel();
    _errSub.cancel();
    _doneSub.cancel();
    super.dispose();
  }
  //同步执行，不完成注册则无法继续
  Future<bool> _verification() async
  {
    _responseCompleter = Completer<String>();
    //发送message
    _channel!.sink.add(
      jsonEncode({
        'type': 'message',
        'target_uuid': _targetController.text,
        'from':Uuid,
        'payload':jsonEncode({
          'cmd':'auth',
          'data':jsonEncode({
            'device_name': deviceName,
            'device_serial': serialNumber,
            'password': _tokenController.text,
            'uuid':Uuid,
          })
        })
      }),
    );
    //接收回信
    String response =await _responseCompleter!.future;
    Map<String, dynamic> message= jsonDecode(response);
    if(message.containsKey('payload'))
    {
      Map<String,dynamic> message1=message['payload'];
      if(message1.containsKey('status'))
        {
          //连接成功
          if(message1['status']=='200')
          {
            Jwt=message1['body'];
            Fluttertoast.cancel();
            Fluttertoast.showToast(msg: Jwt.toString());
            return true;
          }
          else
          {
            Fluttertoast.cancel();
            Fluttertoast.showToast(msg: message1['body'].toString());
            return false;
          }
        }
      else
        {
          Fluttertoast.cancel();
          Fluttertoast.showToast(msg: "找不到status！");
          return false;
        }
    }
    else
    {
      Fluttertoast.cancel();
      Fluttertoast.showToast(msg: "找不到payload！");
      return false;
    }
  }



  void _login() async {
    if (_formKey.currentState!.validate()) {
      // 这里可以添加实际的登录逻辑
      final success=await _verification();
      if(success) {
        Navigator.pushNamed(
          context,
          '/mode',
            arguments:SocketConnectData(channel: _channel, Uuid: Uuid, target: _targetController.text, jwt: Jwt, device_serial: serialNumber),
        );
      }
 //      Navigator.pushNamed(
 //        context,
 //        '/mode',
 // );
      // 模拟网络请求延迟
      await Future.delayed(Duration(seconds: 1));
    }
  }
  @override
  void dispose() {
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueGrey.shade800,
                  Colors.blueGrey.shade200,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 顶部装饰
          Positioned(
            top: -size.width * 0.2,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // 连接表单
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 图标标题
                          Icon(Icons.cloud_circle,
                            size: 60,
                            color: Colors.blueGrey.shade800,
                          ),
                          SizedBox(height: 20),
                          Text('连接设备',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                          SizedBox(height: 30),

                          // IP输入
                          TextFormField(
                            controller: _targetController,
                            decoration: InputDecoration(
                              labelText: '目标UID',
                              prefixIcon: Icon(Icons.dns),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value!.isEmpty) return '请输入目标UID';
                              if (value.length<10) return '无效的UID';
                              return null;
                            },
                          ),
                          SizedBox(height: 20),

                          // 令牌输入
                          TextFormField(
                            controller: _tokenController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: '安全令牌',
                              prefixIcon: Icon(Icons.security),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value!.isEmpty) return '请输入访问令牌';
                              if (value.length < 8) return '令牌至少需要8位字符';
                              return null;
                            },
                          ),
                          SizedBox(height: 30),

                          // 连接按钮
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Colors.blueGrey.shade800,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('立即连接',
                                style: TextStyle(
                                    fontSize: 16,
                                    letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 底部波浪装饰
          Positioned(
            bottom: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                width: size.width,
                height: 100,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

}