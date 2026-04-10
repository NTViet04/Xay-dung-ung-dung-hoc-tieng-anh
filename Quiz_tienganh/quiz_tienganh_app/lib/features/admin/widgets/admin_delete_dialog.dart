import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Hộp thoại xác nhận xóa — thống nhất toàn admin (không dùng AlertDialog mặc định).
Future<bool> showAdminDeleteDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? highlight,
  String cancelLabel = 'Hủy bỏ',
  String confirmLabel = 'Xóa',
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
    builder: (ctx) => _AdminDeleteDialogBody(
      title: title,
      message: message,
      highlight: highlight,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
  return r ?? false;
}

class _AdminDeleteDialogBody extends StatelessWidget {
  const _AdminDeleteDialogBody({
    required this.title,
    required this.message,
    this.highlight,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String? highlight;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.error.withValues(alpha: 0.12),
                        AppColors.error.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.error,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (highlight != null && highlight!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        highlight!,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          cancelLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          confirmLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
