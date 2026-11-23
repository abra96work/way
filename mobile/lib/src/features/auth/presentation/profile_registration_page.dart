import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

enum ProfilePhotoSource { camera, gallery }

class SelectedProfilePhoto {
  const SelectedProfilePhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

typedef PickProfilePhoto = Future<SelectedProfilePhoto?> Function(
  ProfilePhotoSource source,
);
typedef SaveProfile = Future<void> Function(
  String name,
  SelectedProfilePhoto photo,
);

class ProfileRegistrationPage extends StatefulWidget {
  const ProfileRegistrationPage({
    super.key,
    required this.onSave,
    this.onCompleted,
    this.pickPhoto,
  });

  final SaveProfile onSave;
  final VoidCallback? onCompleted;
  final PickProfilePhoto? pickPhoto;

  @override
  State<ProfileRegistrationPage> createState() =>
      _ProfileRegistrationPageState();
}

class _ProfileRegistrationPageState extends State<ProfileRegistrationPage> {
  static const _designSize = Size(375, 812);
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondaryText = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);
  static const _surface = Color(0xFFF3F3F3);

  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  SelectedProfilePhoto? _photo;
  bool _isSubmitting = false;

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _photo != null &&
      !_isSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
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
        body: _isSubmitting
            ? const _ProfileLoadingView()
            : ColoredBox(
                color: _background,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox.fromSize(
                      size: _designSize,
                      child: Stack(
                        children: [
                          const _ProfileHeader(),
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 124,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Создайте профиль и найдите подходящую\nпоездку',
                                  key: ValueKey('profile-registration-hint'),
                                  style: TextStyle(
                                    color: _secondaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.33,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: _ProfilePhoto(
                                    photo: _photo,
                                    onTap: _showPhotoSourceSheet,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 52,
                                  child: TextField(
                                    key: const ValueKey('profile-name-input'),
                                    controller: _nameController,
                                    maxLength: 60,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) {
                                      if (_canContinue) _save();
                                    },
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      height: 1.33,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Имя',
                                      counterText: '',
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
                              ],
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 34,
                            height: 48,
                            child: TextButton(
                              key: const ValueKey('profile-continue'),
                              onPressed: _canContinue ? _save : null,
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  _canContinue ? _primary : Colors.transparent,
                                ),
                                foregroundColor: WidgetStatePropertyAll(
                                  _canContinue ? Colors.white : _secondaryText,
                                ),
                                side: WidgetStatePropertyAll(
                                  BorderSide(
                                    color: _canContinue ? _primary : _divider,
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
                              child: const Text('Далее'),
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

  Future<void> _showPhotoSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final source = await showModalBottomSheet<ProfilePhotoSource>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x590C0C0C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return;
    await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ProfilePhotoSource source) async {
    try {
      final photo = widget.pickPhoto != null
          ? await widget.pickPhoto!(source)
          : await _pickPhotoFromDevice(source);
      if (!mounted || photo == null) return;
      if (photo.bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showError('Фотография должна быть не больше 5 МБ');
        return;
      }
      setState(() => _photo = photo);
    } catch (_) {
      if (mounted) _showError('Не удалось загрузить фотографию');
    }
  }

  Future<SelectedProfilePhoto?> _pickPhotoFromDevice(
    ProfilePhotoSource source,
  ) async {
    final file = await _imagePicker.pickImage(
      source: source == ProfilePhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return SelectedProfilePhoto(
      bytes: await file.readAsBytes(),
      fileName: file.name,
    );
  }

  Future<void> _save() async {
    final photo = _photo;
    if (!_canContinue || photo == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      await widget.onSave(_nameController.text.trim(), photo);
      if (!mounted) return;
      widget.onCompleted?.call();
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Не удалось сохранить профиль';
      setState(() => _isSubmitting = false);
      _showError(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Не удалось сохранить профиль');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 54,
      height: 60,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _ProfileRegistrationPageState._divider),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F7F8),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/profile/user_id.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Создайте свой профиль',
                  key: ValueKey('profile-registration-title'),
                  style: TextStyle(
                    color: _ProfileRegistrationPageState._text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.photo, required this.onTap});

  final SelectedProfilePhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: photo == null
          ? 'Добавить фотографию профиля'
          : 'Изменить фотографию профиля',
      child: GestureDetector(
        key: const ValueKey('profile-photo'),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 96,
          child: Stack(
            children: [
              ClipOval(
                child: ColoredBox(
                  color: _ProfileRegistrationPageState._surface,
                  child: SizedBox.expand(
                    child: photo == null
                        ? Center(
                            child: SvgPicture.asset(
                              'assets/icons/profile/user_rounded.svg',
                              width: 48,
                              height: 48,
                            ),
                          )
                        : Image.memory(
                            photo!.bytes,
                            key: const ValueKey('profile-photo-preview'),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _ProfileRegistrationPageState._primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/profile/pen.svg',
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 192,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 43,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Загрузка фотографии',
                style: TextStyle(
                  color: _ProfileRegistrationPageState._text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.29,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _PhotoSourceAction(
                    key: const ValueKey('profile-photo-camera'),
                    label: 'Камера',
                    icon: 'assets/icons/profile/camera.svg',
                    onTap: () =>
                        Navigator.pop(context, ProfilePhotoSource.camera),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _PhotoSourceAction(
                    key: const ValueKey('profile-photo-gallery'),
                    label: 'Галерея',
                    icon: 'assets/icons/profile/gallery.svg',
                    onTap: () =>
                        Navigator.pop(context, ProfilePhotoSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSourceAction extends StatelessWidget {
  const _PhotoSourceAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileRegistrationPageState._background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _ProfileRegistrationPageState._primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(icon, width: 24, height: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: _ProfileRegistrationPageState._text,
                  fontSize: 15,
                  height: 1.33,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('profile-loading'),
      color: _ProfileRegistrationPageState._background,
      child: Center(
        child: SizedBox.square(
          dimension: 48,
          child: CircularProgressIndicator(
            color: _ProfileRegistrationPageState._primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
