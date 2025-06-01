import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketData
{
  WebSocketChannel? channel;
  String? Uuid;
  SocketData({required this.channel, required this.Uuid});
}

class SocketConnectData
{
  WebSocketChannel? channel;
  String? Uuid;
  String? target;
  String? jwt;
  String? device_serial;
  SocketConnectData({required this.channel,required this.Uuid,required this.target,required this.jwt,required this.device_serial});
}

class WebRtcData
{
  WebSocketChannel? channel;
  String? Uuid;
  String? target;
  String? jwt;
  String? device_serial;
  String? mode;
  WebRtcData({required this.channel,required this.Uuid,required this.target,required this.jwt,required this.device_serial,required this.mode});
}