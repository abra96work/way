import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef RequestLoginCode = Future<void> Function(String phone);
typedef LoginCodeSent = void Function(String phone);

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.onRequestCode,
    this.onCodeSent,
    this.onTermsPressed,
    this.onPrivacyPressed,
  });

  final RequestLoginCode onRequestCode;
  final LoginCodeSent? onCodeSent;
  final VoidCallback? onTermsPressed;
  final VoidCallback? onPrivacyPressed;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  static const _designSize = Size(375, 812);
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondaryText = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isPhoneValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('7');
  }

  String get _phoneE164 =>
      '+${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _background,
        body: ColoredBox(
          color: _background,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: _designSize,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 16,
                      right: 16,
                      top: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать в «Путь»!',
                            key: ValueKey('phone-login-title'),
                            style: TextStyle(
                              color: _text,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Находите выгодные поездки и договаривайтесь\nна своих условиях',
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.33,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 195,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 52,
                            child: TextField(
                              key: const ValueKey('phone-input'),
                              controller: _phoneController,
                              autofocus: false,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              inputFormatters: const [_RussianPhoneFormatter()],
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: _text,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Номер телефона',
                                labelStyle: TextStyle(
                                  color: _secondaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: _secondaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: _divider),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: _text),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Мы отправим вам СМС с кодом для входа в приложение',
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.33,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 96,
                      child: _ConsentText(
                        onTermsPressed: widget.onTermsPressed,
                        onPrivacyPressed: widget.onPrivacyPressed,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 34,
                      height: 48,
                      child: TextButton(
                        key: const ValueKey('phone-request-code'),
                        onPressed: _isPhoneValid && !_isSubmitting
                            ? _requestCode
                            : null,
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            _isPhoneValid ? _primary : Colors.transparent,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            _isPhoneValid ? Colors.white : _secondaryText,
                          ),
                          overlayColor: const WidgetStatePropertyAll(
                            Color(0x1FFFFFFF),
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: _isPhoneValid ? _primary : _divider,
                            ),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textStyle: const WidgetStatePropertyAll(
                            TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.33,
                            ),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Получить код'),
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

  Future<void> _requestCode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      await widget.onRequestCode(_phoneE164);
      if (!mounted) return;
      if (widget.onCodeSent != null) {
        widget.onCodeSent!(_phoneE164);
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Код для входа отправлен')),
        );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Не удалось отправить код. Попробуйте ещё раз';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить код. Попробуйте ещё раз'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ConsentText extends StatelessWidget {
  const _ConsentText({this.onTermsPressed, this.onPrivacyPressed});

  final VoidCallback? onTermsPressed;
  final VoidCallback? onPrivacyPressed;

  @override
  Widget build(BuildContext context) {
    const normalStyle = TextStyle(
      color: _PhoneLoginPageState._secondaryText,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.38,
    );
    const linkStyle = TextStyle(
      color: _PhoneLoginPageState._primary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.38,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Продолжая, я соглашаюсь с ', style: normalStyle),
        GestureDetector(
          key: const ValueKey('terms-link'),
          onTap: onTermsPressed,
          child: const Text('условиями использования', style: linkStyle),
        ),
        const Text(' и ', style: normalStyle),
        GestureDetector(
          key: const ValueKey('privacy-link'),
          onTap: onPrivacyPressed,
          child: const Text('политикой конфиденциальности', style: linkStyle),
        ),
      ],
    );
  }
}

class _RussianPhoneFormatter extends TextInputFormatter {
  const _RussianPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    if (digits.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer('+7 ');
    _writeGroup(buffer, digits, 0, 3);
    _writeGroup(buffer, digits, 3, 3);
    _writeGroup(buffer, digits, 6, 2);
    _writeGroup(buffer, digits, 8, 2);
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static void _writeGroup(
    StringBuffer buffer,
    String digits,
    int start,
    int length,
  ) {
    if (digits.length <= start) return;
    if (start > 0) buffer.write(' ');
    final end = (start + length).clamp(0, digits.length);
    buffer.write(digits.substring(start, end));
  }
}
