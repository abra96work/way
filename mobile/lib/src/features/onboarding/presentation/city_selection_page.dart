import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CitySelectionPage extends StatefulWidget {
  const CitySelectionPage({super.key, this.onCitySelected, this.loadCities});

  final ValueChanged<String>? onCitySelected;
  final Future<List<String>> Function()? loadCities;

  @override
  State<CitySelectionPage> createState() => _CitySelectionPageState();
}

class _CitySelectionPageState extends State<CitySelectionPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _surface = Color(0xFFF3F3F3);
  static const _divider = Color(0xFFE4E5E6);
  static const _text = Color(0xFF0C0C0C);
  static const _secondaryText = Color(0x7F0C0C0C);
  static const _primary = Color(0xFF1EB74D);

  static const _previewCities = <String>[
    'Абакан',
    'Анадырь',
    'Архангельск',
    'Астрахань',
    'Барнаул',
    'Белгород',
    'Биробиджан',
    'Благовещенск',
    'Брянск',
    'Владивосток',
    'Владикавказ',
    'Владимир',
    'Москва',
  ];

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late List<String> _cities = widget.loadCities == null
      ? _previewCities
      : const [];
  bool _isLoadingCities = false;
  String? _citiesError;
  String _query = '';
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChange);
    if (widget.loadCities != null) _loadCities();
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filteredGroups;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(
                width: double.infinity,
                height: 76,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _divider)),
                  ),
                  child: Center(
                    child: Text(
                      'Выберите ваш город',
                      key: ValueKey('city-selection-title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: double.infinity,
                height: 64,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Поездки доступны в выбранном городе и его\nокрестностях',
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.42,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    key: const ValueKey('city-search'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _updateQuery,
                    onSubmitted: (_) => _searchFocusNode.unfocus(),
                    textInputAction: TextInputAction.done,
                    cursorColor: _primary,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.33,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск города...',
                      hintStyle: const TextStyle(color: _secondaryText),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _searchFocusNode.hasFocus
                            ? _primary
                            : const Color(0xFF858788),
                        size: 20,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 20,
                      ),
                      suffixIcon: _searchFocusNode.hasFocus && _query.isNotEmpty
                          ? IconButton(
                              key: const ValueKey('city-search-clear'),
                              onPressed: _clearSearch,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(
                                Icons.cancel,
                                color: _text,
                                size: 16,
                              ),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _divider),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _primary),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingCities
                    ? const Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                    : _citiesError != null
                    ? _CityLoadError(onRetry: _loadCities)
                    : _selectedCity == null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: ColoredBox(
                          color: Colors.white,
                          child: groups.isEmpty
                              ? const _EmptyCitySearch()
                              : ListView.builder(
                                  key: const ValueKey('city-list'),
                                  padding: EdgeInsets.zero,
                                  itemCount: groups.length,
                                  itemBuilder: (context, index) {
                                    final entry = groups[index];
                                    return _CityGroup(
                                      letter: entry.key,
                                      cities: entry.value,
                                      showDivider: index < groups.length - 1,
                                      onCitySelected: _selectCity,
                                    );
                                  },
                                ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton(
                              key: const ValueKey('city-continue'),
                              onPressed: _continueWithSelectedCity,
                              style: ButtonStyle(
                                backgroundColor: const WidgetStatePropertyAll(
                                  _primary,
                                ),
                                foregroundColor: const WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                                overlayColor: const WidgetStatePropertyAll(
                                  Color(0x1FFFFFFF),
                                ),
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.38,
                                  ),
                                ),
                              ),
                              child: const Text('Далее'),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MapEntry<String, List<String>>> get _filteredGroups {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = _cities.where(
      (city) => city.toLowerCase().contains(normalizedQuery),
    );
    final groups = <String, List<String>>{};
    for (final city in filtered) {
      groups.putIfAbsent(city[0], () => []).add(city);
    }
    return groups.entries.toList(growable: false);
  }

  Future<void> _loadCities() async {
    final loader = widget.loadCities;
    if (loader == null) return;
    setState(() {
      _isLoadingCities = true;
      _citiesError = null;
    });
    try {
      final cities = await loader();
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (_) {
      if (!mounted) return;
      setState(() => _citiesError = 'Не удалось загрузить список городов');
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  void _selectCity(String city) {
    _searchController.value = TextEditingValue(
      text: city,
      selection: TextSelection.collapsed(offset: city.length),
    );
    _searchFocusNode.unfocus();
    setState(() {
      _query = city;
      _selectedCity = city;
    });
  }

  void _continueWithSelectedCity() {
    final city = _selectedCity;
    if (city == null) return;
    if (widget.onCitySelected case final callback?) {
      callback(city);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Следующий экран появится далее')),
      );
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
      if (_selectedCity != value.trim()) {
        _selectedCity = null;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCity = null;
    });
    _searchFocusNode.requestFocus();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }
}

class _CityLoadError extends StatelessWidget {
  const _CityLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Не удалось загрузить список городов',
          style: TextStyle(color: _CitySelectionPageState._secondaryText),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

class _CityGroup extends StatelessWidget {
  const _CityGroup({
    required this.letter,
    required this.cities,
    required this.showDivider,
    required this.onCitySelected,
  });

  final String letter;
  final List<String> cities;
  final bool showDivider;
  final ValueChanged<String> onCitySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 7),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: _CitySelectionPageState._divider),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: _CitySelectionPageState._surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                color: _CitySelectionPageState._text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final city in cities)
            InkWell(
              key: ValueKey('city-$city'),
              onTap: () => onCitySelected(city),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    city,
                    style: const TextStyle(
                      color: _CitySelectionPageState._text,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      height: 1.29,
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

class _EmptyCitySearch extends StatelessWidget {
  const _EmptyCitySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Город не найден',
        key: ValueKey('city-search-empty'),
        style: TextStyle(
          color: _CitySelectionPageState._secondaryText,
          fontSize: 15,
        ),
      ),
    );
  }
}
