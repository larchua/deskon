import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http_lib;

import '../common.dart';
import '../utils/http_service.dart' as http;
import 'model.dart';
import 'platform_model.dart';
import 'usage_time_model.dart';

bool refreshingUser = false;

/// 订阅信息数据模型
class SubscriptionInfo {
  final String planType;
  final String planName;
  final String startTime;
  final String endTime;
  final int daysRemaining;
  final bool isActive;

  SubscriptionInfo({
    required this.planType,
    required this.planName,
    required this.startTime,
    required this.endTime,
    required this.daysRemaining,
    required this.isActive,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      planType: json['plan_type'] ?? '',
      planName: json['plan_name'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      daysRemaining: json['days_remaining'] ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }
}

/// 权限信息数据模型
class PermissionsInfo {
  final int maxDevices;
  final int maxConnections;
  final int? dailyUsageLimitMinutes;

  PermissionsInfo({
    required this.maxDevices,
    required this.maxConnections,
    this.dailyUsageLimitMinutes,
  });

  factory PermissionsInfo.fromJson(Map<String, dynamic> json) {
    return PermissionsInfo(
      maxDevices: json['max_devices'] ?? 10,
      maxConnections: json['max_connections'] ?? 5,
      dailyUsageLimitMinutes: json['daily_usage_limit_minutes'],
    );
  }
}

/// 会员信息数据模型
class MembershipInfo {
  final String userLevel;
  final String levelName;
  final SubscriptionInfo? subscription;
  final PermissionsInfo permissions;
  final bool hasValidSubscription;

  MembershipInfo({
    required this.userLevel,
    required this.levelName,
    this.subscription,
    required this.permissions,
    required this.hasValidSubscription,
  });

  factory MembershipInfo.fromJson(Map<String, dynamic> json) {
    return MembershipInfo(
      userLevel: json['user_level'] ?? '普通用户',
      levelName: json['level_name'] ?? 'normal',
      subscription: json['subscription'] != null
          ? SubscriptionInfo.fromJson(json['subscription'])
          : null,
      permissions:
          PermissionsInfo.fromJson(json['permissions'] ?? <String, dynamic>{}),
      hasValidSubscription: json['has_valid_subscription'] ?? false,
    );
  }
}

class UserModel {
  final RxString userName = ''.obs;
  final RxBool isAdmin = false.obs;
  final RxString networkError = ''.obs;
  final RxString membershipLevel = '普通会员'.obs; // 会员等级显示名称
  final Rx<MembershipInfo?> membershipInfo =
      Rx<MembershipInfo?>(null); // 完整的会员信息
  bool get isLogin => userName.isNotEmpty;
  WeakReference<FFI> parent;
  Timer? _membershipInfoTimer; // 定期获取会员信息的定时器

  UserModel(this.parent) {
    userName.listen((p0) {
      // When user name becomes empty, show login button
      // When user name becomes non-empty:
      //  For _updateLocalUserInfo, network error will be set later
      //  For login success, should clear network error
      networkError.value = '';

      // 用户登录状态变化时，启动或停止定期获取会员信息
      if (p0.isNotEmpty) {
        _startMembershipInfoTimer();
      } else {
        _stopMembershipInfoTimer();
      }
    });

    // 如果已有登录信息，立即启动定时器
    _updateLocalUserInfo();
    if (userName.value.isNotEmpty) {
      _startMembershipInfoTimer();
    }
  }

  /// 启动定期获取会员信息的定时器（每5分钟调用一次）
  void _startMembershipInfoTimer() {
    _stopMembershipInfoTimer(); // 先停止已有的定时器，避免重复启动

    _membershipInfoTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      // 只在用户已登录且账户功能未禁用时调用
      if (isLogin && !bind.isDisableAccount()) {
        debugPrint('[Membership] Periodic refresh membership info');
        await fetchMembershipInfo();
      } else {
        // 如果用户未登录，停止定时器
        _stopMembershipInfoTimer();
      }
    });

    debugPrint(
        '[Membership] Membership info timer started (refresh every 5 minutes)');
  }

  /// 停止定期获取会员信息的定时器
  void _stopMembershipInfoTimer() {
    _membershipInfoTimer?.cancel();
    _membershipInfoTimer = null;
    debugPrint('[Membership] Membership info timer stopped');
  }

  void refreshCurrentUser() async {
    if (bind.isDisableAccount()) return;
    networkError.value = '';
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      await updateOtherModels();
      return;
    }
    _updateLocalUserInfo();
    final url = await bind.mainGetApiServer();
    final body = {
      'id': await bind.mainGetMyId(),
      'uuid': await bind.mainGetUuid()
    };
    if (refreshingUser) return;
    try {
      refreshingUser = true;
      final http.Response response;
      try {
        response = await http.post(Uri.parse('$url/api/currentUser'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token'
            },
            body: json.encode(body));
      } catch (e) {
        networkError.value = e.toString();
        rethrow;
      }
      refreshingUser = false;
      final status = response.statusCode;
      if (status == 401 || status == 400) {
        reset(resetOther: status == 401);
        return;
      }
      final data = json.decode(decode_http_response(response));
      final error = data['error'];
      if (error != null) {
        throw error;
      }

      final user = UserPayload.fromJson(data);
      _parseAndUpdateUser(user);
      // 获取会员信息
      await fetchMembershipInfo();
    } catch (e) {
      debugPrint('Failed to refreshCurrentUser: $e');
    } finally {
      refreshingUser = false;
      await updateOtherModels();
    }
  }

  static Map<String, dynamic>? getLocalUserInfo() {
    final userInfo = bind.mainGetLocalOption(key: 'user_info');
    if (userInfo == '') {
      return null;
    }
    try {
      return json.decode(userInfo);
    } catch (e) {
      debugPrint('Failed to get local user info "$userInfo": $e');
    }
    return null;
  }

  _updateLocalUserInfo() {
    final userInfo = getLocalUserInfo();
    if (userInfo != null) {
      userName.value = userInfo['name'];
    }
  }

  Future<void> reset({bool resetOther = false}) async {
    _stopMembershipInfoTimer(); // 重置时停止定时器
    await bind.mainSetLocalOption(key: 'access_token', value: '');
    await bind.mainSetLocalOption(key: 'user_info', value: '');
    if (resetOther) {
      await gFFI.abModel.reset();
      await gFFI.groupModel.reset();
    }
    userName.value = '';
    membershipLevel.value = '普通会员';
    membershipInfo.value = null; // 清除会员信息
  }

  /// 获取会员信息
  /// 调用 /api/membership/info 接口获取会员信息
  /// 按照 API_MEMBERSHIP.md 规范实现完整功能
  /// [accessToken] 可选的 access_token，如果提供则使用它，否则从本地读取
  Future<void> fetchMembershipInfo([String? accessToken]) async {
    if (bind.isDisableAccount()) {
      debugPrint(
          '[Membership] Account disabled, skip fetching membership info');
      return;
    }
    final token = accessToken ?? bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty) {
      debugPrint('[Membership] No access token, set to default');
      membershipLevel.value = '普通会员';
      membershipInfo.value = null;
      return;
    }

    try {
      final url = await bind.mainGetApiServer();
      if (url.isEmpty) {
        debugPrint('[Membership] API server URL is empty');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
        return;
      }

      debugPrint(
          '[Membership] Fetching membership info from: $url/api/membership/info');
      final headers = getHttpHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse('$url/api/membership/info'),
        headers: headers,
      );

      debugPrint('[Membership] Response status: ${response.statusCode}');
      final status = response.statusCode;
      if (status == 401 || status == 400) {
        debugPrint(
            '[Membership] Unauthorized (status: $status), set to default');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
        return;
      }

      if (status != 200) {
        debugPrint('[Membership] HTTP error: $status');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
        return;
      }

      final responseBody = decode_http_response(response);
      debugPrint('[Membership] Response body: $responseBody');

      if (responseBody.isEmpty) {
        debugPrint('[Membership] Empty response body');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
        return;
      }

      final data = json.decode(responseBody);

      // 检查是否有错误
      if (data['error'] != null) {
        debugPrint('[Membership] Error in response: ${data['error']}');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
        return;
      }

      // 解析会员信息 - 按照 API_MEMBERSHIP.md 规范
      if (data['code'] == 1) {
        try {
          final info = MembershipInfo.fromJson(data);
          membershipInfo.value = info;

          // 如果是管理员，优先显示管理员
          if (isAdmin.value) {
            membershipLevel.value = '管理员';
          } else {
            membershipLevel.value = info.userLevel;
          }

          debugPrint('[Membership] Successfully parsed membership info:');
          debugPrint('  - User Level: ${info.userLevel}');
          debugPrint('  - Level Name: ${info.levelName}');
          debugPrint(
              '  - Has Valid Subscription: ${info.hasValidSubscription}');
          debugPrint('  - Max Devices: ${info.permissions.maxDevices}');
          debugPrint('  - Max Connections: ${info.permissions.maxConnections}');
          debugPrint(
              '  - Daily Usage Limit: ${info.permissions.dailyUsageLimitMinutes ?? "无限制"}');

          if (info.subscription != null) {
            debugPrint('  - Subscription: ${info.subscription!.planName}');
            debugPrint(
                '  - Days Remaining: ${info.subscription!.daysRemaining}');

            // 订阅提醒：剩余天数小于7天时提醒
            if (info.subscription!.daysRemaining < 7 &&
                info.subscription!.daysRemaining > 0) {
              debugPrint(
                  '[Membership] Warning: Subscription expires in ${info.subscription!.daysRemaining} days');
            }
          }

          debugPrint(
              '[Membership] Final membership level: ${membershipLevel.value}');
        } catch (e, stackTrace) {
          debugPrint('[Membership] Failed to parse membership info: $e');
          debugPrint('[Membership] Stack trace: $stackTrace');
          membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
          membershipInfo.value = null;
        }
      } else {
        // 如果响应代码不是1，使用默认值
        debugPrint('[Membership] Invalid response code: ${data['code']}');
        membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
        membershipInfo.value = null;
      }
    } catch (e, stackTrace) {
      debugPrint('[Membership] Failed to fetchMembershipInfo: $e');
      debugPrint('[Membership] Stack trace: $stackTrace');
      membershipLevel.value = isAdmin.value ? '管理员' : '普通会员';
      membershipInfo.value = null;
    }
  }

  /// 检查是否可以添加新设备
  bool canAddDevice(int currentDeviceCount) {
    if (!isLogin || membershipInfo.value == null) {
      return currentDeviceCount < 10; // 默认限制
    }
    return currentDeviceCount < membershipInfo.value!.permissions.maxDevices;
  }

  /// 检查是否可以建立新连接
  bool canMakeConnection(int currentConnectionCount) {
    if (!isLogin || membershipInfo.value == null) {
      return currentConnectionCount < 5; // 默认限制
    }
    return currentConnectionCount <
        membershipInfo.value!.permissions.maxConnections;
  }

  /// 获取每日使用时长限制（分钟），null 表示无限制
  int? getDailyUsageLimitMinutes() {
    if (!isLogin || membershipInfo.value == null) {
      return 60; // 默认60分钟
    }
    return membershipInfo.value!.permissions.dailyUsageLimitMinutes;
  }

  /// 是否为高级会员（有有效订阅）
  bool isPremiumUser() {
    if (!isLogin || membershipInfo.value == null) {
      return false;
    }
    return membershipInfo.value!.hasValidSubscription;
  }

  /// 是否需要订阅提醒（剩余天数小于7天）
  bool shouldShowSubscriptionReminder() {
    if (!isLogin || membershipInfo.value == null) {
      return false;
    }
    final subscription = membershipInfo.value!.subscription;
    if (subscription == null || !subscription.isActive) {
      return false;
    }
    return subscription.daysRemaining < 7 && subscription.daysRemaining > 0;
  }

  /// 获取订阅剩余天数
  int? getSubscriptionDaysRemaining() {
    if (!isLogin || membershipInfo.value == null) {
      return null;
    }
    return membershipInfo.value!.subscription?.daysRemaining;
  }

  /// 修改密码
  /// 调用 /api/user/change-password 接口修改密码
  /// 按照 API_USER_PROFILE.md 规范实现
  Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
    if (bind.isDisableAccount()) {
      throw Exception('账户功能已禁用');
    }
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      throw Exception('用户未登录');
    }

    try {
      final url = await bind.mainGetApiServer();
      if (url.isEmpty) {
        throw Exception('API服务器地址未配置');
      }

      debugPrint('[UserProfile] Changing password...');
      final headers = getHttpHeaders();
      headers['Content-Type'] = 'application/json';

      final body = json.encode({
        'access_token': token,
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      final response = await http.post(
        Uri.parse('$url/api/user/change-password'),
        headers: headers,
        body: body,
      );

      debugPrint(
          '[UserProfile] Change password response status: ${response.statusCode}');
      final responseBody = decode_http_response(response);
      debugPrint('[UserProfile] Change password response body: $responseBody');

      final data = json.decode(responseBody);

      if (data['code'] == 1) {
        debugPrint('[UserProfile] Password changed successfully');
        return {'success': true, 'msg': data['msg'] ?? '密码修改成功。'};
      } else {
        final errorMsg = data['msg'] ?? '密码修改失败';
        debugPrint('[UserProfile] Password change failed: $errorMsg');
        return {'success': false, 'msg': errorMsg};
      }
    } catch (e, stackTrace) {
      debugPrint('[UserProfile] Failed to change password: $e');
      debugPrint('[UserProfile] Stack trace: $stackTrace');
      return {'success': false, 'msg': '密码修改失败: $e'};
    }
  }

  /// 上传头像
  /// 调用 /api/user/upload-avatar 接口上传头像
  /// 按照 API_USER_PROFILE.md 规范实现
  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    if (bind.isDisableAccount()) {
      throw Exception('账户功能已禁用');
    }
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      throw Exception('用户未登录');
    }

    try {
      final url = await bind.mainGetApiServer();
      if (url.isEmpty) {
        throw Exception('API服务器地址未配置');
      }

      debugPrint('[UserProfile] Uploading avatar from: $filePath');

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在');
      }

      // 检查文件大小（最大5MB）
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('文件大小不能超过5MB');
      }

      // 检查文件格式
      final extension = filePath.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        throw Exception('不支持的文件类型，仅支持JPG、PNG、GIF格式');
      }

      // 创建 multipart request
      final request = http_lib.MultipartRequest(
        'POST',
        Uri.parse('$url/api/user/upload-avatar'),
      );

      // 添加 headers
      request.headers.addAll(getHttpHeaders());
      request.headers['Authorization'] = 'Bearer $token';

      // 添加文件
      final multipartFile = await http_lib.MultipartFile.fromPath(
        'avatar',
        filePath,
        filename: file.path.split(Platform.pathSeparator).last,
      );
      request.files.add(multipartFile);

      // 发送请求
      final streamedResponse = await request.send();
      final response = await http_lib.Response.fromStream(streamedResponse);

      debugPrint(
          '[UserProfile] Upload avatar response status: ${response.statusCode}');
      final responseBody = decode_http_response(response);
      debugPrint('[UserProfile] Upload avatar response body: $responseBody');

      final data = json.decode(responseBody);

      if (data['code'] == 1) {
        final avatarUrl = data['data']?['avatar_url'];
        debugPrint('[UserProfile] Avatar uploaded successfully: $avatarUrl');

        // 更新本地用户信息中的头像
        final userInfo = getLocalUserInfo();
        if (userInfo != null) {
          userInfo['avatar'] = avatarUrl;
          await bind.mainSetLocalOption(
              key: 'user_info', value: json.encode(userInfo));
          // 触发用户信息更新
          _updateLocalUserInfo();
        }

        return {
          'success': true,
          'msg': data['msg'] ?? '头像上传成功。',
          'avatar_url': avatarUrl,
        };
      } else {
        final errorMsg = data['msg'] ?? '头像上传失败';
        debugPrint('[UserProfile] Avatar upload failed: $errorMsg');
        return {'success': false, 'msg': errorMsg};
      }
    } catch (e, stackTrace) {
      debugPrint('[UserProfile] Failed to upload avatar: $e');
      debugPrint('[UserProfile] Stack trace: $stackTrace');
      return {'success': false, 'msg': '头像上传失败: $e'};
    }
  }

  _parseAndUpdateUser(UserPayload user) {
    userName.value = user.name;
    isAdmin.value = user.isAdmin;
    bind.mainSetLocalOption(key: 'user_info', value: jsonEncode(user));
    if (isWeb) {
      // ugly here, tmp solution
      bind.mainSetLocalOption(key: 'verifier', value: user.verifier ?? '');
    }
    // 用户登录成功后重置使用时间限制
    if (user.name.isNotEmpty) {
      UsageTimeModel.reset();
    }
    // 注意：这里不调用 fetchMembershipInfo()，因为 access_token 可能还没有保存
    // 会员信息将在 token 保存后立即拉取
  }

  // update ab and group status
  static Future<void> updateOtherModels() async {
    await Future.wait([
      gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: false),
      gFFI.groupModel.pull()
    ]);
  }

  Future<void> logOut({String? apiServer}) async {
    _stopMembershipInfoTimer(); // 登出时停止定时器
    final tag = gFFI.dialogManager.showLoading(translate('Waiting'));
    try {
      final url = apiServer ?? await bind.mainGetApiServer();
      final authHeaders = getHttpHeaders();
      authHeaders['Content-Type'] = "application/json";
      await http
          .post(Uri.parse('$url/api/logout'),
              body: jsonEncode({
                'id': await bind.mainGetMyId(),
                'uuid': await bind.mainGetUuid(),
              }),
              headers: authHeaders)
          .timeout(Duration(seconds: 2));
    } catch (e) {
      debugPrint("request /api/logout failed: err=$e");
    } finally {
      await reset(resetOther: true);
      gFFI.dialogManager.dismissByTag(tag);
    }
  }

  /// throw [RequestException]
  Future<LoginResponse> login(LoginRequest loginRequest) async {
    final url = await bind.mainGetApiServer();
    final resp = await http.post(Uri.parse('$url/api/login'),
        body: jsonEncode(loginRequest.toJson()));

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(decode_http_response(resp));
    } catch (e) {
      debugPrint("login: jsonDecode resp body failed: ${e.toString()}");
      if (resp.statusCode != 200) {
        BotToast.showText(
            contentColor: Colors.red, text: 'HTTP ${resp.statusCode}');
      }
      rethrow;
    }
    if (resp.statusCode != 200) {
      throw RequestException(resp.statusCode, body['error'] ?? '');
    }
    if (body['error'] != null) {
      throw RequestException(0, body['error']);
    }

    return getLoginResponseFromAuthBody(body);
  }

  LoginResponse getLoginResponseFromAuthBody(Map<String, dynamic> body) {
    final LoginResponse loginResponse;
    try {
      loginResponse = LoginResponse.fromJson(body);
    } catch (e) {
      debugPrint("login: jsonDecode LoginResponse failed: ${e.toString()}");
      rethrow;
    }

    final isLogInDone = loginResponse.type == HttpType.kAuthResTypeToken &&
        loginResponse.access_token != null;
    if (isLogInDone && loginResponse.user != null) {
      _parseAndUpdateUser(loginResponse.user!);
      // 注意：这里不调用 fetchMembershipInfo()，因为 access_token 还没有保存
      // 会员信息将在 handleLoginResponse 中保存 token 后立即拉取
    }

    return loginResponse;
  }

  static Future<List<dynamic>> queryOidcLoginOptions() async {
    try {
      final url = await bind.mainGetApiServer();
      if (url.trim().isEmpty) return [];
      final resp = await http.get(Uri.parse('$url/api/login-options'));
      if (resp.statusCode != 200) {
        debugPrint("queryOidcLoginOptions: HTTP ${resp.statusCode}");
        return [];
      }
      final decodedBody = jsonDecode(resp.body);
      // 处理服务器返回Map的情况（某些后端可能返回 {"options": [...]}）
      dynamic optionsData = decodedBody;
      if (decodedBody is Map && decodedBody.containsKey('options')) {
        optionsData = decodedBody['options'];
      } else if (decodedBody is Map && decodedBody.containsKey('data')) {
        optionsData = decodedBody['data'];
      }

      // 确保是List类型
      if (optionsData is! List) {
        debugPrint(
            "queryOidcLoginOptions: Response is not a list, got ${optionsData.runtimeType}");
        return [];
      }

      final List<String> ops = [];
      for (final item in optionsData) {
        if (item is String) {
          ops.add(item);
        } else if (item is Map && item['name'] != null) {
          ops.add(item['name'].toString());
        }
      }
      for (final item in ops) {
        if (item.startsWith('common-oidc/')) {
          return jsonDecode(item.substring('common-oidc/'.length));
        }
      }
      return ops
          .where((item) => item.startsWith('oidc/'))
          .map((item) => {'name': item.substring('oidc/'.length)})
          .toList();
    } catch (e) {
      debugPrint(
          "queryOidcLoginOptions: jsonDecode resp body failed: ${e.toString()}");
      return [];
    }
  }
}
