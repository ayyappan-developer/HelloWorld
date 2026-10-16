import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Small pop-up messages that slide in from the top of the screen.
///
/// Usage:
///   Pop.success(context, 'Profile saved');
///   Pop.error(context, 'Something went wrong');
///   Pop.info(context, 'Sign-in cancelled');
///   Pop.toast(context, 'Copied');   // bottom snackbar
class Pop {
  static void success(BuildContext context, String message) {
    _show(context, message, AppColors.success, Icons.check_circle);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppColors.error, Icons.error_outline);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppColors.primary, Icons.info_outline);
  }

  /// A simple message at the bottom of the screen.
  static void toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: Colors.black87,
      ),
    );
  }

  /// Puts a banner on top of every screen (the Overlay), then removes it.
  static void _show(BuildContext context, String message, Color color, IconData icon) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PopBanner(
        message: message,
        color: color,
        icon: icon,
        onClosed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

/// The banner itself: slides down, waits 3 seconds, slides back up.
class _PopBanner extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onClosed;

  const _PopBanner({
    required this.message,
    required this.color,
    required this.icon,
    required this.onClosed,
  });

  @override
  State<_PopBanner> createState() => _PopBannerState();
}

class _PopBannerState extends State<_PopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.5), end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _close, // tap to hide early
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
