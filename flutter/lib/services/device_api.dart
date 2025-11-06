import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;

/// 设备API服务类，用于设备注册和心跳保活
class DeviceApi {
  /// 注册/更新设备信息
  /// 
  /// 根据API文档，使用 POST /api/sysinfo 接口
  /// 需要参数: id, uuid, cpu, hostname, memory, os, version, username(可选)
  static Future<Map<String, dynamic>?> registerDevice() async {
    try {
      final base = await bind.mainGetApiServer();
      if (base.trim().isEmpty) {
        debugPrint('[DeviceApi] API server is empty, skip device registration');
        return null;
      }

      final deviceId = await bind.mainGetMyId();
      if (deviceId.isEmpty) {
        debugPrint('[DeviceApi] device_id is empty, skip device registration');
        return null;
      }

      // 获取设备信息
      String deviceInfoJson = '';
      try {
        deviceInfoJson = bind.mainGetLoginDeviceInfo();
      } catch (e) {
        debugPrint('[DeviceApi] Failed to get device info: $e');
        return null;
      }

      if (deviceInfoJson.isEmpty) {
        debugPrint('[DeviceApi] Device info is empty, skip device registration');
        return null;
      }

      // 解析设备信息
      Map<String, dynamic> deviceInfo;
      try {
        deviceInfo = jsonDecode(deviceInfoJson);
      } catch (e) {
        debugPrint('[DeviceApi] Failed to parse device info: $e');
        return null;
      }

      // 获取UUID
      final uuid = await bind.mainGetUuid();

      // 构建请求体
      final body = {
        'id': deviceId,
        'uuid': uuid,
        'cpu': deviceInfo['cpu'] ?? '',
        'hostname': deviceInfo['hostname'] ?? '',
        'memory': deviceInfo['memory'] ?? '',
        'os': deviceInfo['os'] ?? '',
        'version': deviceInfo['version'] ?? version,
        if (deviceInfo['username'] != null) 'username': deviceInfo['username'],
      };

      final resp = await http.post(
        Uri.parse('$base/api/sysinfo'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final result = jsonDecode(decode_http_response(resp));
        if (result['error'] != null) {
          debugPrint('[DeviceApi] Device registration error: ${result['error']}');
          return null;
        }
        debugPrint('[DeviceApi] Device registered successfully');
        return result;
      } else {
        debugPrint('[DeviceApi] Device registration failed: HTTP ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[DeviceApi] Device registration error => $e');
      return null;
    }
  }

  /// 心跳保活
  /// 
  /// 根据API文档，使用 POST /api/heartbeat 接口
  /// 需要参数: id, uuid
  /// 建议每30-60秒发送一次
  static Future<Map<String, dynamic>?> sendHeartbeat() async {
    try {
      final base = await bind.mainGetApiServer();
      if (base.trim().isEmpty) {
        debugPrint('[DeviceApi] API server is empty, skip heartbeat');
        return null;
      }

      final deviceId = await bind.mainGetMyId();
      if (deviceId.isEmpty) {
        debugPrint('[DeviceApi] device_id is empty, skip heartbeat');
        return null;
      }

      final uuid = await bind.mainGetUuid();

      final body = {
        'id': deviceId,
        'uuid': uuid,
      };

      final resp = await http.post(
        Uri.parse('$base/api/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final result = jsonDecode(decode_http_response(resp));
        if (result['error'] != null) {
          debugPrint('[DeviceApi] Heartbeat error: ${result['error']}');
          return null;
        }
        debugPrint('[DeviceApi] Heartbeat sent successfully');
        return result;
      } else {
        debugPrint('[DeviceApi] Heartbeat failed: HTTP ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[DeviceApi] Heartbeat error => $e');
      return null;
    }
  }
}
