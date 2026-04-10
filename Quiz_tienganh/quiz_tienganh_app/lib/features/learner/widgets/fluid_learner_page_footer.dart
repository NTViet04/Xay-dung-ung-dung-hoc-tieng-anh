import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/app_snackbar.dart';

/// Chân trang dùng chung (Privacy / Terms / Support + bản quyền) — đồng bộ giữa các màn learner.
class FluidLearnerPageFooter extends StatelessWidget {
  const FluidLearnerPageFooter({
    super.key,
    this.onPrivacy,
    this.onTerms,
    this.onSupport,
  });

  final VoidCallback? onPrivacy;
  final VoidCallback? onTerms;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    void def(VoidCallback? c, String msg) {
      if (c != null) {
        c();
      } else {
        showAppSnackBar(context, msg, kind: AppSnackKind.info);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final row = c.maxWidth >= 560;
          final links = Wrap(
            alignment: row ? WrapAlignment.end : WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => def(
                  onPrivacy,
                  'Chính sách bảo mật sẽ được cập nhật.',
                ),
                child: Text(
                  'Quyền riêng tư',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => def(
                  onTerms,
                  'Điều khoản sẽ được cập nhật.',
                ),
                child: Text(
                  'Điều khoản',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => def(
                  onSupport,
                  'Hỗ trợ: liên hệ quản trị viên.',
                ),
                child: Text(
                  'Hỗ trợ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          );

          final brand = Column(
            crossAxisAlignment:
                row ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(
                'The Fluid Scholar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '© ${DateTime.now().year} The Fluid Scholar. Học tiếng Anh bền vững cùng đà tiến bộ.',
                textAlign: row ? TextAlign.left : TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          );

          if (row) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: brand),
                links,
              ],
            );
          }
          return Column(
            children: [
              brand,
              const SizedBox(height: 16),
              links,
            ],
          );
        },
      ),
    );
  }
}
