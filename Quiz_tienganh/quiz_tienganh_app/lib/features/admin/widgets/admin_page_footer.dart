import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/app_snackbar.dart';

/// Chân trang dùng chung các màn admin.
class AdminPageFooter extends StatelessWidget {
  const AdminPageFooter({super.key});

  @override
  Widget build(BuildContext context) {
    void doc() {
      showAppSnackBar(
        context,
        'Tài liệu API: thư mục backend/README.',
        kind: AppSnackKind.info,
      );
    }

    void privacy() {
      showAppSnackBar(
        context,
        'Chính sách bảo mật — bản nội bộ.',
        kind: AppSnackKind.info,
      );
    }

    void support() {
      showAppSnackBar(
        context,
        'Liên hệ quản trị hệ thống để được hỗ trợ.',
        kind: AppSnackKind.info,
      );
    }

    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final row = c.maxWidth > 640;
            final copy = Text(
              '© ${DateTime.now().year} THE ACADEMIC ATELIER. PHIÊN BẢN HỆ THỐNG 2.4.0',
              style: GoogleFonts.robotoMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: const Color(0xFF94A3B8),
              ),
            );
            final links = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Link(label: 'Tài liệu', onTap: doc),
                const SizedBox(width: 20),
                _Link(label: 'Chính sách bảo mật', onTap: privacy),
                const SizedBox(width: 20),
                _Link(label: 'Hỗ trợ', onTap: support),
              ],
            );
            if (row) {
              return Row(
                children: [
                  Expanded(child: copy),
                  links,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Link(label: 'Tài liệu', onTap: doc),
                    _Link(label: 'Chính sách bảo mật', onTap: privacy),
                    _Link(label: 'Hỗ trợ', onTap: support),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.robotoMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
