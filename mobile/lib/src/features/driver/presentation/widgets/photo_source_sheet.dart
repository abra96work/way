import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'driver_style.dart';

/// Where a photo comes from: the camera or the phone's files/gallery.
enum PhotoSource { camera, files }

/// A picked image, ready to upload as multipart.
@immutable
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Picks a photo from [PhotoSource]; `null` when the driver cancels.
typedef PickPhoto = Future<PickedPhoto?> Function(PhotoSource source);

/// "Загрузка фотографии": Камера / Файлы. Resolves to the chosen source.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: DriverColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => const PhotoSourceSheet(),
  );
}

/// Opens the sheet and picks the photo; shows an error for files over 5 MB
/// (the backend limit).
Future<PickedPhoto?> choosePhoto(BuildContext context, PickPhoto pick) async {
  final messenger = ScaffoldMessenger.of(context);
  final source = await showPhotoSourceSheet(context);
  if (source == null) return null;
  try {
    final photo = await pick(source);
    if (photo != null && photo.bytes.lengthInBytes > 5 * 1024 * 1024) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Фотография должна быть не больше 5 МБ')),
      );
      return null;
    }
    return photo;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Не удалось загрузить фотографию')),
    );
    return null;
  }
}

class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 43,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Загрузка фотографии', style: DriverText.cardTitle),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    key: const ValueKey('photo-camera'),
                    label: 'Камера',
                    asset: 'assets/images/driver/photo_camera.png',
                    onTap: () => Navigator.pop(context, PhotoSource.camera),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _SourceTile(
                    key: const ValueKey('photo-files'),
                    label: 'Файлы',
                    asset: 'assets/images/driver/photo_files.png',
                    onTap: () => Navigator.pop(context, PhotoSource.files),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    super.key,
    required this.label,
    required this.asset,
    required this.onTap,
  });

  final String label;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriverColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                asset,
                width: 48,
                height: 48,
                errorBuilder: (_, _, _) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DriverColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: DriverText.body.copyWith(color: DriverColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
