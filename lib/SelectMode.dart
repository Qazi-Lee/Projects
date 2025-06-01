import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import 'WebSocketManager.dart';
import 'Argument.dart';

class SelectMode extends StatelessWidget {
   SelectMode({super.key});

  final List<String> modes = [
    '低延迟模式',
    '高画质模式',
    '自动模式'
  ];

  late StreamSubscription _msgSub;
  WebSocketChannel? _channel;
   String? _Uuid;
   String? _target;
   String? _jwt;
   String? _device_serial;

  void _disconnect()
  {
    //告知电脑端断开连接，本身不进行断开操作
    _channel!.sink.add(
      jsonEncode({
        'type': 'message',
        'target_uuid': _target,
        'from': _Uuid,
        'payload':jsonEncode({
          'cmd':'disconnect',
          'data':jsonEncode({
            'jwt': _jwt,
            'device_serial': _device_serial,
          })
        })
      }),
    );

  }

   void _selectMode(BuildContext context, int mode) {
     switch(mode)
     {
       case 0:
         {_Low(context);
         break;}
       case 1:
         {_High(context);
         break;}
       case 2:
         {_Auto(context);
         break;}
     }
   }

  @override
  Widget build(BuildContext context) {
    final args=ModalRoute.of(context)!.settings.arguments as SocketConnectData;
    _channel = args.channel;
    _Uuid=args.Uuid;
    _target=args.target;
    _jwt=args.jwt;
    _device_serial=args.device_serial;

    _msgSub = WebSocketManager().messageStream.listen((msg) {
      Map<String, dynamic> data=jsonDecode(msg);
      if(data.containsKey('payload'))
        {
          Map<String, dynamic> data1=data['payload'];
          if(data1.containsKey('cmd'))
            {
              if(data1['cmd']=='disconnect')
                {
                  //返回上一级
                  Navigator.pop(context);
                }
            }
        }

    });
    // return GestureDetector(
    //     onHorizontalDragEnd: (details) {
    //   // 检测左滑（从右向左）
    //   if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
    //     _disconnect();
    //     Navigator.pushReplacementNamed(context, '/login');
    //   }
    // },
    return WillPopScope(
        onWillPop: () async {
          _disconnect();
         // Navigator.pushReplacementNamed(context, '/login');
          Navigator.pop(context);
          return false;
        },
    child:Scaffold(
      appBar: AppBar(
        title: Text('模式选择'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _disconnect();
            Navigator.pop(context);
          }
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: modes.length,
                separatorBuilder: (_, i) => Divider(height: 20),
                itemBuilder: (context, index) => Card(
                  elevation: 4,
                  child: ListTile(
                    title: Text(modes[index],
                        style: TextStyle(fontSize: 18)),
                    contentPadding: EdgeInsets.all(20),
                    trailing: Icon(Icons.adb),
                    onTap: () => _selectMode(context, index),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
  void _Low(BuildContext context)
  {
    String? m_mode="low";
    Navigator.pushNamed(
      context,
      '/video',
      arguments: WebRtcData(channel: _channel, Uuid: _Uuid, target: _target, jwt: _jwt,device_serial:_device_serial,mode: m_mode),
    );
    print('_Low');
  }

  void _High(BuildContext context)
  {
    String? m_mode="high";
    Navigator.pushNamed(
      context,
      '/video',
      arguments: WebRtcData(channel: _channel, Uuid: _Uuid, target: _target, jwt: _jwt,device_serial:_device_serial,mode: m_mode),
    );
    print('_High');
  }

  void _Auto(BuildContext context)
  {
    String? m_mode="balanced";
    Navigator.pushNamed(
      context,
      '/video',
      arguments: WebRtcData(channel: _channel, Uuid: _Uuid, target: _target, jwt: _jwt,device_serial:_device_serial,mode: m_mode),
    );
    print('_Auto');
  }
}