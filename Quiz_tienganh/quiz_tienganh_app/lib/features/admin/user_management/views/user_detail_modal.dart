import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../widgets/admin_delete_dialog.dart';

/// Modal chi tiết người dùng — theo `user_management/code.html`.
class UserDetailModal extends StatelessWidget {
  const UserDetailModal({
    required this.userId,
    required this.onChanged,
    super.key,
  });

  final int userId;
  final VoidCallback onChanged;

  static String _fmtInt(num n) {
    final s = n.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _relativeVi(dynamic raw) {
    if (raw == null) {
      return 'Chưa có hoạt động';
    }
    final t = DateTime.tryParse(raw.toString());
    if (t == null) {
      return '$raw';
    }
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes} phút trước';
    }
    if (d.inHours < 24) {
      return '${d.inHours} giờ trước';
    }
    if (d.inDays < 14) {
      return '${d.inDays} ngày trước';
    }
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.user?.id;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FutureBuilder<Map<String, dynamic>>(
          future: context.read<AdminRepository>().fetchUserAdminProfile(userId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              final msg = snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : '$snap.error';
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              );
            }
            final p = snap.data!;
            final username = '${p['username'] ?? ''}';
            final level = (p['level'] as num?)?.toInt() ?? 1;
            final role = '${p['role'] ?? 'learner'}';
            final rank = '${p['rank_title'] ?? ''}';
            final vocab = (p['vocab_count'] as num?)?.toInt() ?? 0;
            final avg = (p['quiz_avg'] as num?)?.toDouble() ?? 0.0;
            final prog = (p['level_progress'] as num?)?.toDouble() ?? 0.0;
            final xpLeft = (p['xp_until_next'] as num?)?.toInt() ?? 0;
            final email = '${p['email'] ?? ''}';
            final sid = '${p['student_id'] ?? ''}';
            final handle = '${p['display_handle'] ?? ''}';
            final lang = '${p['preferred_language'] ?? ''}';
            final last = _relativeVi(p['last_activity']);
            final isSelf = myId == userId;

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurface.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4F46E5),
                                  Color(0xFF3525CD),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DotsPatternPainter(),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -48),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.onSurface
                                              .withValues(alpha: 0.12),
                                          blurRadius: 16,
                                        ),
                                      ],
                                      color: const Color(0xFFEEF2FF),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          handle,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color:
                                                AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: role == 'admin'
                                          ? AppColors.tertiaryFixed
                                              .withValues(alpha: 0.35)
                                          : AppColors.secondaryFixed
                                              .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      role == 'admin'
                                          ? 'QUẢN TRỊ'
                                          : 'THÀNH VIÊN TÍCH CỰC',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: role == 'admin'
                                            ? const Color(0xFF653E00)
                                            : const Color(0xFF007432),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -36),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'HẠNG',
                                          value: rank,
                                          valueColor:
                                              AppColors.primaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'TỪ VỰNG',
                                          value:
                                              '${_fmtInt(vocab)} từ',
                                          valueColor: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'ĐỘ CHÍNH XÁC',
                                          value:
                                              '${avg.toStringAsFixed(1)}%',
                                          valueColor: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'TIẾN ĐỘ CẤP ĐỘ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const SizedBox.shrink(),
                                      Text(
                                        'Cấp $level → ${level + 1}',
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: prog.clamp(0.0, 1.0),
                                      minHeight: 10,
                                      backgroundColor:
                                          AppColors.surfaceContainerHighest,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Còn ${_fmtInt(xpLeft)} XP để lên cấp',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'THÔNG TIN TÀI KHOẢN',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _InfoGrid(
                                    email: email,
                                    studentId: sid,
                                    language: lang,
                                    lastSession: last,
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Nhắn tin trực tiếp sẽ bổ sung trong bản sau.',
                                                ),
                                              ),
                                            );
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Gửi tin nhắn trực tiếp',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton(
                                          onPressed: isSelf
                                              ? null
                                              : () async {
                                                  final pw =
                                                      await _promptPassword(
                                                    context,
                                                  );
                                                  if (pw == null ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  try {
                                                    await context
                                                        .read<
                                                            AdminRepository>()
                                                        .resetUserPassword(
                                                          userId,
                                                          pw,
                                                        );
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Đã đặt lại mật khẩu.',
                                                          ),
                                                        ),
                                                      );
                                                      onChanged();
                                                    }
                                                  } on ApiException catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            e.message,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Đặt lại mật khẩu',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: isSelf
                                            ? null
                                            : () async {
                                                Navigator.pop(context);
                                                final ok =
                                                    await showAdminDeleteDialog(
                                                  context: context,
                                                  title: 'Xóa người dùng?',
                                                  message:
                                                      'Tài khoản và dữ liệu liên quan sẽ bị xóa vĩnh viễn.',
                                                  highlight: username,
                                                  confirmLabel: 'Xóa vĩnh viễn',
                                                );
                                                if (!ok || !context.mounted) {
                                                  return;
                                                }
                                                try {
                                                  await context
                                                      .read<
                                                          AdminRepository>()
                                                      .deleteUser(userId);
                                                  onChanged();
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Đã xóa người dùng.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } on ApiException catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          e.message,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: BorderSide(
                                            color: AppColors.error
                                                .withValues(alpha: 0.35),
                                          ),
                                          padding: const EdgeInsets.all(14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.block_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            );
          },
        ),
      ),
    );
  }

  static Future<String?> _promptPassword(BuildContext context) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Đặt lại mật khẩu',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu mới (≥ 6 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    c.dispose();
    if (r == null || r.length < 6) {
      return null;
    }
    return r;
  }
}

class _DotsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    const step = 18.0;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({
    required this.email,
    required this.studentId,
    required this.language,
    required this.lastSession,
  });

  final String email;
  final String studentId;
  final String language;
  final String lastSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InfoItem(
                label: 'Email',
                value: email,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoItem(
                label: 'Mã học viên',
                value: studentId,
                mono: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InfoItem(
                label: 'Ngôn ngữ ưu tiên',
                value: language,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoItem(
                label: 'Phiên hoạt động cuối',
                value: lastSession,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.robotoMono(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: mono
              ? GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )
              : GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}
