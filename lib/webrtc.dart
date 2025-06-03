import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class WebRTCClient {
  VoidCallback? onRendererReady;
  void _notifyRendererReady() {
    if (onRendererReady != null) {
      onRendererReady!();
    }
  }
  VoidCallback? onConnectClosed;
  String? _mode;

  bool _isExiting = false;
  bool _handClose=false;
  bool _handlingDisconnect=false;
  void _handlePotentialDisconnect() {
    if(_handClose) return;
    if (_handlingDisconnect) return; // 避免重复触发
    _handlingDisconnect = true;
    // 延迟 5 秒后再检测状态
    Future.delayed(Duration(seconds: 3), () {
      final currentState= _peerConnection.connectionState;
      final currentIceState = _peerConnection.iceConnectionState;
      log("5 秒后 ICE 状态为: $currentIceState", name: 'WebRTC');
      if (currentState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected||
          currentState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handClose=true;
        _handlingDisconnect = false;
        onConnectClosed!();
        return ;
      }
      if (currentIceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected||
      currentIceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handClose=true;
        _handlingDisconnect = false;
        onConnectClosed!();
        return ;
      }
    });
  }

  late WebSocketChannel? webSocket;
  late RTCPeerConnection _peerConnection;
  late RTCDataChannel _dataChannel;
  late MediaStream _localStream;
  late RTCVideoRenderer _remoteRenderer;
  MediaStream get localStream =>_localStream;

  String? _Uuid;
  String? _target;
  String? _jwt;


  //String? _sessionId; // 保存服务端返回的 session_id
  WebRTCClient(WebSocketChannel? channel,String? Uuid,String? target,String? jwt,String? mode){
    webSocket=channel; _Uuid=Uuid;_target=target;_jwt=jwt;_mode=mode;
  }
  Future<void> init() async {

    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer.initialize();
    log('Renderer initialized, textureId: ${_remoteRenderer.textureId}',name: 'WebRTC');
    _remoteRenderer.onFirstFrameRendered = () {
      log('✅ 首帧已渲染', name: 'WebRTC');
    };
    _remoteRenderer.onResize=(){
      log('Renderer resized to: ${_remoteRenderer.videoWidth}x${_remoteRenderer.videoHeight}',name: 'WebRTC');
      _notifyRendererReady();
    };

    // 1. 创建 PeerConnection
    Map<String, dynamic> config = {
      'iceServers': [
        {'urls': 'stun:stun.l.qq.com:3478'}
      ]
    };
    _peerConnection = await createPeerConnection(config);
    //设置状态回调函数
    _peerConnection.onConnectionState = (RTCPeerConnectionState state) {
      log('onConnectionState:$state',name:'WebRTC');
      if(!_handClose)
        {
          if ( state == RTCPeerConnectionState.RTCPeerConnectionStateClosed)
          {
            if(!_isExiting)
            {
              _handClose=true;
              onConnectClosed!();
              return;
            }
          }
          else if(state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
              state == RTCPeerConnectionState.RTCPeerConnectionStateFailed )
          {
            if(!_isExiting)
            {

              _handlePotentialDisconnect();

              return;
            }
          }
        }
    };
    // _peerConnection.onIceConnectionState = (RTCIceConnectionState state)
    // {
    //   log('onIceConnectionState:$state',name:'WebRTC');
    //   if(!_handClose)
    //     {
    //       if ( state == RTCIceConnectionState.RTCIceConnectionStateClosed)
    //       {
    //         if(!_isExiting)
    //         {
    //           _handClose=true;
    //           onConnectClosed!();
    //           return;
    //         }
    //       }
    //       if(state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
    //           state == RTCIceConnectionState.RTCIceConnectionStateFailed)
    //       {
    //         if(!_isExiting)
    //         {
    //           _handClose=true;
    //           _handlePotentialDisconnect();
    //           return;
    //         }
    //       }
    //     }
    // };


    // 2. 获取音频流（不获取视频）
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // 3. 添加音频轨道到 PeerConnection
    // 只获取第一个音频轨道（通常就是麦克风）
    var audioTracks = _localStream.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      await _peerConnection.addTrack(audioTracks[0], _localStream);
    }
  /*  await _peerConnection.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
        streams: [], // 显式提供空流，确保加上
      ),
    );
*/
    // 4. 监听远端轨道，接收视频流
    _peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video'&& event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        log('视频流已连接', name: 'WebRTC');
        log('srcObject 设置为: ${_remoteRenderer.srcObject?.id}');
        Future.delayed(Duration(seconds: 1), () {
          log('Renderer textureId after 1s: ${_remoteRenderer.textureId}',name:'WebRTC');
        });
      }
      if (event.track.kind == 'audio') {
        log('接收到音频流', name: 'WebRTC');
      }

    };
   /* _peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        // 1. 如果 SDK 已经在 event.streams 里给你挂好了
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          log('📺 视频流已连接（自带 stream）', name: 'WebRTC');
        } else {
          // 2. 否则，自己创建一个 MediaStream，再把 track 插进去
          createLocalMediaStream('remote').then((MediaStream stream) {
            stream.addTrack(event.track);       // 挂上收到的远端 track
            _remoteRenderer.srcObject = stream; // 绑定到 renderer
            log('📺 视频流已连接（手动创建 stream）', name: 'WebRTC');
          });
        }
      }

      if (event.track.kind == 'audio') {
        log('🎧 接收到音频流', name: 'WebRTC');
        // 同理可以处理音频，但通常你会放在不同的 Renderer 或不展示。
      }
    };
*/


    // 5. 监听 ICE candidate，发送给对端
    /*  _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        webSocket.sink.add(jsonEncode({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdp_mid': candidate.sdpMid,
          'sdp_mline_index': candidate.sdpMLineIndex,
        }));
      }
    };*/




    // 6. 创建 DataChannel
    _dataChannel = await _peerConnection.createDataChannel(
      'control',
      RTCDataChannelInit()..ordered = true,
    );
    _dataChannel.onDataChannelState = (state) {
      log('DataChannel state: $state', name: 'WebRTC');
    };

    _dataChannel.onMessage = (RTCDataChannelMessage message) {
      log('Received DataChannel message:${message.text}',name:'WebRTC');
    };

    //7.发送offer
   //await
   createOffer();

  }
void TestRener() async
{
  if (remoteRenderer.srcObject != null &&
      remoteRenderer.srcObject!.getVideoTracks().isNotEmpty) {
    log('远程视频流已绑定并包含视频轨道', name: 'WebRTC');
    log('远程对象: ${remoteRenderer.srcObject}');
    log('包含 video tracks: ${remoteRenderer.srcObject?.getVideoTracks().length}');
  } else {
    log('尚未接收到远程视频流', name: 'WebRTC');
  }
  final track = remoteRenderer.srcObject?.getVideoTracks().first;
  log('Track enabled: ${track?.enabled}', name: 'WebRTC');
  log('Track muted: ${track?.muted}', name: 'WebRTC');
  var stats = await _peerConnection.getStats();
  for (var report in stats) {
    if (report.type == 'inbound-rtp' && report.values['kind'] == 'video') {
      log('📈 视频统计信息', name: 'WebRTC');
      log('帧数: ${report.values['framesDecoded']}', name: 'WebRTC');
      log('字节数: ${report.values['bytesReceived']}', name: 'WebRTC');
      log('丢包数: ${report.values['packetsLost']}', name: 'WebRTC');
      log('抖动: ${report.values['jitter']}', name: 'WebRTC');
    }
  }
}
  // 7. 创建 offer 并发送
  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection.createOffer();
    //print(offer.sdp);
    await _peerConnection.setLocalDescription(offer);
    webSocket?.sink.add(jsonEncode({
    'type': 'message',
    'target_uuid': _target,
    'from':_Uuid,
    'payload':jsonEncode({
    'cmd':'offer',
    'data':jsonEncode({
    'sdp': offer.sdp,
    'mode': _mode,
    'client_uuid':_Uuid,
    'jwt':_jwt,
       })
    }),
    }));
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        //打印添加信息
        final candidateMsg = jsonEncode({
          'type': 'message',
          'target_uuid': _target,
          'from':_Uuid,
          'payload':jsonEncode({
            'cmd':'candidate',
            'data':jsonEncode({
              'candidate': candidate.candidate,
              'sdp_mid': candidate.sdpMid,
              'sdp_mline_index': candidate.sdpMLineIndex,
              'client_uuid':_Uuid,
              'jwt':_jwt,
            })
          }),
        });
        SendCandidateMsg(candidateMsg);
      //  webSocket?.sink.add(candidateMsg);
      }
    };
  }
  void SendCandidateMsg(String? Msg) async
  {
    await Future.delayed(Duration(milliseconds: 100));
    webSocket?.sink.add(Msg);
  }
  // 8. 处理 answer
//设置webrtc的远端描述
  Future<void> handleAnswer(String sdp) async {
    final answer = RTCSessionDescription(sdp, 'answer'); // 手动指定 type
    await _peerConnection.setRemoteDescription(answer);
  }
//读取answer中的session_id并保存
  void onSignalMessage(dynamic message) async {
    try {
      final Map<String, dynamic> data = message;

      if (data.containsKey('sdp')) {
        // 设置远端 SDP
        await handleAnswer(data['sdp']);

        // 提取并保存 session_id
      } else if (data.containsKey('candidates')) {
        // 处理 ICE 候选
        await addCandidate(data['candidates']);
      }

      // 你可以继续扩展：例如处理 hangup、错误等消息类型

    } catch (e) {
      //print('Error parsing signal message: $e');
      log('Error parsing signal message: $e',name:'WebRTC');
    }
  }
  // 9. 添加 candidate
  Future<void> addCandidate(Map<String, dynamic> candidateMap) async {

    if(candidateMap.containsKey('candidate') && candidateMap['candidate'] != null
        &&candidateMap.containsKey('sdp_mid') && candidateMap['sdp_mid'] != null
        &&candidateMap.containsKey('sdp_mline_index') && candidateMap['sdp_mline_index'] != null)
      {
        RTCIceCandidate candidate = RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdp_mid'],
          candidateMap['sdp_mline_index'],
        );
        //await _peerConnection.addIceCandidate(candidate);
        log('addCandidate',name:'WebRTC');
        await _peerConnection.addCandidate(candidate);
      }
  }



  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  RTCDataChannel get dataChannel => _dataChannel;

  void dispose() {
    _dataChannel.close();
    _remoteRenderer.dispose();
    _localStream.dispose();
    _peerConnection.close();
  }

  void close() {
    _isExiting=true;
    dispose();
  }
}
