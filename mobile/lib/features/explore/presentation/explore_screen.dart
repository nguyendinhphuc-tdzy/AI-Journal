import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import '../data/explore_highlight.dart';
import '../data/explore_places_repository.dart';
import 'widgets/nudaeng_map_marker.dart';
import 'widgets/share_dialog.dart';

Future<void> showShareDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const ShareDialog());

class ExploreScreen extends StatefulWidget {
  const ExploreScreen(
      {super.key,
      this.placesRepository = const MockExplorePlacesRepository(),
      this.highlight});
  final ExplorePlacesRepository placesRepository;

  /// A pin to point out with its card open (a post just shared from Album).
  final ExploreHighlight? highlight;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _style = 'https://tiles.openfreemap.org/styles/liberty';
  MapLibreMapController? _map;
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _loadTimeout;
  Future<void> _markerWork = Future.value();
  int _generation = 0;
  int _searchVersion = 0;
  bool _styleReady = false;
  bool _loadFailed = false;
  String? _searchError;
  String _query = '';
  String? _filter;
  List<ExplorePlace> _places = [];
  ExplorePlace? _selected;
  LatLng? _draftPin;
  ExploreHighlight? _highlight;
  bool _highlightCard = false;

  @override
  void initState() {
    super.initState();
    _highlight = widget.highlight;
    _highlightCard = _highlight != null;
    // Use Android TextureView so Flutter overlays and tab clipping compose
    // correctly; the default SurfaceView uses a separate virtual display.
    MapLibreMap.useHybridComposition = true;
    _search();
  }

  @override
  void didUpdateWidget(ExploreScreen old) {
    super.didUpdateWidget(old);
    final highlight = widget.highlight;
    if (highlight?.id == old.highlight?.id) return;
    if (highlight == null) {
      // Taken off the map (revoked or deleted in Album).
      setState(() {
        _highlight = null;
        _highlightCard = false;
      });
      _syncMarkers();
      return;
    }
    setState(() {
      _highlight = highlight;
      _highlightCard = true;
      _selected = null;
      _draftPin = null;
    });
    _syncMarkers();
    _focusHighlight();
  }

  ExploreHighlight? get _activeHighlight {
    final highlight = _highlight;
    return highlight != null && highlight.isActive(DateTime.now())
        ? highlight
        : null;
  }

  Future<void> _focusHighlight() async {
    final highlight = _activeHighlight;
    final map = _map;
    if (highlight == null || map == null || !_styleReady) return;
    final camera = CameraUpdate.newLatLngZoom(
        LatLng(highlight.latitude, highlight.longitude), 15);
    try {
      MediaQuery.disableAnimationsOf(context)
          ? await map.moveCamera(camera)
          : await map.animateCamera(camera);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _loadTimeout?.cancel();
    _searchController.dispose();
    // MapLibreMap owns and disposes its controller.
    _map = null;
    super.dispose();
  }

  Future<void> _search() async {
    final version = ++_searchVersion;
    try {
      final results = await widget.placesRepository.search(_query, _filter);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = results;
        _searchError = null;
      });
      _syncMarkers();
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = [];
        _searchError = 'Could not load places. Try again.';
      });
      _syncMarkers();
    }
  }

  void _queryChanged(String query) {
    _debounce?.cancel();
    ++_searchVersion;
    setState(() => _query = query);
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _created(MapLibreMapController controller) {
    _map = controller;
    controller.onSymbolTapped.add((symbol) {
      if (!mounted || _map != controller) return;
      final id = symbol.data?['id'];
      for (final place in _places) {
        if (place.id == id) {
          setState(() => _selected = place);
          return;
        }
      }
      if (id == 'draft') setState(() => _selected = null);
      if (id == 'highlight') {
        setState(() {
          _selected = null;
          _highlightCard = true;
        });
      }
    });
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_styleReady) setState(() => _loadFailed = true);
    });
  }

  Future<void> _styleLoaded() async {
    final map = _map;
    if (map == null) return;
    try {
      final bytes = await createNudaengMarker();
      if (!mounted || _map != map) return;
      await map.addImage('nudaeng', bytes);
      if (!mounted || _map != map) return;
      _loadTimeout?.cancel();
      setState(() {
        _styleReady = true;
        _loadFailed = false;
      });
      _syncMarkers();
      _focusHighlight();
    } catch (_) {
      if (mounted && _map == map) setState(() => _loadFailed = true);
    }
  }

  void _syncMarkers() {
    final map = _map;
    if (!_styleReady || map == null) return;
    // Serialize annotation updates so quick searches/taps cannot duplicate pins.
    _markerWork = _markerWork.then((_) async {
      if (!mounted || _map != map || !_styleReady) return;
      final places = List<ExplorePlace>.of(_places);
      final draft = _draftPin;
      final highlight = _activeHighlight;
      await map.clearSymbols();
      if (!mounted || _map != map) return;
      for (final place in places) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: 'nudaeng',
              iconSize: .5,
              iconAnchor: 'bottom',
            ),
            {'id': place.id});
        if (!mounted || _map != map) return;
      }
      if (draft != null) {
        await map.addSymbol(
            SymbolOptions(
                geometry: draft,
                iconImage: 'nudaeng',
                iconSize: .5,
                iconAnchor: 'bottom'),
            {'id': 'draft'});
      }
      if (highlight != null) {
        // Larger than the others: the pin just shared.
        await map.addSymbol(
            SymbolOptions(
                geometry: LatLng(highlight.latitude, highlight.longitude),
                iconImage: 'nudaeng',
                iconSize: .7,
                iconAnchor: 'bottom'),
            {'id': 'highlight'});
      }
    }).catchError((Object error) {
      if (mounted && _map == map) setState(() => _loadFailed = true);
    });
  }

  void _pick(math.Point<double> point, LatLng coordinate) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draftPin = coordinate;
      _selected = null;
      _highlightCard = false;
    });
    _syncMarkers();
  }

  Future<void> _showPlace(ExplorePlace place) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _selected = place;
      _query = '';
      _highlightCard = false;
    });
    _search();
    try {
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(place.latitude, place.longitude), 15));
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _retryMap() {
    _loadTimeout?.cancel();
    setState(() {
      _map = null;
      _styleReady = false;
      _loadFailed = false;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(fit: StackFit.expand, children: [
          MapLibreMap(
            key: ValueKey(_generation),
            styleString: _style,
            initialCameraPosition: const CameraPosition(
                target: LatLng(10.8231, 106.6297), zoom: 12),
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            onMapClick: _pick,
            onMapLongClick: _pick,
            compassViewMargins: const math.Point(12, 100),
            attributionButtonMargins: const math.Point(12, 8),
          ),
          SafeArea(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(16),
                        child: TextField(
                            controller: _searchController,
                            onChanged: _queryChanged,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: const InputDecoration(
                                hintText: 'Search places',
                                prefixIcon: Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14))))),
                const SizedBox(width: 12),
                Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                        width: 52,
                        height: 52,
                        child: PopupMenuButton<String>(
                            tooltip: 'Filter places',
                            icon: const Icon(Icons.menu),
                            position: PopupMenuPosition.under,
                            onSelected: (value) {
                              _debounce?.cancel();
                              setState(() =>
                                  _filter = _filter == value ? null : value);
                              _search();
                            },
                            itemBuilder: (_) => [
                                  for (final category in [
                                    'Study Cafe',
                                    'Entertainment',
                                    'Food'
                                  ])
                                    CheckedPopupMenuItem(
                                        value: category,
                                        checked: _filter == category,
                                        child: Text(category))
                                ]))),
              ]),
              const SizedBox(height: 8),
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                          'Demo places · Tap or hold the map to drop a temporary pin',
                          textAlign: TextAlign.center))),
              if (_query.trim().isNotEmpty ||
                  _filter != null ||
                  _searchError != null)
                Flexible(
                    child: Card(
                        child: ListView(shrinkWrap: true, children: [
                  if (_searchError != null)
                    ListTile(
                        title: Text(_searchError!),
                        trailing: IconButton(
                            onPressed: _search,
                            icon: const Icon(Icons.refresh))),
                  if (_places.isEmpty && _searchError == null)
                    const ListTile(title: Text('No places found')),
                  for (final place in _places)
                    ListTile(
                        title: Text(place.label),
                        subtitle: Text('${place.category} · Demo'),
                        onTap: () => _showPlace(place)),
                ]))),
            ]),
          )),
          if (_loadFailed)
            Center(
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'Map could not load. Check your Internet connection.'),
                          TextButton(
                              onPressed: _retryMap,
                              child: const Text('Retry map')),
                        ])))),
          if (_selected == null &&
              _draftPin == null &&
              _highlightCard &&
              _activeHighlight != null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 40,
                child: SafeArea(
                    top: false,
                    child: Card(
                        child: ListTile(
                      leading: const Icon(Icons.share_location_outlined),
                      title: Text(_activeHighlight!.title),
                      subtitle: Text(_activeHighlight!.subtitle),
                      isThreeLine: true,
                      trailing: IconButton(
                          tooltip: 'Đóng bài chia sẻ',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _highlightCard = false)),
                    )))),
          if (_selected != null || _draftPin != null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 40,
                child: SafeArea(
                    top: false,
                    child: Card(
                        child: ListTile(
                      title: Text(_selected?.label ?? 'Temporary pin'),
                      subtitle: Text(_selected != null
                          ? '${_selected!.category} · Demo only'
                          : '${_draftPin!.latitude.toStringAsFixed(5)}, ${_draftPin!.longitude.toStringAsFixed(5)}\nNot saved · Tap elsewhere to move'),
                      isThreeLine: _selected == null,
                      trailing: IconButton(
                          tooltip: _selected == null
                              ? 'Remove temporary pin'
                              : 'Close place details',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              if (_selected == null) _draftPin = null;
                              _selected = null;
                            });
                            _syncMarkers();
                          }),
                    )))),
        ]),
      );
}
