import 'dart:async';
import 'package:flutter/foundation.dart';
import '../common.dart';
import 'platform_model.dart';

/// 使用时间追踪模型
/// 用于限制未登录用户每天只能使用远程控制1小时
class UsageTimeModel {
  static const String _keyUsageStartTime = 'usage_start_time';
  static const String _keyDailyUsageDate =
      'daily_usage_date'; // 日期（格式：YYYY-MM-DD）
  static const String _keyDailyUsageSeconds =
      'daily_usage_seconds'; // 当天的使用时间（秒）
  static const int _maxUsageSeconds = 3600; // 每天1小时 = 3600秒

  /// 检查是否可以使用远程控制
  /// 如果未登录且当天使用时间超过1小时，返回false
  /// 已登录用户不受此限制（由服务器控制权限）
  static bool canUseRemoteControl() {
    if (gFFI.userModel.isLogin) {
      // 已登录用户不受本地时间限制，权限由服务器控制
      return true;
    }

    final dailySeconds = _getTodayUsageSeconds();
    return dailySeconds < _maxUsageSeconds;
  }

  /// 获取今日剩余使用时间（秒）
  static int getRemainingSeconds() {
    if (gFFI.userModel.isLogin) {
      // 已登录用户无本地时间限制，权限由服务器控制
      return -1;
    }

    final dailySeconds = _getTodayUsageSeconds();
    final remaining = _maxUsageSeconds - dailySeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 获取今日已使用时间（秒）
  static int getUsedSeconds() {
    if (gFFI.userModel.isLogin) {
      return 0;
    }
    return _getTodayUsageSeconds();
  }

  /// 开始记录使用时间（连接成功后调用）
  static void startTracking() {
    if (gFFI.userModel.isLogin) {
      // 已登录用户不需要追踪
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setOption(_keyUsageStartTime, now.toString());
    debugPrint('[UsageTime] Started tracking usage time at: $now');
  }

  /// 实时更新使用时间（定时调用，每秒一次）
  /// 返回 true 表示可以继续使用，false 表示已达到限制
  static bool updateUsageTime() {
    if (gFFI.userModel.isLogin) {
      // 已登录用户不需要追踪
      return true;
    }

    final startTimeStr = getOption(_keyUsageStartTime);
    if (startTimeStr.isEmpty) {
      // 没有正在进行的会话
      return true;
    }

    final startTime = int.tryParse(startTimeStr);
    if (startTime == null) {
      return true;
    }

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final sessionDuration = nowSeconds - startTime;

    // 检查是否是同一天
    final today = _getTodayString();
    final savedDate = getOption(_keyDailyUsageDate);

    int dailySeconds = 0;
    if (savedDate == today) {
      // 同一天，获取已使用时间
      final dailyStr = getOption(_keyDailyUsageSeconds);
      dailySeconds = int.tryParse(dailyStr) ?? 0;
    } else {
      // 新的一天，重置使用时间
      dailySeconds = 0;
    }

    // 计算当前会话开始前的已使用时间
    // 如果会话跨天，需要重置
    final sessionStartDate =
        DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
    final sessionStartDateStr =
        '${sessionStartDate.year}-${sessionStartDate.month.toString().padLeft(2, '0')}-${sessionStartDate.day.toString().padLeft(2, '0')}';

    if (sessionStartDateStr != today) {
      // 会话跨天了，重置开始时间
      setOption(_keyUsageStartTime, nowSeconds.toString());
      dailySeconds = 0;
      setOption(_keyDailyUsageDate, today);
      setOption(_keyDailyUsageSeconds, '0');
      return true;
    }

    // 计算当前总使用时间（包括正在进行的会话）
    final currentTotalSeconds = dailySeconds + sessionDuration;

    // 如果达到限制，保存当前会话时间并返回false
    if (currentTotalSeconds >= _maxUsageSeconds) {
      // 保存已使用的时间（达到限制的时间）
      final newDailyTotal = _maxUsageSeconds; // 最多只能到限制值
      setOption(_keyDailyUsageDate, today);
      setOption(_keyDailyUsageSeconds, newDailyTotal.toString());
      setOption(_keyUsageStartTime, ''); // 清除开始时间，停止追踪
      debugPrint('[UsageTime] Usage limit reached: $newDailyTotal seconds');
      return false;
    }

    // 每10秒更新一次累积时间（避免频繁写入）
    if (sessionDuration % 10 == 0) {
      final newDailyTotal = dailySeconds + sessionDuration;
      setOption(_keyDailyUsageDate, today);
      setOption(_keyDailyUsageSeconds, newDailyTotal.toString());
      debugPrint('[UsageTime] Updated usage time: $newDailyTotal seconds');
    }

    return true;
  }

  /// 停止记录使用时间并累积到当天（连接断开时调用）
  static void stopTracking() {
    if (gFFI.userModel.isLogin) {
      // 已登录用户不需要追踪
      return;
    }

    final startTimeStr = getOption(_keyUsageStartTime);
    if (startTimeStr.isEmpty) {
      // 可能已经被updateUsageTime清除（达到限制时）
      return;
    }

    final startTime = int.tryParse(startTimeStr);
    if (startTime == null) {
      return;
    }

    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final sessionDuration = nowSeconds - startTime;

    if (sessionDuration > 0) {
      // 检查是否是同一天
      final today = _getTodayString();
      final savedDate = getOption(_keyDailyUsageDate);

      int dailySeconds = 0;
      if (savedDate == today) {
        // 同一天，获取已使用时间
        final dailyStr = getOption(_keyDailyUsageSeconds);
        dailySeconds = int.tryParse(dailyStr) ?? 0;
      } else {
        // 新的一天，重置使用时间
        dailySeconds = 0;
      }

      // 确保不超过限制
      final newDailyTotal =
          (dailySeconds + sessionDuration).clamp(0, _maxUsageSeconds);
      setOption(_keyDailyUsageDate, today);
      setOption(_keyDailyUsageSeconds, newDailyTotal.toString());
      debugPrint(
          '[UsageTime] Session ended. Duration: $sessionDuration seconds, Today total: $newDailyTotal seconds');
    }

    // 清除开始时间
    setOption(_keyUsageStartTime, '');
  }

  /// 获取今日使用时间（秒）
  /// 包括正在进行的会话时间
  static int _getTodayUsageSeconds() {
    final today = _getTodayString();
    final savedDate = getOption(_keyDailyUsageDate);

    int dailySeconds = 0;
    if (savedDate == today) {
      // 同一天，获取已保存的使用时间
      final dailyStr = getOption(_keyDailyUsageSeconds);
      dailySeconds = int.tryParse(dailyStr) ?? 0;
    }

    // 如果有正在进行的会话，加上会话时间
    final startTimeStr = getOption(_keyUsageStartTime);
    if (startTimeStr.isNotEmpty) {
      final startTime = int.tryParse(startTimeStr);
      if (startTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final sessionDuration = now - startTime;

        // 检查会话是否跨天
        final sessionStartDate =
            DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
        final sessionStartDateStr =
            '${sessionStartDate.year}-${sessionStartDate.month.toString().padLeft(2, '0')}-${sessionStartDate.day.toString().padLeft(2, '0')}';

        if (sessionStartDateStr == today) {
          // 同一天，加上会话时间
          dailySeconds += sessionDuration;
        }
      }
    }

    return dailySeconds;
  }

  /// 获取今天的日期字符串（格式：YYYY-MM-DD）
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 重置使用时间（用户登录后调用）
  /// 注意：登录后不需要重置，因为已登录用户不受本地时间限制
  static void reset() {
    setOption(_keyUsageStartTime, '');
    // 不需要重置每日使用时间，因为登录后不再追踪
    debugPrint('[UsageTime] Usage time tracking stopped (user logged in)');
  }

  /// 重置免费使用时长（用于测试）
  /// 清除所有使用时间记录，恢复到初始状态
  static void resetFreeUsageTime() {
    setOption(_keyUsageStartTime, '');
    setOption(_keyDailyUsageDate, '');
    setOption(_keyDailyUsageSeconds, '0');
    debugPrint('[UsageTime] Free usage time reset (for testing)');
  }

  /// 清理过期的使用时间记录（每天自动清理前一天的数据）
  static void cleanupOldData() {
    final today = _getTodayString();
    final savedDate = getOption(_keyDailyUsageDate);

    // 如果不是今天，清理旧数据
    if (savedDate.isNotEmpty && savedDate != today) {
      setOption(_keyDailyUsageDate, '');
      setOption(_keyDailyUsageSeconds, '0');
      debugPrint('[UsageTime] Cleaned up old usage data for date: $savedDate');
    }
  }

  /// 获取本地选项
  static String getOption(String key) {
    return bind.mainGetLocalOption(key: key);
  }

  /// 设置本地选项
  static Future<void> setOption(String key, String value) async {
    await bind.mainSetLocalOption(key: key, value: value);
  }

  /// 格式化时间为可读字符串
  static String formatTime(int seconds) {
    if (seconds < 0) {
      return '无限制';
    }
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}小时${minutes}分钟${secs}秒';
    } else if (minutes > 0) {
      return '${minutes}分钟${secs}秒';
    } else {
      return '${secs}秒';
    }
  }

  /// 获取使用时间限制提示信息
  static String getLimitMessage() {
    final remaining = getRemainingSeconds();
    if (remaining < 0) {
      return '您已登录，权限由服务器控制';
    }
    if (remaining == 0) {
      return '今日免费使用时间已用完，请登录后继续使用';
    }
    final used = getUsedSeconds();
    return '今日免费使用：${formatTime(used)} / ${formatTime(_maxUsageSeconds)}\n剩余时间：${formatTime(remaining)}';
  }

  /// 获取今日剩余使用时间显示文本（仅开发版显示）
  static String? getRemainingTimeDisplayText() {
    // 仅在开发模式下显示
    if (kReleaseMode) {
      return null;
    }

    if (gFFI.userModel.isLogin) {
      return null; // 已登录不显示
    }

    final remaining = getRemainingSeconds();
    if (remaining <= 0) {
      return '今日免费时长已用完';
    }
    return '今日剩余：${formatTime(remaining)}';
  }
}
