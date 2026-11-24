import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef VerifySmsCode = Future<void> Function(String phone, String code);
typedef ResendSmsCode = Future<void> Function(String phone);

class SmsCodePage extends StatefulWidget {
  const SmsCodePage({
    super.key,
    required this.phone,
    required this.onVerify,
    required this.onResend,
    this.onBack,
    this.onVerified,
    this.initialSeconds = 59,
  });

  final String phone;
  final VerifySmsCode onVerify;
  final ResendSmsCode onResend;
  final VoidCallback? onBack;
  final VoidCallback? onVerified;
  final int initialSeconds;

  @override
  State<SmsCodePage> createState() => _SmsCodePageState();
}

class _SmsCodePageState extends State<SmsCodePage> {
  static const _designSize = Size(375, 812);
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondaryText = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);
  static const _danger = Color(0xFFFF3B3B);

  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  late int _secondsLeft;
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _hasInvalidCode = false;
  String _verificationError = 'Неверный код подтверждения';

  bool get _isComplete => _codeController.text.length == 6;
  bool get _canSubmit => _isComplete && !_isSubmitting && !_hasInvalidCode;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.initialSeconds.clamp(0, 59);
    _focusNode.addListener(_refresh);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _formatPhone(widget.phone);

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
                    _Header(onBack: widget.onBack),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 110,
                      child: Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              text:
                                  'Введите код подтверждения из SMS,\n'
                                  'отправленного на ',
                              children: [
                                TextSpan(
                                  text: formattedPhone,
                                  style: const TextStyle(color: _text),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _secondaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.33,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _CodeFields(
                            code: _codeController.text,
                            focused: _focusNode.hasFocus,
                            onTap: _focusNode.requestFocus,
                          ),
                          const SizedBox(height: 24),
                          _buildResendRow(),
                          if (_hasInvalidCode) ...[
                            const SizedBox(height: 16),
                            _InvalidCodeMessage(message: _verificationError),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 145,
                      width: 1,
                      height: 1,
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          key: const ValueKey('sms-code-input'),
                          controller: _codeController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) {
                            setState(() {
                              _hasInvalidCode = false;
                              _verificationError = 'Неверный код подтверждения';
                            });
                          },
                          onSubmitted: (_) {
                            if (_canSubmit) _verify();
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 34,
                      height: 48,
                      child: TextButton(
                        key: const ValueKey('sms-login-button'),
                        onPressed: _canSubmit ? _verify : null,
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            _canSubmit ? _primary : Colors.transparent,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            _canSubmit ? Colors.white : _secondaryText,
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(color: _canSubmit ? _primary : _divider),
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
                            : const Text('Вход'),
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

  Widget _buildResendRow() {
    if (_secondsLeft > 0) {
      final seconds = _secondsLeft.toString().padLeft(2, '0');
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Выслать код повторно через:',
              style: TextStyle(
                color: _secondaryText,
                fontSize: 13,
                height: 1.38,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              key: const ValueKey('sms-resend-timer'),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '0:$seconds',
                style: const TextStyle(
                  color: _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Не получили SMS код?',
            style: TextStyle(color: _secondaryText, fontSize: 13, height: 1.38),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 26,
            child: OutlinedButton(
              key: const ValueKey('sms-resend-button'),
              onPressed: _isResending ? null : _resend,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: _text,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _isResending
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    )
                  : const Text('Отправить'),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    if (_secondsLeft <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      await widget.onVerify(widget.phone, _codeController.text);
      if (!mounted) return;
      widget.onVerified?.call();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _hasInvalidCode = true;
        _verificationError = _apiMessage(error, 'Неверный код подтверждения');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasInvalidCode = true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await widget.onResend(widget.phone);
      if (!mounted) return;
      setState(() {
        _hasInvalidCode = false;
        _secondsLeft = 59;
      });
      _startTimer();
    } on DioException catch (error) {
      _showResendError(
        _apiMessage(error, 'Не удалось отправить код. Попробуйте ещё раз'),
      );
    } catch (_) {
      _showResendError('Не удалось отправить код. Попробуйте ещё раз');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showResendError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _apiMessage(DioException error, String fallback) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : fallback;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  static String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('7')) {
      return '+7 ${digits.substring(1, 4)} ${digits.substring(4, 7)} '
          '${digits.substring(7, 9)} ${digits.substring(9, 11)}';
    }
    if (digits.length == 12 && digits.startsWith('375')) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 5)} '
          '${digits.substring(5, 8)} ${digits.substring(8, 10)} '
          '${digits.substring(10, 12)}';
    }
    return phone;
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 44,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'СМС-код',
            key: ValueKey('sms-title'),
            style: TextStyle(
              color: _SmsCodePageState._text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.29,
            ),
          ),
          Positioned(
            left: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('sms-back'),
                customBorder: const CircleBorder(),
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: _SmsCodePageState._primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeFields extends StatelessWidget {
  const _CodeFields({
    required this.code,
    required this.focused,
    required this.onTap,
  });

  final String code;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = focused || code.isNotEmpty;
    return Semantics(
      label: 'Код из СМС',
      value: code,
      textField: true,
      child: GestureDetector(
        key: const ValueKey('sms-code-fields'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final hasDigit = index < code.length;
            final isCaret = focused && index == code.length && code.length < 6;
            return Container(
              key: ValueKey('sms-digit-$index'),
              width: 52,
              height: 52,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: highlighted
                    ? Border.all(color: _SmsCodePageState._primary)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isCaret
                  ? Container(
                      width: 1,
                      height: 20,
                      color: _SmsCodePageState._primary,
                    )
                  : Text(
                      hasDigit ? code[index] : '_',
                      style: const TextStyle(
                        color: _SmsCodePageState._text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.29,
                      ),
                    ),
            );
          }),
        ),
      ),
    );
  }
}

class _InvalidCodeMessage extends StatelessWidget {
  const _InvalidCodeMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('sms-invalid-code'),
      children: [
        Container(
          height: 34,
          decoration: BoxDecoration(
            color: _SmsCodePageState._danger,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Код не подходит. Проверьте правильность введённых\n'
          'цифр и срок действия кода. Если код устарел,\n'
          'запросите новый',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _SmsCodePageState._danger,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
