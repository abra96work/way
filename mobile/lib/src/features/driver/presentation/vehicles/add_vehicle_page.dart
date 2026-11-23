import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_api_exception.dart';
import '../../domain/trip_draft.dart' show VehicleType;
import '../widgets/driver_header.dart';
import '../widgets/driver_style.dart';
import '../widgets/photo_source_sheet.dart';
import 'catalog_picker_sheet.dart';
import 'sts_page.dart';

/// Everything "Добавление нового ТС" collects.
@immutable
class NewVehicle {
  const NewVehicle({
    required this.model,
    required this.type,
    required this.seats,
    this.plate,
    this.photo,
    this.sts,
  });

  final CatalogItem model;
  final VehicleType type;

  /// Passenger seats, without the driver.
  final int seats;
  final String? plate;
  final PickedPhoto? photo;
  final PickedPhoto? sts;

  /// Body of `POST /api/v1/cars`.
  Map<String, dynamic> toJson() => {
    'model_id': model.id,
    'vehicle_type': type.apiValue,
    'seats': seats,
    if (plate != null) 'plate': plate,
  };
}

/// "Добавление нового ТС": brand, model, seats, photo, type, СТС.
class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({
    super.key,
    required this.loadBrands,
    required this.loadModels,
    required this.pickPhoto,
    required this.onSubmit,
    this.openSts,
  });

  final Future<List<CatalogItem>> Function() loadBrands;
  final Future<List<CatalogItem>> Function(int brandId) loadModels;
  final PickPhoto pickPhoto;

  /// Creates the vehicle; throws [DriverApiException] with the reason.
  final Future<void> Function(NewVehicle vehicle) onSubmit;

  /// Opens the "СТС" screen; replaced in tests.
  final Future<PickedPhoto?> Function(PickedPhoto? current)? openSts;

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  CatalogItem? _brand;
  CatalogItem? _model;
  VehicleType? _type;
  PickedPhoto? _photo;
  PickedPhoto? _sts;
  final _seats = TextEditingController();
  final _plate = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _seats.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _seats.dispose();
    _plate.dispose();
    super.dispose();
  }

  int? get _seatsValue => int.tryParse(_seats.text);

  int get _maxSeats => (_type ?? VehicleType.bus).maxSeats;

  String? get _seatsError {
    final n = _seatsValue;
    if (n == null) return null;
    if (n < 1) return 'Укажите хотя бы одно место';
    if (n > _maxSeats) {
      return _type == VehicleType.car
          ? 'В легковом не больше ${VehicleType.car.maxSeats} пассажирских мест'
          : 'В автобусе не больше ${VehicleType.bus.maxSeats} пассажирских мест';
    }
    return null;
  }

  bool get _ready =>
      _model != null &&
      _type != null &&
      _seatsValue != null &&
      _seatsError == null &&
      !_submitting;

  Future<void> _pickBrand() async {
    final brand = await showCatalogPicker(
      context,
      title: 'Выбрать марку автомобиля',
      hint: 'Марка автомобиля',
      load: widget.loadBrands,
      grouped: true,
      carIcons: true,
    );
    if (brand == null || !mounted) return;
    setState(() {
      if (brand != _brand) _model = null;
      _brand = brand;
    });
  }

  Future<void> _pickModel() async {
    final brand = _brand;
    if (brand == null) return _pickBrand();
    final model = await showCatalogPicker(
      context,
      title: 'Выбрать модель ${brand.name}',
      hint: 'Модель автомобиля',
      load: () => widget.loadModels(brand.id),
    );
    if (model != null && mounted) setState(() => _model = model);
  }

  Future<void> _addPhoto() async {
    final photo = await choosePhoto(context, widget.pickPhoto);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _openSts() async {
    final open =
        widget.openSts ??
        (current) => Navigator.of(context).push<PickedPhoto>(
          MaterialPageRoute(
            builder: (_) =>
                StsPage(pickPhoto: widget.pickPhoto, initial: current),
          ),
        );
    final sts = await open(_sts);
    if (sts != null && mounted) setState(() => _sts = sts);
  }

  Future<void> _submit() async {
    final plate = _plate.text.trim();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        NewVehicle(
          model: _model!,
          type: _type!,
          seats: _seatsValue!,
          plate: plate.isEmpty ? null : plate,
          photo: _photo,
          sts: _sts,
        ),
      );
    } on DriverApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не удалось добавить ТС. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DriverHeader(title: 'Добавление нового ТС'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  children: [
                    const _Label('Информация об автомобиле'),
                    _Card(
                      children: [
                        _SelectField(
                          key: const ValueKey('vehicle-brand'),
                          label: 'Марка',
                          value: _brand?.name,
                          onTap: _pickBrand,
                        ),
                        _SelectField(
                          key: const ValueKey('vehicle-model'),
                          label: 'Модель',
                          value: _model?.name,
                          onTap: _pickModel,
                        ),
                        if (_brand != null) ...[
                          _TextInput(
                            key: const ValueKey('vehicle-seats'),
                            controller: _seats,
                            label: 'Вместимость',
                            suffix: 'мест',
                            digitsOnly: true,
                            maxLength: 2,
                          ),
                          if (_seatsError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _seatsError!,
                                key: const ValueKey('vehicle-seats-error'),
                                style: const TextStyle(
                                  color: Color(0xFFD92D20),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          _TextInput(
                            key: const ValueKey('vehicle-plate'),
                            controller: _plate,
                            label: 'Госномер (необязательно)',
                            maxLength: 12,
                          ),
                        ],
                        const SizedBox(height: 11),
                        if (_photo == null)
                          SizedBox(
                            height: 32,
                            child: OutlinedButton.icon(
                              key: const ValueKey('vehicle-add-photo'),
                              onPressed: _addPhoto,
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Добавить фото'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DriverColors.primary,
                                side: const BorderSide(
                                  color: DriverColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.33,
                                ),
                              ),
                            ),
                          )
                        else
                          _PhotoPreview(
                            photo: _photo!,
                            onRemove: () => setState(() => _photo = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _Label('Тип'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TypeCard(
                              key: const ValueKey('vehicle-type-car'),
                              icon: Icons.directions_car_filled_rounded,
                              label: 'Легковой',
                              selected: _type == VehicleType.car,
                              onTap: () =>
                                  setState(() => _type = VehicleType.car),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeCard(
                              key: const ValueKey('vehicle-type-bus'),
                              icon: Icons.directions_bus_filled_rounded,
                              label: 'Автобус',
                              selected: _type == VehicleType.bus,
                              onTap: () =>
                                  setState(() => _type = VehicleType.bus),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Label('Подтверждающие документы'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: DriverColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const ValueKey('vehicle-sts'),
                          onTap: _openSts,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  color: DriverColors.text,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'СТС',
                                        style: DriverText.label,
                                      ),
                                      Text(
                                        _sts == null
                                            ? 'Фото свидетельства о регистрации'
                                            : 'Фото добавлено',
                                        style: DriverText.body.copyWith(
                                          fontSize: 13,
                                          color: _sts == null
                                              ? DriverColors.secondaryText
                                              : DriverColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: DriverColors.text,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DriverColors.divider)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('vehicle-submit'),
                    onPressed: _ready ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: DriverColors.primary,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: DriverColors.secondaryText,
                      side: _ready
                          ? null
                          : const BorderSide(color: DriverColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: DriverText.label,
                    ),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DriverColors.primary,
                            ),
                          )
                        : const Text('Добавить'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(text, style: DriverText.label),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// "Марка ›": placeholder label, or a small label over the chosen value.
class _SelectField extends StatelessWidget {
  const _SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value == null ? label : '$label: $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DriverColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: value == null
                    ? Text(label, style: DriverText.body)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: DriverText.body.copyWith(fontSize: 12),
                          ),
                          Text(
                            value!,
                            style: DriverText.body.copyWith(
                              color: DriverColors.text,
                            ),
                          ),
                        ],
                      ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DriverColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text input with a floating label, like "Вместимость … мест".
class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.digitsOnly = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool digitsOnly;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      style: DriverText.body.copyWith(color: DriverColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DriverText.body,
        floatingLabelStyle: DriverText.body.copyWith(fontSize: 12),
        suffixText: suffix,
        suffixStyle: DriverText.body.copyWith(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: DriverColors.divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: DriverColors.text),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.onRemove});

  final PickedPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 343 / 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              photo.bytes,
              key: const ValueKey('vehicle-photo'),
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: const Color(0x990C0C0C),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('vehicle-photo-remove'),
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                      semanticLabel: 'Удалить фото',
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
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFE6F6EB) : DriverColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? DriverColors.primary : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: DriverColors.text),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: DriverText.body.copyWith(color: DriverColors.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
