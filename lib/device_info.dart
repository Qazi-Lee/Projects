import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceInfo {

  static Future<String> getDeviceName() async {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      return deviceName;
  }

  static Future<String> getSerialNumber() async {

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final androidId = androidInfo.id; // ANDROID_ID
    return androidId;
  }
}