import 'package:flutter/material.dart';

import '../widgets/driver_header.dart';
import '../widgets/driver_style.dart';
import '../widgets/photo_source_sheet.dart';

/// "СТС": photo of the registration certificate. Pops with the photo on
/// "Готово"; the backend only stores it (`PUT /cars/{id}/sts`).
class StsPage extends StatefulWidget {
  const StsPage({super.key, required this.pickPhoto, this.initial});

  final PickPhoto pickPhoto;
  final PickedPhoto? initial;

  @override
  State<StsPage> createState() => _StsPageState();
}

class _StsPageState extends State<StsPage> {
  late PickedPhoto? _photo = widget.initial;

  Future<void> _take() async {
    final photo = await choosePhoto(context, widget.pickPhoto);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DriverHeader(title: 'СТС'),
            Expanded(
              child: photo == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'СТС (свидетельство о регистрации)',
                              textAlign: TextAlign.center,
                              style: DriverText.cardTitle,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Загрузите фото документа автомобиля',
                              textAlign: TextAlign.center,
                              style: DriverText.body,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Проверьте, что документ хорошо читается',
                          textAlign: TextAlign.center,
                          style: DriverText.body,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              photo.bytes,
                              key: const ValueKey('sts-preview'),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('sts-primary'),
                      onPressed: photo == null
                          ? _take
                          : () => Navigator.pop(context, photo),
                      style: FilledButton.styleFrom(
                        backgroundColor: DriverColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: DriverText.label,
                      ),
                      child: Text(photo == null ? 'Сделать фото' : 'Готово'),
                    ),
                  ),
                  if (photo != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const ValueKey('sts-retake'),
                        onPressed: _take,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DriverColors.primary,
                          side: const BorderSide(color: DriverColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: DriverText.label,
                        ),
                        child: const Text('Переснять'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
