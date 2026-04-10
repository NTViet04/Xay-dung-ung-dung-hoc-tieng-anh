import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/auth_provider.dart';
import '../widgets/lexicon_auth_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _passwordStrong => _passCtrl.text.length >= 6;
  bool get _passwordsMatch =>
      _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmCtrl.text;

  Future<void> _submit() async {
    if (_userCtrl.text.trim().length < 3) {
      _snack('Tên đăng nhập cần ít nhất 3 ký tự.');
      return;
    }
    if (!_passwordStrong) {
      _snack('Mật khẩu cần ít nhất 6 ký tự.');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _snack('Mật khẩu xác nhận không khớp.');
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    setState(() => _loading = true);
    try {
      await auth.register(_userCtrl.text.trim(), _passCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        wide ? 40 : 28,
        wide ? 40 : 28,
        wide ? 40 : 28,
        32,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _passCtrl,
          _confirmCtrl,
        ]),
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tạo tài khoản của bạn',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: wide ? 28 : 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bắt đầu hành trình làm chủ ngôn ngữ ngay hôm nay.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              LexiconTextField(
                controller: _userCtrl,
                label: 'Tên đăng nhập',
                hint: 'nguoi_hoc_chon_loc',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autocorrect: false,
              ),
              const SizedBox(height: 18),
              LexiconTextField(
                controller: _emailCtrl,
                label: 'Địa chỉ email (tuỳ chọn)',
                hint: 'xin_chao@lexicon.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Hệ thống hiện chỉ lưu tên đăng nhập và mật khẩu trên máy chủ.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final row = c.maxWidth >= 420;
                  final passField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Mật khẩu',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure1,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          filled: true,
                          fillColor: AppColors.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.fromLTRB(44, 18, 44, 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.outlineVariant,
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure1 = !_obscure1),
                            icon: Icon(
                              _obscure1
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  final confirmField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Xác nhận',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _loading ? null : _submit(),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          filled: true,
                          fillColor: AppColors.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.fromLTRB(44, 18, 44, 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.shield_outlined,
                            color: AppColors.outlineVariant,
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  if (row) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: passField),
                        const SizedBox(width: 16),
                        Expanded(child: confirmField),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      passField,
                      const SizedBox(height: 16),
                      confirmField,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_passwordStrong && _passwordsMatch)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mật khẩu đủ mạnh và khớp xác nhận',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else if (_passCtrl.text.isNotEmpty && !_passwordStrong)
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mật khẩu cần ít nhất 6 ký tự.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              LexiconPrimaryButton(
                label: 'Đăng ký Lexicon',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'Bạn đã có tài khoản? '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.login,
                            );
                          }
                        },
                        child: Text(
                          'Đăng nhập',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.lastError == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      auth.lastError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    return LexiconAuthPage(
      branding: LexiconBrandingData.register(),
      showRegisterNav: true,
      formCard: card,
      legalLinks: LexiconLegalLinks(
        onPrivacy: () => _snack('Nội dung chính sách sẽ được cập nhật.'),
        onTerms: () => _snack('Nội dung điều khoản sẽ được cập nhật.'),
        onCookie: () => _snack('Cài đặt cookie sẽ có trong bản sau.'),
      ),
    );
  }
}
