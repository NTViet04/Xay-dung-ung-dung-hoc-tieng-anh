import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Snackbar nổi, bo góc — thay cho SnackBar mặc định (đặc biệt trên web).
enum AppSnackKind {
  info,
  success,
  warning,
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackKind kind = AppSnackKind.info,
}) {
  final messenger = ScaffoldMessenger.of(context);

  late final Color bg;
  late final Color border;
  late final Color fg;
  late final IconData icon;

  switch (kind) {
    case AppSnackKind.success:
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFF6EE7B7).withValues(alpha: 0.55);
      fg = const Color(0xFF047857);
      icon = Icons.check_circle_outline_rounded;
      break;
    case AppSnackKind.warning:
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFBBF24).withValues(alpha: 0.5);
      fg = const Color(0xFFB45309);
      icon = Icons.info_outline_rounded;
      break;
    case AppSnackKind.info:
      bg = const Color(0xFFEEF2FF);
      border = const Color(0xFF818CF8).withValues(alpha: 0.45);
      fg = const Color(0xFF3730A3);
      icon = Icons.notifications_active_outlined;
      break;
  }

  // Tránh trùng Hero giữa hai SnackBar (IndexedStack / web) khi hiện liên tiếp.
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      content: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: fg.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
