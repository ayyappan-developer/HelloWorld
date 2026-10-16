import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Network listener for the whole app.
///
/// connectivity_plus only tells us "wifi / mobile / none". Being on wifi does
/// not mean the internet works, so we also send a tiny request to Supabase.
///
/// Three ways to use it:
///   ConnectivityService.instance.online      -> ValueNotifier, for widgets
///   ConnectivityService.instance.onRestored  -> fires when the internet comes back
///   ConnectivityService.instance.isOnline    -> a quick true / false
class ConnectivityService {
  // One shared object for the whole app
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  AppLifecycleListener? _lifecycle;
  Timer? _retryTimer;
  bool _checking = false;
  bool _started = false;

  /// true = online. Starts as true so the red bar does not flash on launch.
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  final StreamController<void> _restored = StreamController<void>.broadcast();

  /// Fires every time the internet comes back after being lost.
  Stream<void> get onRestored => _restored.stream;

  bool get isOnline => online.value;

  /// Call once in main(). Safe to call again.
  Future<void> init() async {
    if (_started) return;
    _started = true;

    // Wifi / mobile changed: check again
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluate(interfaceUp: !_isNone(results));
    });

    // The app came back from the background: check again
    _lifecycle = AppLifecycleListener(onResume: check);

    await check();
  }

  /// Checks the connection now. Returns true when online.
  Future<bool> check() async {
    final results = await _connectivity.checkConnectivity();
    return _evaluate(interfaceUp: !_isNone(results));
  }

  Future<bool> _evaluate({required bool interfaceUp}) async {
    if (_checking) return isOnline;
    _checking = true;
    final bool result = interfaceUp && await _reachable();
    _checking = false;
    _publish(result);
    return result;
  }

  void _publish(bool value) {
    final bool wasOnline = online.value;
    online.value = value;

    if (value) {
      _retryTimer?.cancel();
      _retryTimer = null;
      if (!wasOnline) {
        debugPrint('Connectivity: back online');
        _restored.add(null);
      }
    } else {
      if (wasOnline) debugPrint('Connectivity: connection lost');
      // A router coming back often sends no event, so keep checking every 5s
      _retryTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => check());
    }
  }

  bool _isNone(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  /// true when a real request reaches the internet.
  Future<bool> _reachable() async {
    // On the web the browser already knows, and a request would hit CORS
    if (kIsWeb) return true;

    final String url = dotenv.env['SUPABASE_URL'] ?? '';
    try {
      final response = await http
          .head(Uri.parse(url.startsWith('http') ? url : 'https://www.google.com'))
          .timeout(const Duration(seconds: 6));
      return response.statusCode > 0; // any answer means the internet works
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _lifecycle?.dispose();
    _retryTimer?.cancel();
    _started = false;
  }
}
