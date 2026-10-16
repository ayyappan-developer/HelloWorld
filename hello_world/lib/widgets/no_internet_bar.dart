import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../utils/app_colors.dart';

/// Wraps the whole app (see MaterialApp.builder in main.dart).
///
/// Internet lost     -> red "No internet connection" bar at the bottom.
/// Internet is back  -> green "Back online" bar for 2 seconds.
class NoInternetBar extends StatefulWidget {
  final Widget child;
  const NoInternetBar({super.key, required this.child});

  @override
  State<NoInternetBar> createState() => _NoInternetBarState();
}

class _NoInternetBarState extends State<NoInternetBar> {
  bool _showBackOnline = false;
  bool _retrying = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.online.addListener(_onChanged);
  }

  @override
  void dispose() {
    ConnectivityService.instance.online.removeListener(_onChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    _hideTimer?.cancel();
    final bool online = ConnectivityService.instance.isOnline;
    setState(() {
      _showBackOnline = online;
      if (online) _retrying = false;
    });
    if (online) {
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await ConnectivityService.instance.check();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: ConnectivityService.instance.online,
            builder: (context, online, _) {
              final bool visible = !online || _showBackOnline;
              return AnimatedSlide(
                offset: Offset(0, visible ? 0 : 1),
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(ignoring: !visible, child: _bar(online)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bar(bool online) {
    // Stay above the keyboard and the phone's gesture bar
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: online ? AppColors.success : AppColors.error,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 8, 10 + (keyboard > 0 ? keyboard : safeBottom)),
        child: Row(
          children: [
            Icon(online ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                online ? 'Back online' : 'No internet connection',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            if (!online)
              TextButton(
                onPressed: _retry,
                child: _retrying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
