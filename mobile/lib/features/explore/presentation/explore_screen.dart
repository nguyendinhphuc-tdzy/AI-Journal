import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/explore_highlight.dart';
import '../data/explore_places_repository.dart';
import '../data/remote_saved_places_repository.dart';
import 'map_style.dart';
import 'widgets/map_overlay_parts.dart';
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
    this.highlight,
  });

  final ExplorePlacesRepository placesRepository;

  /// Allows deterministic day/night rendering in widget tests.
  final DateTime Function()? clock;

  /// Shared memory pin passed from Album A10; cleared after A11/A12 revoke.
  final ExploreHighlight? highlight;

  static const searchHint = 'Tìm địa điểm';
  static const inboxTooltip = 'Mở hộp thư';
  static const allMoods = 'Tất cả';
  static const communityLabel = 'Cộng đồng';
  static const saveLabel = 'Lưu nơi này';
  static const pinHint = 'Chạm vào bản đồ để ghim tạm';
  static const noResults = 'Không tìm thấy địa điểm';
  static const searchFailed = 'Chưa tải được địa điểm. Bạn thử lại nhé.';
  static const retryLabel = 'Thử lại';
  static const sample = 'Địa điểm mẫu';
  static const draftTitle = 'Ghim tạm';
  static const draftDetail = 'Chưa lưu · Chạm chỗ khác để dời';
  static const closePlaceTooltip = 'Đóng địa điểm';
  static const removeDraftTooltip = 'Bỏ ghim tạm';
  static const closePostTooltip = 'Đóng bài chia sẻ';
  static const mapFailed =
      'Không tải được bản đồ. Bạn kiểm tra kết nối mạng nhé.';
  static const reloadMapLabel = 'Tải lại bản đồ';

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
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
  String _selectedMood = ExploreScreen.allMoods;
  List<ExplorePlace> _places = [];
  ExplorePlace? _selected;
  LatLng? _draftPin;
  ExploreHighlight? _highlight;
  bool _highlightCard = false;
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
  RemoteSavedPlacesRepository? _cloudPlaces;
  bool _hasUnreadMail = true;
  bool _showAnonymous = false;

  /// The pin hint is said until the first pin.
  bool _pinnedOnce = false;

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
    _highlight = widget.highlight;
    _highlightCard = _highlight != null;
    // Use Android TextureView so Flutter overlays and tab clipping compose
    // correctly; the default SurfaceView uses a separate virtual display.
    MapLibreMap.useHybridComposition = true;
    _isNight =
        ExploreMapStyle.isNightAt(widget.clock?.call() ?? DateTime.now());
    _search();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cloud = SavedPlacesScope.maybeOf(context);
    if (cloud == null || identical(cloud, _cloudPlaces)) return;
    _cloudPlaces = cloud;
    // Authenticated cloud screens never display the three local demo pins.
    setState(() {
      _savedPlaces.clear();
    });
    _syncMarkers();
    _reloadSavedPlaces();
  }

  Future<void> _reloadSavedPlaces() async {
    final cloud = _cloudPlaces;
    if (cloud == null) return;
    try {
      final items = await cloud.all();
      if (!mounted || !identical(cloud, _cloudPlaces)) return;
      setState(() {
        _savedPlaces..clear()..addAll(items);
      });
      await _syncMarkers();
    } catch (_) {
      if (!mounted || !identical(cloud, _cloudPlaces)) return;
      _toast('Không tải được địa điểm đã lưu từ tài khoản. Thử mở lại bản đồ.');
    }
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
      final results = await widget.placesRepository.search(_query, null);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = results;
        _searchError = null;
      });
      _syncMarkers();
      _focusHighlight();
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = [];
        _searchError = ExploreScreen.searchFailed;
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
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: (dialog) => Dialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.modal)),
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipOval(
                        child: Image.asset('assets/images/loading.gif',
                            height: 76, width: 76)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: const Text('Trạm dừng ẩn danh',
                        textAlign: TextAlign.center,
                        style: AppText.sectionTitle),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(place['message'] as String,
                      textAlign: TextAlign.center,
                      style: AppText.bodySecondary),
                  const SizedBox(height: AppSpacing.xl),
                  AppSecondaryButton(
                      label: 'Đóng',
                      compact: true,
                      onPressed: () => Navigator.pop(dialog)),
                ],
              ),
            ),
          ),
        ),
      );

  List<SavedPlace> get _visibleSavedPlaces => _selectedMood ==
          ExploreScreen.allMoods
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
      if (highlight != null) {
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
    return _markerWork;
  }

  void _pick(math.Point<double> point, LatLng coordinate) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draftPin = coordinate;
      _selected = null;
      _highlightCard = false;
      _pinnedOnce = true;
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
    final cloud = _cloudPlaces;
    if (cloud != null && !draft.isAnonymousShare) {
      final target = _draftPin ?? _currentCameraPosition;
      try {
        final saved = await cloud.create(
          draft,
          latitude: target.latitude,
          longitude: target.longitude,
        );
        if (!mounted) return;
        setState(() {
          _savedPlaces.add(saved);
          _draftPin = null;
          _selected = null;
        });
        await _syncMarkers();
        if (mounted) _toast('Đã lưu vào tài khoản');
      } on PartiallySavedPlace {
        // The pin was created; reloading prevents a retry from duplicating it.
        await _reloadSavedPlaces();
        if (mounted) {
          _toast('Đã tạo ghim nhưng chưa lưu được ghi chú. Vui lòng kiểm tra lại.');
        }
      } catch (_) {
        if (mounted) _toast('Không lưu được ghim trên cloud. Hãy thử lại.');
      }
      return;
    }
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
      _toast(draft.isAnonymousShare ? 'Đã thả trạm ẩn danh' : 'Đã lưu cho bạn');
    } catch (_) {
      if (mounted) {
        _toast('Chưa lấy được vị trí bản đồ. Bạn thử lại nhé.');
      }
    }
  }

  /// A short message, above the floating "Cộng đồng" / "Lưu nơi này" row so
  /// it never covers them.
  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 116),
    ));

  Future<void> _showShareBottomSheet(SavedPlace place) async {
    if (_cloudPlaces != null) {
      _toast('Chia sẻ địa điểm chưa được hỗ trợ trên cloud.');
      return;
    }
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
          Text('Nudaeng đang giao thư…',
              style: AppText.label.copyWith(color: AppColors.surface)),
        ]),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _toast('Thư đã được gửi tới ${recipients.join(', ')}!');
  }

  Future<void> _showInbox() async {
    if (_cloudPlaces != null) {
      _toast('Hòm thư mẫu chưa kết nối với tài khoản.');
      return;
    }
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
    _toast('Đã lưu vào bản đồ của bạn');
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

  /// One line under the chips: the vibe, and either the pin hint (until
  /// the first pin) or what the chosen mood shows. Nothing once both are
  /// said.
  String? get _status {
    if (_selectedMood != ExploreScreen.allMoods) {
      return '$_vibeLabel · Đang xem: $_selectedMood · '
          '${_visibleSavedPlaces.length} địa điểm';
    }
    return _pinnedOnce ? null : '$_vibeLabel · ${ExploreScreen.pinHint}';
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _activeHighlight;
    final showHighlight = _selected == null &&
        _draftPin == null &&
        _highlightCard &&
        highlight != null;
    final status = _status;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(fit: StackFit.expand, children: [
        MapLibreMap(
          key: ValueKey(_generation),
          styleString: ExploreMapStyle.day,
          initialCameraPosition:
              const CameraPosition(target: LatLng(10.8231, 106.6297), zoom: 12),
          onMapCreated: _created,
          onStyleLoadedCallback: _styleLoaded,
          trackCameraPosition: true,
          onCameraMove: (position) {
            _currentCameraPosition = position.target;
          },
          onMapClick: _pick,
          onMapLongClick: _pick,
          compassViewMargins: const math.Point(16, 140),
          attributionButtonMargins: const math.Point(16, 12),
        ),
        SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 0),
            child: Column(children: [
              Row(children: [
                Expanded(child: _buildSearch()),
                const SizedBox(width: 12),
                _buildInbox(),
              ]),
              const SizedBox(height: 12),
              _buildMoods(),
              if (status != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MapFloatingSurface(
                    radius: 16,
                    color: AppColors.surface.withValues(alpha: .94),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            _isNight
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_outlined,
                            size: 16,
                            color: AppColors.warmAccent),
                        const SizedBox(width: 6),
                        Flexible(child: Text(status, style: AppText.meta)),
                      ]),
                    ),
                  ),
                ),
              ],
              if (_query.trim().isNotEmpty || _searchError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: _buildResults()),
              ],
            ]),
          ),
        ),
        if (_loadFailed) Center(child: _buildMapFailed()),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: 44,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (showHighlight) ...[
                MapInfoCard(
                  icon: Icons.share_location_outlined,
                  title: highlight.title,
                  subtitle: highlight.subtitle,
                  closeTooltip: ExploreScreen.closePostTooltip,
                  onClose: () => setState(() => _highlightCard = false),
                ),
                const SizedBox(height: 12),
              ],
              if (_selected != null || _draftPin != null) ...[
                MapInfoCard(
                  icon: _selected != null
                      ? Icons.place_outlined
                      : Icons.push_pin_outlined,
                  title: _selected?.label ?? ExploreScreen.draftTitle,
                  subtitle: _selected != null
                      ? '${_selected!.category} · ${ExploreScreen.sample}'
                      : ExploreScreen.draftDetail,
                  closeTooltip: _selected != null
                      ? ExploreScreen.closePlaceTooltip
                      : ExploreScreen.removeDraftTooltip,
                  onClose: () {
                    setState(() {
                      if (_selected == null) _draftPin = null;
                      _selected = null;
                    });
                    _syncMarkers();
                  },
                ),
                const SizedBox(height: 12),
              ],
              _buildActions(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearch() => MapFloatingSurface(
        child: TextField(
          controller: _searchController,
          onChanged: _queryChanged,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppText.body,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: ExploreScreen.searchHint,
            hintStyle: AppText.bodySecondary,
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textSecondary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );

  Widget _buildInbox() => MapFloatingSurface(
        child: SizedBox.square(
          dimension: 52,
          child: Stack(alignment: Alignment.center, children: [
            IconButton(
              tooltip: ExploreScreen.inboxTooltip,
              onPressed: _showInbox,
              icon: const Icon(Icons.mail_outline_rounded,
                  color: AppColors.textPrimary),
            ),
            if (_hasUnreadMail)
              Positioned(
                top: 12,
                right: 12,
                child: IgnorePointer(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAction,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );

  /// Every mood, as chips; the shadow needs a little room to show.
  Widget _buildMoods() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(children: [
          for (final (index, mood)
              in [ExploreScreen.allMoods, ...moodTags].indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            MapMoodChip(
              label: mood,
              selected: _selectedMood == mood,
              onTap: () => _filterPlacesByMood(
                  _selectedMood == mood ? ExploreScreen.allMoods : mood),
            ),
          ],
        ]),
      );

  Widget _buildResults() => MapFloatingSurface(
        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
          if (_searchError != null)
            ListTile(
              title: Text(_searchError!, style: AppText.body),
              trailing: IconButton(
                  tooltip: ExploreScreen.retryLabel,
                  onPressed: _search,
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.primaryAction)),
            ),
          if (_places.isEmpty && _searchError == null)
            const ListTile(
                title: Text(ExploreScreen.noResults,
                    style: AppText.bodySecondary)),
          for (final place in _places)
            ListTile(
              leading: const Icon(Icons.place_outlined,
                  color: AppColors.primaryAction),
              title: Text(place.label, style: AppText.label),
              subtitle: Text('${place.category} · ${ExploreScreen.sample}',
                  style: AppText.meta),
              onTap: () => _showPlace(place),
            ),
        ]),
      );

  Widget _buildMapFailed() => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: MapFloatingSurface(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 32, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text(ExploreScreen.mapFailed,
                  textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                  label: ExploreScreen.reloadMapLabel,
                  icon: Icons.refresh_rounded,
                  compact: true,
                  onPressed: _retryMap),
            ]),
          ),
        ),
      );

  /// Community on the left, "Lưu nơi này" on the right; on a narrow screen
  /// the save button keeps only its icon.
  Widget _buildActions() => LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        return Row(children: [
          MapFloatingSurface(
            radius: 24,
            child: Semantics(
              label: 'Hiện trạm cộng đồng ẩn danh',
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      size: 20, color: AppColors.primaryAction),
                  const SizedBox(width: 6),
                  Text(ExploreScreen.communityLabel,
                      style: AppText.label.copyWith(fontSize: 14)),
                  Switch(
                    value: _showAnonymous,
                    onChanged: _toggleAnonymous,
                    activeTrackColor: AppColors.primaryAction,
                    activeThumbColor: AppColors.surface,
                    inactiveTrackColor: AppColors.background,
                    inactiveThumbColor: AppColors.textSecondary,
                    trackOutlineColor:
                        const WidgetStatePropertyAll(AppColors.border),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ]),
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: ExploreScreen.saveLabel,
            child: DecoratedBox(
              decoration: const ShapeDecoration(
                  shape: StadiumBorder(), shadows: mapOverlayShadow),
              child: FilledButton(
                onPressed: _addPlace,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 20),
                  shape: const StadiumBorder(),
                  textStyle: AppText.label,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_location_alt_outlined, size: 22),
                  if (!narrow) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Text(ExploreScreen.saveLabel),
                  ],
                ]),
              ),
            ),
          ),
        ]);
      });
}
