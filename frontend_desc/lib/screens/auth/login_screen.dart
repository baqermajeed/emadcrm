import 'dart:io' show Platform, Process;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bg =
      'asset/Luxury Tropical Villa Resort by the Pool.png';
  static const _logo = 'asset/amad.png';
  static const _devLogo = 'asset/bosala.png';

  static const _blue = Color(0xFF2575FC);
  static const _blueDark = Color(0xFF1A5EDD);
  static const _navy = Color(0xFF0D2141);
  static const _muted = Color(0xFF8E9AAF);
  static const _fieldBg = Color(0xFFF8FAFD);
  static const _border = Color(0xFFE0E5EE);

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthController>().login(
          _username.text,
          _password.text,
        );
    if (!ok && mounted) {
      final error = context.read<AuthController>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'فشل تسجيل الدخول')),
      );
    }
  }

  Future<void> _openForgotPasswordWhatsApp() async {
    const phone = '07746818591';
    var normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalized.startsWith('0')) {
      normalized = '964${normalized.substring(1)}';
    }
    final url = 'https://wa.me/$normalized';
    final uri = Uri.parse(url);

    var opened = false;
    try {
      if (await canLaunchUrl(uri)) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on PlatformException {
      opened = false;
    } catch (_) {
      opened = false;
    }

    if (!opened && !kIsWeb && Platform.isWindows) {
      try {
        await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
        opened = true;
      } catch (_) {
        opened = false;
      }
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final size = MediaQuery.sizeOf(context);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _bg,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              filterQuality: FilterQuality.high,
            ),
            Container(color: Colors.black.withValues(alpha: 0.20)),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _LoginCard(
                            formKey: _formKey,
                            username: _username,
                            password: _password,
                            obscure: _obscure,
                            remember: _remember,
                            loading: auth.loading,
                            logo: _logo,
                            blue: _blue,
                            blueDark: _blueDark,
                            navy: _navy,
                            muted: _muted,
                            fieldBg: _fieldBg,
                            border: _border,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onRemember: (v) =>
                                setState(() => _remember = v ?? false),
                            onForgotPassword: _openForgotPasswordWhatsApp,
                            onSubmit: auth.loading ? null : _submit,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: _DeveloperSignature(logo: _devLogo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperSignature extends StatelessWidget {
  const _DeveloperSignature({required this.logo});

  final String logo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              child: Divider(
                color: Colors.white.withValues(alpha: 0.45),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'من تطوير',
                style: AppFonts.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Divider(
                color: Colors.white.withValues(alpha: 0.45),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'شركة دقة البوصلة',
                  textAlign: TextAlign.right,
                  style: AppFonts.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    shadows: const [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                Text(
                  'للتسويق العقاري',
                  textAlign: TextAlign.right,
                  style: AppFonts.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.3,
                    shadows: const [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Image.asset(
              logo,
              height: 44,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.username,
    required this.password,
    required this.obscure,
    required this.remember,
    required this.loading,
    required this.logo,
    required this.blue,
    required this.blueDark,
    required this.navy,
    required this.muted,
    required this.fieldBg,
    required this.border,
    required this.onToggleObscure,
    required this.onRemember,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final bool remember;
  final bool loading;
  final String logo;
  final Color blue;
  final Color blueDark;
  final Color navy;
  final Color muted;
  final Color fieldBg;
  final Color border;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onRemember;
  final VoidCallback onForgotPassword;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              logo,
              height: 110,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 4),
            Text(
              'شركة عماد سكر',
              style: AppFonts.style(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: navy,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'نظام ادارة مبيعات المجمعات السكنية',
              textAlign: TextAlign.center,
              style: AppFonts.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 28),
            _field(
              controller: username,
              hint: 'اسم المستخدم',
              // RTL: suffix = visual left (icon), text on the right
              leadingIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'أدخل اسم المستخدم' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: password,
              hint: 'كلمة المرور',
              leadingIcon: Icons.lock_outline_rounded,
              obscure: obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit?.call(),
              // RTL: prefix = visual right (eye)
              trailing: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: muted,
                  size: 22,
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 4) ? 'أدخل كلمة المرور' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InkWell(
                  onTap: onForgotPassword,
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: AppFonts.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: blue,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تذكرني في هذا الجهاز',
                      style: AppFonts.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: remember,
                        onChanged: onRemember,
                        activeColor: blue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [blue, blueDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: blue.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSubmit,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'دخول',
                                  style: AppFonts.style(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData leadingIcon,
    required String? Function(String?) validator,
    bool obscure = false,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    Widget? trailing,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      textAlign: TextAlign.right,
      style: AppFonts.style(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: navy,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.style(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: muted,
        ),
        filled: true,
        fillColor: fieldBg,
        // In RTL: suffix = left edge, prefix = right edge
        suffixIcon: Icon(leadingIcon, color: blue, size: 22),
        prefixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
