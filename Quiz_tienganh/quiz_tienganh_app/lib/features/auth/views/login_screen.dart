import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../controllers/auth_provider.dart';
import '../widgets/lexicon_auth_page.dart';
import 'register_screen.dart';

/// Đăng nhập — giao diện Lexicon + API `/auth/login`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;

  static const _kRemember = 'lexicon_remember_device';
  static const _kUsername = 'lexicon_saved_username';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final remember = p.getBool(_kRemember) ?? false;
    final saved = p.getString(_kUsername);
    if (!mounted) return;
    setState(() {
      _remember = remember;
      if (saved != null && saved.isNotEmpty) {
        _userCtrl.text = saved;
      }
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistRemember() async {
    final p = await SharedPreferences.getInstance();
    if (_remember) {
      await p.setBool(_kRemember, true);
      await p.setString(_kUsername, _userCtrl.text.trim());
    } else {
      await p.setBool(_kRemember, false);
      await p.remove(_kUsername);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    setState(() => _loading = true);
    try {
      await auth.login(_userCtrl.text.trim(), _passCtrl.text);
      await _persistRemember();
      if (mounted) {
        showAppSnackBar(
          context,
          'Đăng nhập thành công.',
          kind: AppSnackKind.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.message,
          kind: AppSnackKind.warning,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openRegister() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _snack(String msg) {
    showAppSnackBar(context, msg, kind: AppSnackKind.info);
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
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chào mừng quay trở lại',
            style: GoogleFonts.plusJakartaSans(
              fontSize: wide ? 28 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiếp tục hành trình ngôn ngữ của bạn.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          LexiconTextField(
            controller: _userCtrl,
            label: 'Email hoặc tên đăng nhập',
            hint: 'Nhập thông tin của bạn',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Padding(
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
              ),
              TextButton(
                onPressed: () => _snack(
                  'Quên mật khẩu: vui lòng liên hệ quản trị viên để được hỗ trợ.',
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Quên mật khẩu?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loading ? null : _submit(),
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.inter(color: AppColors.outlineVariant),
              filled: true,
              fillColor: AppColors.surfaceContainerHighest,
              contentPadding: const EdgeInsets.fromLTRB(48, 18, 48, 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.outlineVariant,
                size: 22,
              ),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _remember = !_remember),
                  child: Text(
                    'Ghi nhớ thiết bị này',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LexiconPrimaryButton(
            label: 'Đăng nhập Lexicon',
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
                const TextSpan(text: 'Bạn chưa có tài khoản? '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: _openRegister,
                    child: Text(
                      'Tạo tài khoản',
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
      ),
    );

    return LexiconAuthPage(
      branding: LexiconBrandingData.login(),
      showRegisterNav: false,
      formCard: card,
      legalLinks: LexiconLegalLinks(
        onPrivacy: () => _snack('Nội dung chính sách sẽ được cập nhật.'),
        onTerms: () => _snack('Nội dung điều khoản sẽ được cập nhật.'),
        onCookie: () => _snack('Cài đặt cookie sẽ có trong bản sau.'),
      ),
    );
  }
}
