import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Dữ liệu panel trái (đăng nhập / đăng ký) — bám HTML Lexicon.
class LexiconBrandingData {
  const LexiconBrandingData({
    required this.imageUrl,
    required this.titleLead,
    required this.titleAccent,
    required this.subtitle,
    required this.chips,
    this.imageRotation = -0.035,
  });

  final String imageUrl;
  final String titleLead;
  final String titleAccent;
  final String subtitle;
  final List<LexiconChipData> chips;

  /// Góc xoay ảnh (radian ≈ rotate-2 trong HTML).
  final double imageRotation;

  static LexiconBrandingData login() {
    return const LexiconBrandingData(
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDPnKCaYFfOHbinfHJqVZ-SPTDLp96gTn-SHMQAKSaJ2KGBCIILfcA95lR7qFle1fqxfYtfYO29QIIA0xWCUNrly68uYmzd8byEFYLpdrgw2-0FMS1ehg0vnWlgpcUly4fOBQlXPg5ru6jm1mmoHPPkl1ovT_O95Xkt8CdQHgZtIHScWkFyr7h2xPqHylN3diEgD0PEz-z0w8NflinAQD0ojbuxltKKGI2XJQVQigUDbHRpsKl_uJDHSBlJS9rgpfJaEQIuD75qVso',
      titleLead: 'Phát triển ',
      titleAccent: 'vốn từ vựng',
      subtitle:
          'Tham gia hệ sinh thái người học được chọn lọc và nắm vững các sắc thái tiếng Anh qua sự phát triển tự nhiên mỗi ngày.',
      chips: [
        LexiconChipData(
          label: 'Phù du',
          bg: Color(0xFFFFDDB8),
          fg: Color(0xFF2A1700),
        ),
        LexiconChipData(
          label: 'Rực rỡ',
          bg: Color(0xFF4F46E5),
          fg: Color(0xFFDAD7FF),
        ),
        LexiconChipData(
          label: 'Hùng hồn',
          bg: Color(0xFFE4E1EE),
          fg: Color(0xFF464555),
        ),
      ],
      imageRotation: -0.035,
    );
  }

  static LexiconBrandingData register() {
    return const LexiconBrandingData(
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBL3irF0TfkTfeeJa87mQZiwmqnHj40rO7gHgCjh3RIr2aCWzF1reNPiFmmyn8DsneKrrkXbA6G5Ykaezv0T7ou2r4ieF70c-dIA8TunfCLz_tsY59gaTXY6lj8-ODz2i5VOqOdsl8eg8lyyZWOJtRS_w2wiGq_a4g2lBFrIFGqAeGJV3TFgy5Xz5-Vh2iXVzUtGIZ5CrksS0e0_AzjWpqhpq2KaCquWeSiHm37k_4tkhcUhrK1dNOHHvARrEnXZxKwULeDWzd5Zbo',
      titleLead: 'Làm chủ nghệ thuật ',
      titleAccent: 'diễn đạt',
      subtitle:
          'Tham gia cộng đồng người học được chọn lọc, xây dựng vốn từ vựng qua sự tinh tế và khám phá mỗi ngày.',
      chips: [
        LexiconChipData(
          label: 'Uyển chuyển',
          bg: Color(0xFFFFDDB8),
          fg: Color(0xFF2A1700),
        ),
        LexiconChipData(
          label: 'Phù du',
          bg: Color(0xFF4F46E5),
          fg: Color(0xFFDAD7FF),
        ),
        LexiconChipData(
          label: 'Kiên cường',
          bg: Color(0xFFE4E1EE),
          fg: Color(0xFF464555),
        ),
      ],
      imageRotation: 0.035,
    );
  }
}

class LexiconChipData {
  const LexiconChipData({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;
}

/// Khung trang đăng nhập / đăng ký: header, branding responsive, thẻ form, footer pháp lý ngoài thẻ.
class LexiconAuthPage extends StatefulWidget {
  const LexiconAuthPage({
    super.key,
    required this.branding,
    required this.formCard,
    this.showRegisterNav = false,
    this.onHelp,
    this.legalLinks,
  });

  final LexiconBrandingData branding;
  final Widget formCard;
  final bool showRegisterNav;

  /// true: Explore, Features, Help (đăng ký). false: chỉ Help (đăng nhập).
  final VoidCallback? onHelp;

  /// Liên kết chính sách / điều khoản — hiển thị ở vùng dưới, **ngoài** thẻ form.
  final Widget? legalLinks;

  @override
  State<LexiconAuthPage> createState() => _LexiconAuthPageState();
}

class _LexiconAuthPageState extends State<LexiconAuthPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Laptop / tablet ngang: hai cột. Điện thoại & tablet dọc: một cột, branding gọn phía trên.
  static const _breakSplit = 760.0;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final split = w >= _breakSplit;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFCF8FF),
              Color(0xFFF5F2FF),
            ],
          ),
        ),
        child: Column(
          children: [
            _Header(
              showRegisterNav: widget.showRegisterNav,
              onHelp: widget.onHelp,
            ),
            Expanded(
              child: split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 10,
                          child: _BrandingPanel(data: widget.branding),
                        ),
                        Expanded(
                          flex: 10,
                          child: _FormSide(
                            fade: _fade,
                            slide: _slide,
                            child: widget.formCard,
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _slide,
                                    child: _BrandingCompact(
                                      data: widget.branding,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _slide,
                                    child: widget.formCard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _GlobalFooter(legalLinks: widget.legalLinks),
          ],
        ),
      ),
    );
  }
}

/// Liên kết pháp lý — đặt trong [LexiconAuthPage.legalLinks], hiển thị ngoài ô nhập.
class LexiconLegalLinks extends StatelessWidget {
  const LexiconLegalLinks({
    super.key,
    required this.onPrivacy,
    required this.onTerms,
    required this.onCookie,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onCookie;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 11,
      color: const Color(0xFF64748B),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF94A3B8),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: onPrivacy,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Chính sách bảo mật', style: style),
        ),
        Text('·', style: TextStyle(color: style.color, fontSize: 11)),
        TextButton(
          onPressed: onTerms,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Điều khoản dịch vụ', style: style),
        ),
        Text('·', style: TextStyle(color: style.color, fontSize: 11)),
        TextButton(
          onPressed: onCookie,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Cookie', style: style),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showRegisterNav,
    this.onHelp,
  });

  final bool showRegisterNav;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Text(
              'Lexicon',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4338CA),
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            if (showRegisterNav && MediaQuery.sizeOf(context).width >= 600) ...[
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mục Khám phá sẽ được bổ sung.')),
                  );
                },
                child: Text(
                  'Khám phá',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Danh sách tính năng sẽ được bổ sung.')),
                  );
                },
                child: Text(
                  'Tính năng',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            TextButton(
              onPressed: onHelp ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Trợ giúp: liên hệ quản trị viên hệ thống.'),
                      ),
                    );
                  },
              child: Text(
                'Trợ giúp',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4338CA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Branding gọn cho điện thoại / tablet dọc — không cuộn nội bộ, nằm trong một scroll chung.
class _BrandingCompact extends StatelessWidget {
  const _BrandingCompact({required this.data});

  final LexiconBrandingData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.rotate(
                angle: data.imageRotation * 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 108,
                    height: 135,
                    child: Image.network(
                      data.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: AppColors.surfaceContainerHighest,
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 48,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lexicon',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.onSurface,
                        ),
                        children: [
                          TextSpan(text: data.titleLead),
                          TextSpan(
                            text: data.titleAccent,
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in data.chips) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel trái màn hình chia đôi — scale theo chiều cao khung, **không** dùng scroll riêng.
class _BrandingPanel extends StatelessWidget {
  const _BrandingPanel({required this.data});

  final LexiconBrandingData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLow,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final maxW = constraints.maxWidth;
              final pad = math.max(12.0, maxW * 0.05);
              var imgW = (maxW - pad * 2).clamp(200.0, 400.0);
              var imgH = imgW * 1.25;
              final textBlock = maxH * 0.38;
              if (imgH + textBlock > maxH) {
                imgH = (maxH * 0.48).clamp(140.0, 340.0);
                imgW = imgH / 1.25;
              }

              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxW - pad * 2,
                        maxHeight: maxH - 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.rotate(
                            angle: data.imageRotation,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) {
                                return Opacity(opacity: t, child: child);
                              },
                              child: Material(
                                elevation: 20,
                                shadowColor: Colors.black26,
                                borderRadius: BorderRadius.circular(24),
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox(
                                  width: imgW,
                                  height: imgH,
                                  child: Image.network(
                                    data.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            ColoredBox(
                                      color: AppColors.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        size: 64,
                                        color: AppColors.primaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: math.max(12.0, maxH * 0.02)),
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: maxW < 380 ? 22 : 28,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                color: AppColors.onSurface,
                              ),
                              children: [
                                TextSpan(text: data.titleLead),
                                TextSpan(
                                  text: data.titleAccent,
                                  style: const TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: maxW < 380 ? 13 : 14.5,
                              height: 1.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: math.max(10.0, maxH * 0.018)),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: data.chips
                                .map(
                                  (c) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.bg,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      c.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: c.fg,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalFooter extends StatelessWidget {
  const _GlobalFooter({this.legalLinks});

  final Widget? legalLinks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        color: const Color(0xFFF8FAFC),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (legalLinks != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: legalLinks!,
              ),
            ],
            Text(
              '© ${DateTime.now().year} Lexicon Learning · Tinh tế hữu cơ.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô nhập có icon trái — bám input HTML.
class LexiconTextField extends StatelessWidget {
  const LexiconTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.autocorrect = true,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final bool autocorrect;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: autocorrect,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.outlineVariant),
            filled: true,
            fillColor: AppColors.surfaceContainerHighest,
            contentPadding: EdgeInsets.fromLTRB(
              prefixIcon != null ? 48 : 18,
              18,
              18,
              18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            suffixIcon: suffix,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.outlineVariant, size: 22)
                : null,
          ),
        ),
      ],
    );
  }
}

/// Nút gradient giống HTML (submit).
class LexiconPrimaryButton extends StatelessWidget {
  const LexiconPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: onPressed == null && !loading ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        borderRadius: BorderRadius.circular(999),
        elevation: 0,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

