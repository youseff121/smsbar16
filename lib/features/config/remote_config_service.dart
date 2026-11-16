import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigService {
  // ذخیره در FlutterSharedPreferences با کلید flutter.remote_config (برای SmsReceiver)
  static const String _key = 'remote_config';

  // مقادیر پیش‌فرض (با پیش‌شماره ۹۸)
  static const List<String> defaultSenders = [
    '9820007777',
    '9830001923',
    '98200013333',
  ];
  static const List<String> defaultDestinations = [
    '5000200050',
  ];

  // آدرس‌های اولیه (همیشه امتحان میشن). کانفیگ می‌تونه آدرس‌های جدید به فیلد sources اضافه کنه.
  static const List<String> _fallbackSources = [
    'https://your-host.example.com/dalahoo/config.json', // TODO: آدرس واقعی هاست
    'https://raw.githubusercontent.com/OWNER/REPO/main/config.json', // TODO: آدرس واقعی گیت‌هاپ
  ];

  // خواندن فرستنده‌ها از کش (اگه نبود، مقادیر پیش‌فرض)
  static Future<List<String>> loadSenders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = _cached(prefs);
      final list = decoded?['senders'];
      if (list is List && list.isNotEmpty) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return defaultSenders;
  }

  static Map<String, dynamic>? _cached(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static const MethodChannel _native = MethodChannel('sms_forwarder');

  // بررسی نسخه با کانفیگ و دانلود/نصب در صورت تفاوت
  static Future<String> checkAndUpdate() async {
    try {
      await refresh();
      final prefs = await SharedPreferences.getInstance();
      final app = _cached(prefs)?['app'];
      if (app is! Map || app['version'] == null || app['url'] == null) {
        return 'اطلاعات آپدیت پیدا نشد';
      }
      final remoteVersion = app['version'].toString().trim();
      final url = app['url'].toString().trim();

      final currentVersion =
          (await _native.invokeMethod<String>('getAppVersion')) ?? '';
      if (remoteVersion == currentVersion) {
        return 'برنامه آخرین نسخه است';
      }
      if (!url.startsWith('https://')) {
        return 'آدرس آپدیت معتبر نیست';
      }

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 3));
      if (res.statusCode != 200) {
        return 'دانلود آپدیت انجام نشد';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      await file.writeAsBytes(res.bodyBytes, flush: true);

      await _native.invokeMethod('installApk', {'path': file.path});
      return 'فایل آپدیت آماده شد، نصب رو تایید کن';
    } catch (e) {
      debugPrint('update failed: $e');
      return 'بروزرسانی انجام نشد';
    }
  }

  static Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedSources = (_cached(prefs)?['sources'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.startsWith('https://'))
            .toList() ??
        <String>[];

    // اول آدرس‌های ذخیره‌شده از کانفیگ، بعد آدرس‌های داخل اپ
    final urls = <String>{...cachedSources, ..._fallbackSources}.toList();

    for (final url in urls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is! Map) continue;

        final senders = decoded['senders'];
        final destinations = decoded['destinations'];
        if (senders is! List ||
            destinations is! List ||
            senders.isEmpty ||
            destinations.isEmpty) {
          continue;
        }

        final newSources = (decoded['sources'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.startsWith('https://'))
                .toList() ??
            cachedSources;

        await prefs.setString(
          _key,
          jsonEncode({
            'senders': senders,
            'destinations': destinations,
            'sources': newSources,
            'app': decoded['app'] ?? _cached(prefs)?['app'],
          }),
        );
        debugPrint('remote config updated from $url');
        return;
      } catch (e) {
        debugPrint('remote config failed ($url): $e');
      }
    }
  }
}
