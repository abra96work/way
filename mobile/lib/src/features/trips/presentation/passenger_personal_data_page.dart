import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../driver/presentation/widgets/photo_source_sheet.dart';
import '../domain/passenger_api_exception.dart';
import '../domain/passenger_profile.dart';

class PassengerPersonalDataPage extends StatefulWidget {
  const PassengerPersonalDataPage({
    super.key,
    required this.loadProfile,
    required this.pickPhoto,
    required this.onSave,
    required this.onBack,
  });

  final Future<PassengerProfile> Function() loadProfile;
  final PickPhoto pickPhoto;
  final Future<void> Function(
    String firstName,
    String? lastName,
    PickedPhoto? photo,
  )
  onSave;
  final VoidCallback onBack;

  @override
  State<PassengerPersonalDataPage> createState() =>
      _PassengerPersonalDataPageState();
}

class _PassengerPersonalDataPageState extends State<PassengerPersonalDataPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _secondary = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  PassengerProfile? _profile;
  PickedPhoto? _photo;
  String _initialName = '';
  String _initialLastName = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _changed =>
      _photo != null ||
      _nameController.text.trim() != _initialName ||
      _lastNameController.text.trim() != _initialLastName;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_nameChanged);
    _lastNameController.addListener(_nameChanged);
    _load();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_nameChanged)
      ..dispose();
    _lastNameController
      ..removeListener(_nameChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      key: const ValueKey('passenger-personal-data-page'),
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: _divider),
            Expanded(child: _content()),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: FilledButton(
                key: const ValueKey('passenger-personal-save'),
                onPressed:
                    !_loading &&
                        !_saving &&
                        _changed &&
                        _nameController.text.trim().isNotEmpty
                    ? _save
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _primary,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: _secondary,
                  side: BorderSide(color: _changed ? _primary : _divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _header() => SizedBox(
    height: 62,
    child: Row(
      children: [
        const SizedBox(width: 12),
        _circleButton(Icons.chevron_left, widget.onBack),
        const Expanded(
          child: Text(
            'Личные данные',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        _circleButton(Icons.more_horiz, null),
        const SizedBox(width: 12),
      ],
    ),
  );

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null && _profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final profile = _profile!;
    final ImageProvider<Object>? avatar = _photo != null
        ? MemoryImage(_photo!.bytes)
        : profile.avatarUrl != null
        ? NetworkImage(profile.avatarUrl!)
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: _divider,
                backgroundImage: avatar,
                child: avatar == null
                    ? const Icon(Icons.person, size: 48, color: Colors.grey)
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: 0,
                child: Material(
                  color: _primary,
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    key: const ValueKey('passenger-personal-photo'),
                    onTap: _choosePhoto,
                    borderRadius: BorderRadius.circular(7),
                    child: const SizedBox.square(
                      dimension: 26,
                      child: Icon(Icons.edit, color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('Имя', style: TextStyle(color: _secondary, fontSize: 12)),
        TextField(
          key: const ValueKey('passenger-personal-name'),
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.only(top: 5, bottom: 10),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Фамилия',
          style: TextStyle(color: _secondary, fontSize: 12),
        ),
        TextField(
          key: const ValueKey('passenger-personal-last-name'),
          controller: _lastNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.only(top: 5, bottom: 10),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Номер телефона',
          style: TextStyle(color: _secondary, fontSize: 12),
        ),
        SizedBox(
          height: 42,
          child: Row(
            children: [
              Expanded(child: Text(_formatPhone(profile.phone))),
              const Icon(Icons.phone, color: Colors.grey, size: 18),
            ],
          ),
        ),
        const Divider(height: 1, color: _divider),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback? onTap) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(dimension: 40, child: Icon(icon, size: 21)),
    ),
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.loadProfile();
      if (!mounted) return;
      _initialName = profile.firstName;
      _initialLastName = profile.lastName ?? '';
      _nameController.text = profile.firstName;
      _lastNameController.text = profile.lastName ?? '';
      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PassengerApiException
            ? error.message
            : 'Не удалось загрузить профиль';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choosePhoto() async {
    final photo = await choosePhoto(context, widget.pickPhoto);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final lastName = _lastNameController.text.trim();
      await widget.onSave(
        _nameController.text.trim(),
        lastName.isEmpty ? null : lastName,
        _photo,
      );
      if (mounted) widget.onBack();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PassengerApiException
                ? error.message
                : 'Не удалось сохранить данные',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _nameChanged() {
    if (mounted) setState(() {});
  }
}

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 &&
      (digits.startsWith('7') || digits.startsWith('8'))) {
    return '+7 ${digits.substring(1, 4)} ${digits.substring(4, 7)} '
        '${digits.substring(7, 9)} ${digits.substring(9, 11)}';
  }
  return value;
}
