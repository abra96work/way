import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage.terms({super.key}) : document = LegalDocument.terms;

  const LegalDocumentPage.privacy({super.key})
    : document = LegalDocument.privacy;

  static const _text = Color(0xFF0C0C0C);
  static const _divider = Color(0xFFE4E5E6);
  static const _primary = Color(0xFF1EB74D);

  final LegalDocument document;

  String get _title => switch (document) {
    LegalDocument.terms => 'Условия использования',
    LegalDocument.privacy => 'Политика конфиденциальности',
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 48,
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: const Border(bottom: BorderSide(color: _divider)),
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: IconButton(
              key: const ValueKey('legal-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Color(0xFFF7F7F8)),
                foregroundColor: WidgetStatePropertyAll(_primary),
              ),
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
            ),
          ),
          title: Text(
            _title,
            key: const ValueKey('legal-title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        body: SingleChildScrollView(
          key: const ValueKey('legal-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: SelectionArea(
            child: Text.rich(
              document == LegalDocument.terms ? _termsText : _privacyText,
              style: const TextStyle(
                color: _text,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.33,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _heading = TextStyle(fontWeight: FontWeight.w700);

  static const _termsText = TextSpan(
    children: [
      TextSpan(text: 'Условия использования приложения '),
      TextSpan(text: '«Путь»\n', style: _heading),
      TextSpan(text: 'Дата последнего обновления: 26.02.2026\n\n'),
      TextSpan(text: '1. Введение\n\n', style: _heading),
      TextSpan(
        text:
            '1.1. Настоящие условия регулируют отношения между администрацией приложения «Путь» и пользователем.\n\n'
            '1.2. Используя приложение, пользователь соглашается с настоящими условиями.\n\n',
      ),
      TextSpan(text: '2. Предмет условий\n\n', style: _heading),
      TextSpan(
        text: '2.1. Приложение помогает находить и создавать поездки, бронировать места и взаимодействовать с другими участниками.\n\n',
      ),
      TextSpan(text: '3. Регистрация и доступ\n\n', style: _heading),
      TextSpan(
        text:
            '3.1. Для использования отдельных функций может потребоваться регистрация.\n\n'
            '3.2. Пользователь отвечает за конфиденциальность своих учётных данных.\n\n',
      ),
      TextSpan(text: '4. Права и обязанности\n\n', style: _heading),
      TextSpan(
        text:
            '4.1. Пользователь обязуется не нарушать закон и права других лиц.\n\n'
            '4.2. Администрация может изменять функционал и обновлять условия с публикацией новой версии в приложении.\n\n',
      ),
      TextSpan(text: '5. Ответственность\n\n', style: _heading),
      TextSpan(
        text: '5.1. Участники самостоятельно договариваются о деталях поездки и несут ответственность за свои действия.\n\n',
      ),
      TextSpan(text: '6. Интеллектуальная собственность\n\n', style: _heading),
      TextSpan(
        text: '6.1. Исключительные права на приложение и его материалы принадлежат их правообладателям.',
      ),
    ],
  );

  static const _privacyText = TextSpan(
    children: [
      TextSpan(text: 'Политика конфиденциальности «Путь»\n', style: _heading),
      TextSpan(text: 'Дата последнего обновления: 26.02.2026\n\n'),
      TextSpan(text: '1. Какие данные мы обрабатываем\n\n', style: _heading),
      TextSpan(
        text: 'Для работы приложения могут обрабатываться номер телефона, данные профиля, информация о поездках и технические данные.\n\n',
      ),
      TextSpan(text: '2. Цели обработки\n\n', style: _heading),
      TextSpan(
        text: 'Данные используются для авторизации, оказания услуг, безопасности, связи с пользователем и улучшения работы приложения.\n\n',
      ),
      TextSpan(text: '3. Хранение и защита\n\n', style: _heading),
      TextSpan(
        text: 'Мы применяем организационные и технические меры для защиты данных от несанкционированного доступа.\n\n',
      ),
      TextSpan(text: '4. Права пользователя\n\n', style: _heading),
      TextSpan(
        text: 'Пользователь может запросить уточнение, изменение или удаление своих данных в пределах, установленных законом.',
      ),
    ],
  );
}
