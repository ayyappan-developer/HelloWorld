import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App settings that live in the cloud (Supabase table "app_setting", one row).
/// Change them in Supabase -> Table Editor; no new app build needed.
///
///   maintenance_mode     true  -> everyone sees the Maintenance screen
///   maintenance_message  text shown on that screen
///   app_version          latest build number in the store (the "+N" in pubspec version)
///   force_update         true  -> the Update screen has no "Later" button
///   android_url, ios_url store links for the "Update Now" button
///   splash_image         full image URL, or a file name in the "app-assets" bucket
///   splash_time          seconds the splash stays on screen
class AppSettingsService {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();

  // Keys for the splash image saved on the phone (shown on the next launch)
  static const _splashImageKey = 'splash_image';
  static const _splashTimeKey = 'splash_time';

  bool maintenanceMode = false;
  String maintenanceMessage = '';
  int latestVersion = 0;
  bool forceUpdate = false;
  String androidUrl = '';
  String iosUrl = '';
  String splashImage = '';
  int splashTime = 2;

  /// This app's own build number, e.g. 3 for "version: 1.0.2+3".
  int currentVersion = 0;
  String currentVersionName = '';

  /// Set when the user taps "Later" on an optional update (only for this launch).
  bool updateSkipped = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// A newer build is in the store (phones only; the web is always up to date).
  bool get hasUpdate {
    final bool phone = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    return phone && latestVersion > currentVersion;
  }

  String get storeUrl => defaultTargetPlatform == TargetPlatform.iOS ? iosUrl : androidUrl;

  /// The splash image saved last time. Fast, no internet needed.
  Future<void> loadCachedSplash() async {
    final prefs = await SharedPreferences.getInstance();
    splashImage = prefs.getString(_splashImageKey) ?? '';
    splashTime = prefs.getInt(_splashTimeKey) ?? 2;
  }

  /// Downloads the settings. Returns false when there is no internet.
  Future<bool> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = int.tryParse(info.buildNumber) ?? 0;
      currentVersionName = info.version;

      final Map<String, dynamic>? row = await _supabase
          .from('app_setting')
          .select()
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      // No row yet (setup.sql not run): keep the defaults so the app still works
      if (row == null) return true;

      maintenanceMode = row['maintenance_mode'] == true;
      maintenanceMessage = (row['maintenance_message'] ?? '').toString();
      latestVersion = int.tryParse('${row['app_version'] ?? 0}') ?? 0;
      forceUpdate = row['force_update'] == true;
      androidUrl = (row['android_url'] ?? '').toString();
      iosUrl = (row['ios_url'] ?? '').toString();

      // Save the splash for the next launch (the splash is shown before this loads)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_splashImageKey, _imageUrl((row['splash_image'] ?? '').toString()));
      await prefs.setInt(_splashTimeKey, int.tryParse('${row['splash_time'] ?? 2}') ?? 2);
      return true;
    } on PostgrestException catch (e) {
      // The table does not exist yet: run supabase/setup.sql. Do not block the app.
      debugPrint('app_setting error: ${e.message}');
      return e.code == 'PGRST205' || e.code == '42P01';
    } catch (e) {
      debugPrint('app_setting load failed: $e');
      return false;
    }
  }

  /// "splash.jpg" -> public URL in the "app-assets" bucket. Full URLs stay as they are.
  String _imageUrl(String name) {
    if (name.isEmpty || name.startsWith('http')) return name;
    return _supabase.storage.from('app-assets').getPublicUrl(name);
  }
}
