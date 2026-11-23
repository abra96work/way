import 'package:flutter/material.dart';

const _primary = Color(0xFF1EB74D);
const _background = Color(0xFFF1F2F3);
const _text = Color(0xFF151619);
const _secondary = Color(0xFF77797E);

class PassengerAddressSuggestion {
  const PassengerAddressSuggestion({
    required this.title,
    this.subtitle,
    this.isCurrentLocation = false,
  });

  final String title;
  final String? subtitle;
  final bool isCurrentLocation;
}

typedef SearchPassengerAddresses =
    Future<List<PassengerAddressSuggestion>> Function(String query);

Future<PassengerAddressSuggestion?> showPassengerAddressSearchSheet(
  BuildContext context, {
  SearchPassengerAddresses? search,
}) => showModalBottomSheet<PassengerAddressSuggestion>(
  context: context,
  isScrollControlled: true,
  useSafeArea: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.38),
  builder: (_) => _PassengerAddressSearchSheet(search: search),
);

class _PassengerAddressSearchSheet extends StatefulWidget {
  const _PassengerAddressSearchSheet({this.search});

  final SearchPassengerAddresses? search;

  @override
  State<_PassengerAddressSearchSheet> createState() =>
      _PassengerAddressSearchSheetState();
}

class _PassengerAddressSearchSheetState
    extends State<_PassengerAddressSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PassengerAddressSuggestion> _suggestions = _defaultSuggestions;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_search);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_search)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        key: const ValueKey('passenger-address-search-sheet'),
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .90,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 43,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCACBCE),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  key: const ValueKey('passenger-address-query'),
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Введите адрес',
                    hintStyle: const TextStyle(color: _secondary),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: _primary,
                      size: 25,
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('passenger-address-clear'),
                            onPressed: _controller.clear,
                            icon: const Icon(Icons.close, size: 19),
                          ),
                    filled: true,
                    fillColor: _background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: _primary,
                  backgroundColor: Colors.transparent,
                ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('passenger-address-results'),
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return _AddressResultTile(
                      resultKey: ValueKey(
                        'passenger-address-$index-${suggestion.title}',
                      ),
                      suggestion: suggestion,
                      onTap: () => Navigator.pop(context, suggestion),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _search() async {
    final request = ++_request;
    final query = _controller.text.trim();
    final search = widget.search;
    if (search == null) {
      final normalized = query.toLowerCase();
      setState(() {
        _suggestions = normalized.isEmpty
            ? _defaultSuggestions
            : _defaultSuggestions
                  .where(
                    (value) =>
                        value.title.toLowerCase().contains(normalized) ||
                        (value.subtitle?.toLowerCase().contains(normalized) ??
                            false),
                  )
                  .toList(growable: false);
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await search(query);
      if (!mounted || request != _request) return;
      setState(() => _suggestions = results);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }
}

class _AddressResultTile extends StatelessWidget {
  const _AddressResultTile({
    required this.resultKey,
    required this.suggestion,
    required this.onTap,
  });

  final Key resultKey;
  final PassengerAddressSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: resultKey,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              suggestion.isCurrentLocation
                  ? Icons.my_location
                  : Icons.location_on,
              color: suggestion.isCurrentLocation ? _primary : _secondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suggestion.subtitle case final subtitle?) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _text, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _defaultSuggestions = <PassengerAddressSuggestion>[
  PassengerAddressSuggestion(
    title: 'Моё местоположение',
    isCurrentLocation: true,
  ),
  PassengerAddressSuggestion(title: 'Московский, 56', subtitle: 'Москва'),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
  PassengerAddressSuggestion(
    title: 'Адрес',
    subtitle: 'Москва, Московская область',
  ),
];
