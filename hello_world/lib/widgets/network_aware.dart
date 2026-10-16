import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

/// Add to a screen's State to reload it when the internet comes back.
///
/// ```dart
/// class _AccountScreenState extends State<AccountScreen> with NetworkAware {
///   @override
///   void onNetworkRestored() => _loadProfile();
/// }
/// ```
///
/// Only the screen the user is looking at reloads.
mixin NetworkAware<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _networkSubscription;

  /// Called every time the internet comes back.
  void onNetworkRestored();

  @override
  void initState() {
    super.initState();
    _networkSubscription = ConnectivityService.instance.onRestored.listen((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return; // hidden screen
      onNetworkRestored();
    });
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }
}
