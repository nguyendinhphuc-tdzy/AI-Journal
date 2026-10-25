import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import '../data/explore_places_repository.dart';
import 'widgets/nudaeng_map_marker.dart';
import 'widgets/place_sheets.dart';
import 'widgets/share_dialog.dart';

Future<void> showShareDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const ShareDialog());

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.placesRepository = const MockExplorePlacesRepository(),
    this.clock,
  });

  final ExplorePlacesRepository placesRepository;

  /// Allows deterministic day/night rendering in widget tests.
  final DateTime Function()? clock;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _dayStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const _nightStyle = 'https://tiles.openfreemap.org/styles/dark';
  // The requested ngu.gif asset is not part of this repository yet. Keep the
  // fallback local and replace this path once that approved asset is added.
  static const _nightMascotAsset = 'assets/images/loading.gif';

  late final bool _isNight;
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
  String _selectedMood = 'Tất cả';
  List<ExplorePlace> _places = [];
  ExplorePlace? _selected;
  LatLng? _draftPin;
  LatLng _currentCameraPosition = const LatLng(10.8231, 106.6297);
  final List<SavedPlace> _savedPlaces = [
    const SavedPlace(
      id: 'saved:0',
      name: 'Góc đọc sách ven sông',
      category: 'Chill',
      moodTag: 'Yên tĩnh',
      note: 'Gió nhẹ và đủ yên để đọc vài trang sách.',
      latitude: 10.7792,
      longitude: 106.6974,
      moodAsset: 'assets/images/docsach.gif',
      moodLabel: 'Reading',
    ),
    const SavedPlace(
      id: 'saved:1',
      name: 'Con đường nhỏ đầy nắng',
      category: 'Chill',
      moodTag: 'Cần chữa lành',
      note: 'Một đoạn đường để đi chậm và hít thở.',
      latitude: 10.7709,
      longitude: 106.7048,
      moodAsset: 'assets/images/laixe.gif',
      moodLabel: 'On the road',
    ),
    const SavedPlace(
      id: 'saved:2',
      name: 'Quán bánh cuối tuần',
      category: 'Food',
      moodTag: 'Vui vẻ',
      note: 'Một nơi để gặp bạn bè và cười thật nhiều.',
      latitude: 10.7757,
      longitude: 106.6929,
      moodAsset: 'assets/images/like.gif',
      moodLabel: 'Loved it',
    ),
  ];
  int _nextSavedPlaceId = 3;
  bool _hasUnreadMail = true;
  bool _showAnonymous = false;

  /// Mock community posts deliberately contain no name, account or identifier.
  final List<Map<String, dynamic>> _anonymousPlaces = [
    {
      'id': 'hope-1',
      'latitude': 10.7733,
      'longitude': 106.6983,
      'message':
          'Một người lạ đã từng rất áp lực ở đây, nhưng mọi chuyện rồi sẽ ổn!',
    },
    {
      'id': 'hope-2',
      'latitude': 10.7816,
      'longitude': 106.7040,
      'message': 'Bạn không cần phải mạnh mẽ mọi lúc. Hãy nghỉ một chút nhé.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Use Android TextureView so Flutter overlays and tab clipping compose
    // correctly; the default SurfaceView uses a separate virtual display.
    MapLibreMap.useHybridComposition = true;
    final hour = (widget.clock?.call() ?? DateTime.now()).hour;
    _isNight = hour >= 18 || hour < 5;
    _search();
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
      final results = await widget.placesRepository.search(_query, null);
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

  void _filterPlacesByMood(String mood) {
    setState(() => _selectedMood = mood);
    _syncMarkers();
  }

  void _toggleAnonymous(bool value) {
    setState(() => _showAnonymous = value);
    _syncMarkers();
  }

  Future<void> _showAnonymousMessage(Map<String, dynamic> place) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipOval(
                child: Image.asset('assets/images/loading.gif',
                    height: 76, width: 76)),
            const SizedBox(height: 14),
            const Text('Trạm dừng ẩn danh',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(place['message'] as String, textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng')),
          ],
        ),
      );

  List<SavedPlace> get _visibleSavedPlaces => _selectedMood == 'Tất cả'
      ? _savedPlaces
      : _savedPlaces.where((place) => place.moodTag == _selectedMood).toList();

  void _created(MapLibreMapController controller) {
    _map = controller;
    _currentCameraPosition =
        controller.cameraPosition?.target ?? _currentCameraPosition;
    controller.onSymbolTapped.add((symbol) {
      if (!mounted || _map != controller) return;
      final id = symbol.data?['id'];
      if (id is String && id.startsWith('anonymous:')) {
        Map<String, dynamic>? anonymous;
        for (final place in _anonymousPlaces) {
          if ('anonymous:${place['id']}' == id) {
            anonymous = place;
            break;
          }
        }
        if (anonymous != null) _showAnonymousMessage(anonymous);
        return;
      }
      if (id is String && id.startsWith('saved:')) {
        SavedPlace? saved;
        for (final place in _savedPlaces) {
          if (place.id == id) {
            saved = place;
            break;
          }
        }
        final selectedPlace = saved;
        if (selectedPlace != null) {
          showSavedPlaceSheet(context, selectedPlace,
              onShare: () => _showShareBottomSheet(selectedPlace));
        }
        return;
      }
      for (final place in _places) {
        if (place.id == id) {
          setState(() => _selected = place);
          return;
        }
      }
      if (id == 'draft') setState(() => _selected = null);
    });
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_styleReady) setState(() => _loadFailed = true);
    });
  }

  String get _mapStyle => _isNight ? _nightStyle : _dayStyle;

  String get _vibeLabel => _isNight ? 'Vibe ban đêm' : 'Vibe ban ngày';

  Future<void> _styleLoaded() async {
    final map = _map;
    if (map == null) return;
    try {
      final markers = <String, Uint8List>{};
      for (final mood in moodOptions) {
        final mascotAsset = _isNight ? _nightMascotAsset : mood.$2;
        markers['nudaeng-${mood.$1}'] = await createNudaengMarker(mascotAsset);
      }
      markers['nudaeng'] = markers['nudaeng-Reading']!;
      markers['anonymous'] = await createNudaengMarker(
        _isNight ? _nightMascotAsset : 'assets/images/loading.gif',
        const Color(0xFF6FBFB5),
      );
      if (!mounted || _map != map) return;
      for (final marker in markers.entries) {
        await map.addImage(marker.key, marker.value);
      }
      if (!mounted || _map != map) return;
      _loadTimeout?.cancel();
      setState(() {
        _styleReady = true;
        _loadFailed = false;
      });
      _syncMarkers();
    } catch (_) {
      if (mounted && _map == map) setState(() => _loadFailed = true);
    }
  }

  /// Mirrors the in-memory saved-place state to MapLibre native symbols.
  ///
  /// MapLibre has no declarative `markers: Set<Marker>` property like Google
  /// Maps. Waiting for this future means a successful save is already queued
  /// (and normally rendered) before its confirmation is shown.
  Future<void> _syncMarkers() {
    final map = _map;
    if (!_styleReady || map == null) return Future.value();
    // Serialize annotation updates so quick searches/taps cannot duplicate pins.
    _markerWork = _markerWork.then((_) async {
      if (!mounted || _map != map || !_styleReady) return;
      final places = List<ExplorePlace>.of(_places);
      final savedPlaces = List<SavedPlace>.of(_visibleSavedPlaces);
      final anonymousPlaces = _showAnonymous
          ? List<Map<String, dynamic>>.of(_anonymousPlaces)
          : const <Map<String, dynamic>>[];
      final draft = _draftPin;
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
      for (final place in savedPlaces) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: 'nudaeng-${place.moodLabel}',
              iconSize: .5,
              iconAnchor: 'bottom',
            ),
            {'id': place.id});
        if (!mounted || _map != map) return;
      }
      for (final place in anonymousPlaces) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(
                place['latitude'] as double,
                place['longitude'] as double,
              ),
              iconImage: 'anonymous',
              iconSize: .5,
              iconAnchor: 'bottom',
            ),
            {'id': 'anonymous:${place['id']}'});
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
    }).catchError((Object error) {
      if (mounted && _map == map) setState(() => _loadFailed = true);
    });
    return _markerWork;
  }

  void _pick(math.Point<double> point, LatLng coordinate) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draftPin = coordinate;
      _selected = null;
    });
    _syncMarkers();
  }

  Future<void> _addPlace() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await showAddPlaceSheet(context);
    if (!mounted || draft == null) return;
    await _saveNewPlace(draft);
  }

  /// Stores a private place or a community pin at the current map centre.
  ///
  /// MapLibre renders annotations imperatively, so [_syncMarkers] is the
  /// equivalent of updating a GoogleMap `Set<Marker>` after `setState`.
  Future<void> _saveNewPlace(PlaceDraft draft) async {
    try {
      final markerIdVal = 'marker_${DateTime.now().millisecondsSinceEpoch}';
      final target = _currentCameraPosition;
      setState(() {
        if (draft.isAnonymousShare) {
          _anonymousPlaces.add({
            'id': markerIdVal,
            'latitude': target.latitude,
            'longitude': target.longitude,
            'message': draft.note.isEmpty
                ? 'Một người bạn ẩn danh để lại nơi này để bạn có thể dừng lại và thở thật sâu.'
                : draft.note,
          });
          // Make a newly shared community pin visible immediately.
          _showAnonymous = true;
        } else {
          _savedPlaces.add(SavedPlace(
            id: 'saved:$markerIdVal',
            name: draft.name,
            category: draft.category,
            moodTag: draft.moodTag,
            note: draft.note,
            latitude: target.latitude,
            longitude: target.longitude,
            moodAsset: draft.moodAsset,
            moodLabel: draft.moodLabel,
          ));
        }
        _draftPin = null;
        _selected = null;
      });
      await _syncMarkers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            draft.isAnonymousShare ? 'Đã thả trạm ẩn danh' : 'Đã lưu cho bạn'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa lấy được vị trí bản đồ. Hãy thử lại.')));
      }
    }
  }

  Future<void> _showShareBottomSheet(SavedPlace place) async {
    final recipients =
        await showShareFriendsSheet(context, placeName: place.name);
    if (!mounted || recipients == null || recipients.isEmpty) return;
    await _showDeliveryAnimation(recipients);
  }

  Future<void> _showDeliveryAnimation(List<String> recipients) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/laixe.gif', height: 140),
          const SizedBox(height: 12),
          const Text('Nudaeng đang giao thư...',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Thư đã được gửi thành công tới ${recipients.join(', ')}!')));
  }

  Future<void> _showInbox() async {
    final accept = await showInboxSheet(context);
    if (!mounted || accept != true) return;
    final target =
        _map?.cameraPosition?.target ?? const LatLng(10.7768, 106.7008);
    setState(() {
      _hasUnreadMail = false;
      _savedPlaces.add(SavedPlace(
        id: 'saved:${_nextSavedPlaceId++}',
        name: 'Góc bí mật của Tường Vy',
        category: 'Chill',
        moodTag: 'Cần chữa lành',
        note: 'Một nơi Tường Vy muốn gửi bạn ghé qua.',
        latitude: target.latitude,
        longitude: target.longitude,
        moodAsset: 'assets/images/laixe.gif',
        moodLabel: 'On the road',
      ));
    });
    _syncMarkers();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu vào bản đồ của bạn')));
  }

  Future<void> _showPlace(ExplorePlace place) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _selected = place;
      _query = '';
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
            styleString: _mapStyle,
            initialCameraPosition: const CameraPosition(
                target: LatLng(10.8231, 106.6297), zoom: 12),
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            trackCameraPosition: true,
            onCameraMove: (position) {
              _currentCameraPosition = position.target;
            },
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
                            onSelected: _filterPlacesByMood,
                            itemBuilder: (_) => [
                                  for (final mood in [
                                    'Tất cả',
                                    ...moodTags,
                                  ])
                                    CheckedPopupMenuItem(
                                        value: mood,
                                        checked: _selectedMood == mood,
                                        child: Text(mood))
                                ]))),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(clipBehavior: Clip.none, children: [
                      IconButton(
                        tooltip: 'Open inbox',
                        onPressed: _showInbox,
                        icon: const Icon(Icons.mail_outline),
                      ),
                      if (_hasUnreadMail)
                        const Positioned(
                          top: 9,
                          right: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 9, height: 9),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Material(
                color: Colors.white.withValues(alpha: .94),
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.volunteer_activism_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Cộng đồng ẩn danh')),
                    Switch.adaptive(
                      value: _showAnonymous,
                      onChanged: _toggleAnonymous,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          _selectedMood == 'Tất cả'
                              ? '$_vibeLabel · Khám phá theo cảm xúc · Chạm/nhấn giữ để ghim tạm'
                              : '$_vibeLabel · Đang xem: $_selectedMood · ${_visibleSavedPlaces.length} địa điểm',
                          textAlign: TextAlign.center))),
              if (_query.trim().isNotEmpty || _searchError != null)
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
          if (_selected != null || _draftPin != null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 96,
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
          Positioned(
            right: 18,
            bottom: 26,
            child: FloatingActionButton(
              heroTag: 'add-place',
              tooltip: 'Save a new place',
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              onPressed: _addPlace,
              child: const Icon(Icons.add_location_alt),
            ),
          ),
        ]),
      );
}
