import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/guest_mode_store.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/explore_highlight.dart';
import '../../social/presentation/friend_space_screen.dart';
import '../../album/album_scope.dart';
import '../../social/data/friends_sharing.dart';
import 'widgets/friend_post_card.dart';
import '../data/device_location.dart';
import '../data/explore_places_repository.dart';
import '../data/place_lookup.dart';
import '../data/remote_saved_places_repository.dart';
import 'map_style.dart';
import 'widgets/map_marker_art.dart';
import 'widgets/map_overlay_parts.dart';
import 'widgets/nudaeng_map_marker.dart';
import 'widgets/place_pick_overlay.dart';
import 'widgets/place_sheets.dart';
import 'widgets/places_sheet.dart';
import 'widgets/share_dialog.dart';

Future<void> showShareDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const ShareDialog());

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.placesRepository = const MockExplorePlacesRepository(),
    this.savedPlacesStore = const LocalSavedPlacesStore(),
    this.location = const GeolocatorDeviceLocation(),
    this.highlight,
  });

  final ExplorePlacesRepository placesRepository;

  /// Where saved places and community stops are kept between runs.
  final SavedPlacesStore savedPlacesStore;

  /// "Vị trí của tôi": permission is asked only when it is tapped.
  final DeviceLocation location;

  /// Shared memory pin passed from Album A10; cleared after A11/A12 revoke.
  final ExploreHighlight? highlight;

  static const searchHint = 'Tìm địa điểm';
  static const inboxTooltip = 'Mở hộp thư';
  static const friendsTooltip = 'Bạn bè trên app';
  static const allFilter = 'Tất cả';
  static const moodFilter = 'Cảm xúc';
  static const communityLabel = 'Cộng đồng';
  static const saveLabel = 'Lưu một nơi';
  static const saveHereLabel = 'Lưu nơi này';
  static const locateTooltip = 'Vị trí của tôi';
  static const zoomInTooltip = MapZoomButtons.zoomInTooltip;
  static const zoomOutTooltip = MapZoomButtons.zoomOutTooltip;
  static const locationDenied =
      'Bạn chưa cho phép dùng vị trí. Có thể bật lại trong Cài đặt của máy.';
  static const locationFailed = 'Chưa lấy được vị trí. Bạn thử lại nhé.';
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
  static const savedResult = 'Đã lưu';
  static const saved = 'Đã lưu nơi này';
  static const savedShown = 'Đã lưu. Bộ lọc được bỏ để bạn thấy nơi này.';
  static const keepFailed =
      'Đã ghim trên bản đồ nhưng chưa lưu được vào máy. Bạn thử lại nhé.';
  static const cloudSaved = 'Đã lưu vào tài khoản';
  static const cloudSaveFailed = 'Không lưu được ghim trên cloud. Hãy thử lại.';
  static const cloudPartlySaved =
      'Đã tạo ghim nhưng chưa lưu được ghi chú. Vui lòng kiểm tra lại.';
  static const cloudLoadFailed =
      'Không tải được địa điểm đã lưu từ tài khoản. Thử mở lại bản đồ.';
  static const cloudShareUnsupported =
      'Chia sẻ địa điểm chưa được hỗ trợ trên cloud.';
  static const cloudInboxUnsupported =
      'Hòm thư mẫu chưa kết nối với tài khoản.';

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
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

  /// The filters: what places are for, and the Nudaeng felt there. Null:
  /// any.
  String? _category;
  PlaceMood? _mood;
  List<ExplorePlace> _places = [];
  ExplorePlace? _selected;
  LatLng? _draftPin;
  ExploreHighlight? _highlight;
  bool _highlightCard = false;
  LatLng _currentCameraPosition = const LatLng(10.8231, 106.6297);
  double _zoom = 12;

  /// The saved place chosen (its pin larger, named, its card highlighted).
  String? _selectedSavedId;
  Symbol? _selectedSymbol;

  /// The wave frame the chosen pin shows while Nudaeng waves; a redraw
  /// meanwhile (the map settling, a filter) carries on from it.
  String? _waveFrame;
  var _waveRun = 0;
  final _cardKeys = <String, GlobalKey>{};

  /// Groups drawn as one numbered pin, by their symbol id.
  var _clusters = <String, List<SavedPlace>>{};
  final _clusterImages = <String>{};
  double _clusteredAt = 12;

  /// "Những nơi của bạn": its controller, height (a part of the room) and
  /// the room's height.
  final _sheet = DraggableScrollableController();
  double? _sheetSize;
  double _room = 700;
  static const _collapsedHeight = 84.0;
  static const _half = PlacesSheet.half;

  /// Choosing where a new place goes: the pin at the middle of the map.
  var _picking = false;
  var _moving = false;

  var _locating = false;
  var _located = false;
  final List<SavedPlace> _savedPlaces = [
    const SavedPlace(
      id: 'saved:0',
      name: 'Góc đọc sách ven sông',
      category: 'Study',
      mood: PlaceMood.peaceful,
      note: 'Gió nhẹ và đủ yên để đọc vài trang sách.',
      latitude: 10.7792,
      longitude: 106.6974,
    ),
    const SavedPlace(
      id: 'saved:1',
      name: 'Con đường nhỏ đầy nắng',
      category: 'Chill',
      mood: PlaceMood.reflective,
      note: 'Một đoạn đường để đi chậm và hít thở.',
      latitude: 10.7709,
      longitude: 106.7048,
    ),
    const SavedPlace(
      id: 'saved:2',
      name: 'Quán bánh cuối tuần',
      category: 'Food',
      mood: PlaceMood.happy,
      note: 'Một nơi để gặp bạn bè và cười thật nhiều.',
      latitude: 10.7757,
      longitude: 106.6929,
    ),
  ];
  int _nextSavedPlaceId = 3;

  /// The signed-in user's private places ([SavedPlacesScope]); then the
  /// samples and the device store are not used for them.
  RemoteSavedPlacesRepository? _cloudPlaces;
  bool _storeReady = false;
  bool _signedIn = false;

  /// Friends' 24-hour posts shared with the user (signed in), asked again
  /// every minute while Explore is open.
  RemoteFriendsSharing? _friendsSharing;
  List<FriendPost> _friendPosts = const [];
  Timer? _friendPostsTimer;

  /// The friend's post whose card is open, and photos already asked for.
  FriendPost? _openPost;
  final _postPhotos = <String, Future<Uint8List>>{};
  PlaceLookup? _placeLookup;
  late SavedPlacesStore _effectiveLocalStore;
  bool _hasUnreadMail = true;
  bool _showAnonymous = false;

  /// The pin hint is said until the first pin.
  bool _pinnedOnce = false;

  /// Mock community posts deliberately contain no name, account or identifier.
  final List<CommunityStop> _anonymousPlaces = [
    const CommunityStop(
      id: 'hope-1',
      latitude: 10.7733,
      longitude: 106.6983,
      message:
          'Một người lạ đã từng rất áp lực ở đây, nhưng mọi chuyện rồi sẽ ổn!',
    ),
    const CommunityStop(
      id: 'hope-2',
      latitude: 10.7816,
      longitude: 106.7040,
      message: 'Bạn không cần phải mạnh mẽ mọi lúc. Hãy nghỉ một chút nhé.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _highlight = widget.highlight;
    _highlightCard = _highlight != null;
    // Use Android TextureView so Flutter overlays and tab clipping compose
    // correctly; the default SurfaceView uses a separate virtual display.
    MapLibreMap.useHybridComposition = true;
  }

  /// What was saved before (in an earlier run); the samples until then.
  Future<void> _loadKept() async {
    try {
      final places = await _effectiveLocalStore.places();
      final stops = _signedIn
          ? null // No mock community messages/inbox for authenticated users.
          : await _effectiveLocalStore.stops();
      if (!mounted) return;
      setState(() {
        // Account places come from the cloud, never from the device.
        if (places != null && _cloudPlaces == null) {
          _savedPlaces
            ..clear()
            ..addAll(places);
        }
        if (stops != null) {
          _anonymousPlaces
            ..clear()
            ..addAll(stops);
        }
      });
      _syncMarkers();
    } catch (_) {
      // Unreadable: the samples stay; nothing is overwritten until a save.
    }
  }

  /// Keeps the places and stops; false when that failed.
  Future<bool> _keep() async {
    try {
      if (_cloudPlaces == null) {
        await _effectiveLocalStore.keepPlaces(_savedPlaces);
      }
      if (!_signedIn) await _effectiveLocalStore.keepStops(_anonymousPlaces);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lookup = PlaceLookupScope.maybeOf(context);
    final searchChanged = !_storeReady || !identical(lookup, _placeLookup);
    _placeLookup = lookup;
    // Choose the correct account key BEFORE reading saved pins. The old
    // unscoped demo key must not leak between signed-in accounts.
    if (!_storeReady) {
      _storeReady = true;
      final id = AuthScope.maybeOf(context)?.currentUserId;
      _signedIn = id != null;
      // A guest's pins live under the guest's own key, which leaving guest
      // mode discards; never the old shared key, which outlived every
      // guest and showed one guest's pins to the next.
      final owner = id ??
          (GuestScope.maybeOf(context) != null ? GuestModeStore.userId : null);
      _effectiveLocalStore = owner == null
          ? widget.savedPlacesStore
          : LocalSavedPlacesStore(userId: owner);
      if (_signedIn) {
        _savedPlaces.clear();
        _anonymousPlaces.clear();
        _hasUnreadMail = false;
        _showAnonymous = false;
      }
      _loadKept();
    }
    if (searchChanged) _search();
    final sharing = AlbumScope.memorySharingOf(context);
    if (sharing is RemoteFriendsSharing && !identical(sharing, _friendsSharing)) {
      _friendsSharing = sharing;
      _friendPostsTimer?.cancel();
      _friendPostsTimer = Timer.periodic(
          const Duration(minutes: 1), (_) => _loadFriendPosts());
      _loadFriendPosts();
    }
    final cloud = SavedPlacesScope.maybeOf(context);
    if (cloud == null || identical(cloud, _cloudPlaces)) return;
    _cloudPlaces = cloud;
    // Authenticated cloud screens never display the three local demo pins
    // or the sample mail.
    setState(() {
      _savedPlaces.clear();
      _hasUnreadMail = false;
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
        _savedPlaces
          ..clear()
          ..addAll(items);
      });
      await _syncMarkers();
    } catch (_) {
      if (!mounted || !identical(cloud, _cloudPlaces)) return;
      _toast(ExploreScreen.cloudLoadFailed);
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

  Future<void> _loadFriendPosts() async {
    final sharing = _friendsSharing;
    if (sharing == null) return;
    try {
      final posts = await sharing.received();
      if (!mounted) return;
      _friendPosts = posts;
      _syncMarkers();
    } catch (_) {
      // Offline: the pins already shown stay until the next try.
    }
  }

  /// A friend's post: its card, the pin brought into view.
  /// A friend's post: its card with the photo, the pin brought into view.
  void _showFriendPost(FriendPost post) {
    setState(() {
      _openPost = post;
      if (post.hasPhoto) {
        _postPhotos.putIfAbsent(post.id, () => _friendsSharing!.photo(post.id));
      }
      _highlightCard = false;
      _selected = null;
      _selectedSavedId = null;
      _draftPin = null;
    });
    _syncMarkers();
    final map = _map;
    if (map == null || !_styleReady) return;
    final camera = CameraUpdate.newLatLngZoom(
        LatLng(post.latitude, post.longitude), 15);
    (MediaQuery.disableAnimationsOf(context)
            ? map.moveCamera(camera)
            : map.animateCamera(camera))
        .catchError((Object _) => false);
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
    _friendPostsTimer?.cancel();
    _debounce?.cancel();
    _loadTimeout?.cancel();
    _searchController.dispose();
    _sheet.dispose();
    // MapLibreMap owns and disposes its controller.
    _map = null;
    super.dispose();
  }

  Future<void> _search() async {
    final version = ++_searchVersion;
    try {
      final lookup = _placeLookup;
      final List<ExplorePlace> results;
      if (lookup != null) {
        final candidates = await lookup.search(_query);
        results = [
          for (final candidate in candidates)
            ExplorePlace(
              candidate.id ?? '${candidate.latitude},${candidate.longitude}',
              candidate.name ?? candidate.coordinates,
              'Địa điểm',
              candidate.latitude,
              candidate.longitude,
              sample: candidate.sample,
            ),
        ];
      } else {
        // Signed-in sessions never substitute sample provider results.
        results = _signedIn
            ? const []
            : await widget.placesRepository.search(_query, null);
      }
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

  void _filter({String? category, PlaceMood? mood}) {
    setState(() {
      _category = category;
      _mood = mood;
      // A chosen place the filters hide is no longer chosen.
      if (!_visibleSavedPlaces.any((p) => p.id == _selectedSavedId)) {
        _selectedSavedId = null;
      }
    });
    _syncMarkers(fade: true);
    // Filtered: the map goes to what is left, wherever it is.
    if (category != null || mood != null) {
      _frame([
        for (final place in _visibleSavedPlaces)
          LatLng(place.latitude, place.longitude)
      ]);
    }
  }

  /// Moves the map to show [points], zoomed in: one up close, several all
  /// in view clear of the overlays. Nothing to show: the map stays.
  Future<void> _frame(List<LatLng> points) async {
    final map = _map;
    if (map == null || points.isEmpty) return;
    final CameraUpdate camera;
    if (points.length == 1) {
      camera = CameraUpdate.newLatLngZoom(points.single, 16);
    } else {
      var south = points.first.latitude, north = south;
      var west = points.first.longitude, east = west;
      for (final point in points.skip(1)) {
        south = math.min(south, point.latitude);
        north = math.max(north, point.latitude);
        west = math.min(west, point.longitude);
        east = math.max(east, point.longitude);
      }
      camera = CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest: LatLng(south, west), northeast: LatLng(north, east)),
          // Clear of the search and chips above, the sheet and buttons below.
          left: 48,
          top: 200,
          right: 48,
          bottom: _sheetHeight + 90);
    }
    try {
      MediaQuery.disableAnimationsOf(context)
          ? await map.moveCamera(camera)
          : await map.animateCamera(camera);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _pickMood() async {
    final picked = await showMoodFilterSheet(context, _mood);
    if (!mounted || picked == null) return;
    _filter(category: _category, mood: picked.$1);
  }

  void _toggleAnonymous(bool value) {
    setState(() => _showAnonymous = value);
    _syncMarkers();
  }

  Future<void> _showAnonymousMessage(CommunityStop place) => showDialog<void>(
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
                  Text(place.message,
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

  List<SavedPlace> get _visibleSavedPlaces => [
        for (final place in _savedPlaces)
          if ((_category == null || place.category == _category) &&
              (_mood == null || place.mood == _mood))
            place,
      ];

  void _created(MapLibreMapController controller) {
    _map = controller;
    _currentCameraPosition =
        controller.cameraPosition?.target ?? _currentCameraPosition;
    controller.onSymbolTapped.add((symbol) {
      if (!mounted || _map != controller) return;
      final id = symbol.data?['id'];
      if (id is String && id.startsWith('anonymous:')) {
        CommunityStop? anonymous;
        for (final place in _anonymousPlaces) {
          if ('anonymous:${place.id}' == id) {
            anonymous = place;
            break;
          }
        }
        if (anonymous != null) _showAnonymousMessage(anonymous);
        return;
      }
      if (id is String && id.startsWith('saved:')) {
        for (final place in _savedPlaces) {
          if (place.id == id) {
            _selectSaved(place);
            return;
          }
        }
        return;
      }
      if (id is String && id.startsWith('cluster:')) {
        // A group: the map zooms in until they come apart.
        _frame([
          for (final place in _clusters[id] ?? const <SavedPlace>[])
            LatLng(place.latitude, place.longitude)
        ]);
        return;
      }
      for (final place in _places) {
        if (place.id == id) {
          setState(() => _selected = place);
          return;
        }
      }
      if (id is String && id.startsWith('friend:')) {
        for (final post in _friendPosts) {
          if ('friend:${post.id}' == id) {
            _showFriendPost(post);
            return;
          }
        }
        return;
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
      // Every pin: Nudaeng in the pin frame, its tip on the place. A saved
      // place shows the Nudaeng felt there; others, the neutral one.
      final markers = <String, Uint8List>{
        'nudaeng': await createPinMarker(PinArt.neutral, crop: PinArt.waveCrop),
        for (final mood in PlaceMood.values)
          mood.marker: await createPinMarker(mood.asset),
        // The blink-and-wave frames, played on the chosen pin.
        for (final (i, frame) in PinArt.waveFrames.indexed)
          'wave-${i + 1}': await createPinMarker(frame, crop: PinArt.waveCrop),
      };
      markers['drop'] = await createDropMarker();
      markers['ring'] = await createRingMarker();
      markers['anonymous'] = await createNudaengMarker(
        'assets/images/loading.gif',
        const Color(0xFF6FBFB5),
      );
      if (!mounted || _map != map) return;
      // Pins and the chosen one's name always show, over street names.
      await map.setSymbolIconAllowOverlap(true);
      await map.setSymbolIconIgnorePlacement(true);
      await map.setSymbolTextAllowOverlap(true);
      await map.setSymbolTextIgnorePlacement(true);
      if (!mounted || _map != map) return;
      _clusterImages.clear();
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
  Future<void> _syncMarkers({bool fade = false}) {
    final map = _map;
    if (!_styleReady || map == null) return Future.value();
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Serialize annotation updates so quick searches/taps cannot duplicate pins.
    _markerWork = _markerWork.then((_) async {
      if (!mounted || _map != map || !_styleReady) return;
      final places = List<ExplorePlace>.of(_places);
      final savedPlaces = List<SavedPlace>.of(_visibleSavedPlaces);
      final anonymousPlaces = _showAnonymous
          ? List<CommunityStop>.of(_anonymousPlaces)
          : const <CommunityStop>[];
      final draft = _draftPin;
      final highlight = _activeHighlight;
      final now = DateTime.now();
      final friendPosts = [
        for (final post in _friendPosts)
          if (post.isActive(now)) post
      ];
      final selectedId = _selectedSavedId;
      final zoom = _zoom;
      final clusters = clusterPlaces(savedPlaces, zoom, keep: selectedId);
      await map.clearSymbols();
      _selectedSymbol = null;
      _clusteredAt = zoom;
      final shown = <Symbol>[];
      final groups = <String, List<SavedPlace>>{};
      if (!mounted || _map != map) return;
      for (final place in places) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: 'nudaeng',
              iconSize: PinArt.size,
              iconAnchor: 'bottom',
            ),
            {'id': place.id});
        if (!mounted || _map != map) return;
      }
      for (final (index, cluster) in clusters.indexed) {
        if (cluster.places.length > 1) {
          final count = cluster.places.length;
          final image = 'cluster-${math.min(count, 100)}';
          if (_clusterImages.add(image)) {
            await map.addImage(image, await createClusterMarker(count));
          }
          final id = 'cluster:$index';
          groups[id] = cluster.places;
          shown.add(await map.addSymbol(
              SymbolOptions(
                geometry: cluster.centre,
                iconImage: image,
                iconSize: .5,
                iconAnchor: 'center',
                iconOpacity: fade && !reduced ? 0 : 1,
              ),
              {'id': id}));
          if (!mounted || _map != map) return;
          continue;
        }
        final place = cluster.places.single;
        final selected = place.id == selectedId;
        final symbol = await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: selected && _waveFrame != null
                  ? _waveFrame
                  : place.mood?.marker ?? 'nudaeng',
              // Anchored at the tip: growing never moves it off its place.
              iconSize: selected ? PinArt.chosenSize : PinArt.size,
              iconAnchor: 'bottom',
              iconOpacity: fade && !reduced ? 0 : 1,
              zIndex: selected ? 2 : 1,
              // The chosen one is named under its pin.
              textField: selected ? place.name : null,
              fontNames: const ['Noto Sans Bold'],
              textSize: 13,
              textAnchor: 'top',
              textOffset: const Offset(0, .3),
              textColor: '#1F201C',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.6,
            ),
            {'id': place.id});
        shown.add(symbol);
        if (selected) _selectedSymbol = symbol;
        if (!mounted || _map != map) return;
      }
      _clusters = groups;
      for (final place in anonymousPlaces) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(place.latitude, place.longitude),
              iconImage: 'anonymous',
              iconSize: .5,
              iconAnchor: 'bottom',
            ),
            {'id': 'anonymous:${place.id}'});
        if (!mounted || _map != map) return;
      }
      for (final post in friendPosts) {
        await map.addSymbol(
            SymbolOptions(
              geometry: LatLng(post.latitude, post.longitude),
              iconImage: 'nudaeng',
              iconSize: PinArt.size,
              iconAnchor: 'bottom',
              zIndex: 2,
              // Whose post it is, under the pin.
              textField: post.senderName,
              fontNames: const ['Noto Sans Bold'],
              textSize: 12,
              textAnchor: 'top',
              textOffset: const Offset(0, .3),
              textColor: '#2E6E78',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.6,
            ),
            {'id': 'friend:${post.id}'});
        if (!mounted || _map != map) return;
      }
      if (draft != null) {
        await map.addSymbol(
            SymbolOptions(
                geometry: draft,
                iconImage: 'drop',
                iconSize: .5,
                iconAnchor: 'bottom'),
            {'id': 'draft'});
      }
      if (highlight != null) {
        await map.addSymbol(
            SymbolOptions(
                geometry: LatLng(highlight.latitude, highlight.longitude),
                iconImage: 'nudaeng',
                iconSize: PinArt.chosenSize,
                iconAnchor: 'bottom'),
            {'id': 'highlight'});
      }
      // Filtered: the pins come in over 180 ms rather than at once.
      if (fade && !reduced) {
        for (final opacity in [.35, .7, 1.0]) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          if (!mounted || _map != map) return;
          for (final symbol in shown) {
            await map.updateSymbol(symbol, SymbolOptions(iconOpacity: opacity));
          }
        }
      }
    }).catchError((Object error) {
      if (mounted && _map == map) setState(() => _loadFailed = true);
    });
    return _markerWork;
  }

  void _pick(math.Point<double> point, LatLng coordinate) {
    if (_picking) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draftPin = coordinate;
      _selected = null;
      _selectedSavedId = null;
      _highlightCard = false;
      _pinnedOnce = true;
    });
    _syncMarkers().then((_) => _ripple(coordinate));
  }

  /// A soft ring spreads once around a new pin.
  Future<void> _ripple(LatLng at) async {
    final map = _map;
    if (map == null ||
        !_styleReady ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    try {
      final ring = await map.addSymbol(SymbolOptions(
          geometry: at,
          iconImage: 'ring',
          iconAnchor: 'center',
          iconSize: .15,
          iconOpacity: .9));
      for (var step = 1; step <= 6; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 55));
        if (!mounted || _map != map) return;
        await map.updateSymbol(
            ring,
            SymbolOptions(
                iconSize: .15 + .12 * step, iconOpacity: .9 - .15 * step));
      }
      await map.removeSymbol(ring);
    } catch (_) {
      // Cleared by a newer redraw meanwhile: nothing to finish.
    }
  }

  /// The chosen pin's Nudaeng blinks and waves once (about 1.8 s), then is
  /// its own again. Only the art inside changes: the frame and its tip stay
  /// on the place. Reduced motion: nothing.
  Future<void> _wave(SavedPlace place) async {
    final map = _map;
    if (map == null || MediaQuery.disableAnimationsOf(context)) return;
    // A newer wave (chosen again) takes over from this one.
    final run = ++_waveRun;
    // Shows [image] on the chosen pin, whichever symbol it is now (a redraw
    // makes a new one). False once something else is chosen.
    Future<bool> show(String? image) async {
      if (!mounted ||
          _map != map ||
          _selectedSavedId != place.id ||
          run != _waveRun) {
        return false;
      }
      _waveFrame = image;
      final symbol = _selectedSymbol;
      if (symbol == null) return true;
      try {
        await map.updateSymbol(symbol,
            SymbolOptions(iconImage: image ?? place.mood?.marker ?? 'nudaeng'));
      } catch (_) {
        // Redrawn meanwhile: the redraw shows [_waveFrame] itself.
      }
      return true;
    }

    for (final (frame, ms) in PinArt.wave) {
      if (!await show('wave-$frame')) break;
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
    if (run != _waveRun) return;
    _waveFrame = null;
    await show(null);
  }

  double get _sheetHeight => (_sheetSize ?? _collapsedHeight / _room) * _room;

  /// A saved place chosen from its pin, its card or a search: its pin
  /// grows and its Nudaeng waves, the sheet rises to show its card, and the map moves
  /// it into the part left in view above the sheet.
  Future<void> _selectSaved(SavedPlace place) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedSavedId = place.id;
      _selected = null;
      _draftPin = null;
      _highlightCard = false;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    // After this frame: the sheet may only now be back (it waits while
    // searching). It goes to half, then the card comes into view.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_sheet.isAttached) return;
      // Half open: the card below, the place in view on the map above.
      if ((_sheet.size - _half).abs() > .01) {
        reduced
            ? _sheet.jumpTo(_half)
            : await _sheet.animateTo(_half,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic);
      }
      // Its card is first: the list goes back to the top, under the title.
      final card = _cardKeys[place.id]?.currentContext;
      final list =
          card != null && card.mounted ? Scrollable.maybeOf(card) : null;
      if (mounted && list != null && list.position.pixels > 0) {
        reduced
            ? list.position.jumpTo(0)
            : await list.position.animateTo(0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut);
      }
    });
    final at = LatLng(place.latitude, place.longitude);
    final map = _map;
    if (map != null) {
      // A little around the place, fitted above the half-open sheet.
      const span = .0025;
      final camera = CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest: LatLng(at.latitude - span, at.longitude - span),
              northeast: LatLng(at.latitude + span, at.longitude + span)),
          left: 48,
          top: 200,
          right: 48,
          bottom: _half * _room + 24);
      try {
        reduced
            ? await map.moveCamera(camera)
            : await map.animateCamera(camera);
      } catch (_) {
        if (mounted) setState(() => _loadFailed = true);
      }
    }
    await _syncMarkers();
    if (mounted) _wave(place);
  }

  /// "+ Lưu một nơi": the pin at the middle of the map; the user moves the
  /// map under it. From a dropped pin, the map starts there.
  void _startPick() {
    FocusManager.instance.primaryFocus?.unfocus();
    final from = _draftPin;
    setState(() {
      _picking = true;
      _selected = null;
      _selectedSavedId = null;
      _highlightCard = false;
    });
    if (from != null) _map?.animateCamera(CameraUpdate.newLatLng(from));
    _syncMarkers();
  }

  Future<void> _confirmPick() async {
    final target = _map?.cameraPosition?.target ?? _currentCameraPosition;
    setState(() {
      _picking = false;
      _draftPin = null;
    });
    await _addPlaceAt(target, pinned: true);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final fix = await widget.location.current();
    if (!mounted) return;
    setState(() => _locating = false);
    switch (fix) {
      case DeviceFixFound(:final latitude, :final longitude):
        setState(() => _located = true);
        final camera =
            CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15);
        try {
          MediaQuery.disableAnimationsOf(context)
              ? await _map?.moveCamera(camera)
              : await _map?.animateCamera(camera);
        } catch (_) {
          if (mounted) setState(() => _loadFailed = true);
        }
      case DeviceFixDenied():
        _toast(ExploreScreen.locationDenied);
      case DeviceFixFailed():
        _toast(ExploreScreen.locationFailed);
    }
  }

  void _cameraIdle() {
    if (_moving) setState(() => _moving = false);
    // Zoomed: groups come apart or join.
    if ((_zoom - _clusteredAt).abs() > .25) _syncMarkers();
  }

  /// The form for a place at [at] ([name] to start from); saved there.
  Future<void> _addPlaceAt(LatLng at,
      {String? name, bool pinned = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await showAddPlaceSheet(context, pinned: pinned, name: name);
    if (!mounted || draft == null) return;
    await _saveNewPlace(draft, at);
  }

  /// Stores a private place or a community pin where the user pinned, or
  /// at the map centre without a pin, keeps it on the device, and shows it:
  /// filters that would hide it are dropped and the map goes to it.
  ///
  /// MapLibre renders annotations imperatively, so [_syncMarkers] is the
  /// equivalent of updating a GoogleMap `Set<Marker>` after `setState`.
  Future<void> _saveNewPlace(PlaceDraft draft, LatLng target) async {
    final cloud = _cloudPlaces;
    if (cloud != null && !draft.isAnonymousShare) {
      await _saveCloudPlace(cloud, draft, target);
      return;
    }
    try {
      final markerIdVal = 'marker_${DateTime.now().millisecondsSinceEpoch}';
      var unfiltered = false;
      SavedPlace? added;
      setState(() {
        if (draft.isAnonymousShare) {
          _anonymousPlaces.add(CommunityStop(
            id: markerIdVal,
            latitude: target.latitude,
            longitude: target.longitude,
            message: draft.note.isEmpty
                ? 'Một người bạn ẩn danh để lại nơi này để bạn có thể dừng lại và thở thật sâu.'
                : draft.note,
          ));
          // Make a newly shared community pin visible immediately.
          _showAnonymous = true;
        } else {
          _savedPlaces.add(added = SavedPlace(
            id: 'saved:$markerIdVal',
            name: draft.name,
            category: draft.category,
            mood: draft.mood,
            note: draft.note,
            latitude: target.latitude,
            longitude: target.longitude,
          ));
          // A filter that would hide it at once is dropped.
          if ((_category != null && _category != draft.category) ||
              (_mood != null && _mood != draft.mood)) {
            _category = null;
            _mood = null;
            unfiltered = true;
          }
        }
        _draftPin = null;
        _selected = null;
      });
      final kept = await _keep();
      if (!mounted) return;
      // The new pin, chosen: its Nudaeng, its card, in view.
      final place = added;
      if (place != null) {
        await _selectSaved(place);
      } else {
        await _syncMarkers();
        _frame([target]);
      }
      if (!mounted) return;
      _toast(!kept
          ? ExploreScreen.keepFailed
          : draft.isAnonymousShare
              ? 'Đã thả trạm ẩn danh'
              : unfiltered
                  ? ExploreScreen.savedShown
                  : ExploreScreen.saved);
    } catch (_) {
      if (mounted) {
        _toast('Chưa lấy được vị trí bản đồ. Bạn thử lại nhé.');
      }
    }
  }

  /// A private place saved to the signed-in account, then shown as a local
  /// one would be.
  Future<void> _saveCloudPlace(RemoteSavedPlacesRepository cloud,
      PlaceDraft draft, LatLng target) async {
    final SavedPlace place;
    try {
      place = await cloud.create(draft,
          latitude: target.latitude, longitude: target.longitude);
    } on PartiallySavedPlace {
      // The pin was created; reloading prevents a retry from duplicating it.
      await _reloadSavedPlaces();
      if (mounted) _toast(ExploreScreen.cloudPartlySaved);
      return;
    } catch (_) {
      if (mounted) _toast(ExploreScreen.cloudSaveFailed);
      return;
    }
    if (!mounted || !identical(cloud, _cloudPlaces)) return;
    var unfiltered = false;
    setState(() {
      _savedPlaces.add(place);
      // A filter that would hide it at once is dropped.
      if ((_category != null && _category != place.category) ||
          (_mood != null && _mood != place.mood)) {
        _category = null;
        _mood = null;
        unfiltered = true;
      }
      _draftPin = null;
      _selected = null;
    });
    await _selectSaved(place);
    if (!mounted) return;
    _toast(unfiltered ? ExploreScreen.savedShown : ExploreScreen.cloudSaved);
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
    // The friends list here is a sample: never pretend to send a real
    // account's place.
    if (_cloudPlaces != null) {
      _toast(ExploreScreen.cloudShareUnsupported);
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
      _toast(ExploreScreen.cloudInboxUnsupported);
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
        note: 'Một nơi Tường Vy muốn gửi bạn ghé qua.',
        latitude: target.latitude,
        longitude: target.longitude,
      ));
    });
    await _keep();
    if (!mounted) return;
    _syncMarkers();
    _toast('Đã lưu vào bản đồ của bạn');
  }

  /// Saved places whose name or note has the query, accents or not.
  List<SavedPlace> get _savedMatches {
    final query = _fold(_query.trim());
    if (query.isEmpty) return const [];
    return [
      for (final place in _savedPlaces)
        if (_fold(place.name).contains(query) ||
            _fold(place.note).contains(query))
          place,
    ];
  }

  /// Lower case without Vietnamese accents: "cach mang" finds "Cách Mạng".
  static String _fold(String text) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
        'ùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooo'
        'uuuuuuuuuuuyyyyyd';
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final at = from.indexOf(char);
      buffer.write(at < 0 ? char : to[at]);
    }
    return buffer.toString();
  }

  /// Search submitted: the map shows every result, the user's and the
  /// samples, zoomed in on them.
  void _frameResults() => _frame([
        for (final place in _savedMatches)
          LatLng(place.latitude, place.longitude),
        for (final place in _places) LatLng(place.latitude, place.longitude),
      ]);

  /// A saved place picked from the results: the map goes to it, close up,
  /// and its sheet opens.
  Future<void> _showSaved(SavedPlace place) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _selected = null;
      _highlightCard = false;
    });
    _search();
    await _selectSaved(place);
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
    await _frame([LatLng(place.latitude, place.longitude)]);
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
    final filters = [
      if (_category case final category?) categoryName(category),
      if (_mood case final mood?) mood.label,
    ];
    if (filters.isNotEmpty) {
      return 'Đang xem: ${filters.join(' · ')} · '
          '${_visibleSavedPlaces.length} địa điểm';
    }
    return _pinnedOnce ? null : ExploreScreen.pinHint;
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _activeHighlight;
    final openPost = _openPost != null &&
            _openPost!.isActive(DateTime.now()) &&
            _selected == null &&
            _draftPin == null
        ? _openPost
        : null;
    final showHighlight = _selected == null &&
        _draftPin == null &&
        openPost == null &&
        _highlightCard &&
        highlight != null;
    final status = _status;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, box) {
        _room = box.maxHeight;
        final collapsed = (_collapsedHeight / box.maxHeight).clamp(.06, .3);
        final sheetHeight = (_sheetSize ?? collapsed) * box.maxHeight;
        // Pulled well up, the sheet is the focus: the map's buttons step aside.
        final sheetOpen = (_sheetSize ?? collapsed) > _half + .05;
        final visible = _visibleSavedPlaces;
        final searching = _query.trim().isNotEmpty || _searchError != null;
        for (final place in visible) {
          _cardKeys.putIfAbsent(place.id, GlobalKey.new);
        }
        return Stack(fit: StackFit.expand, children: [
          MapLibreMap(
            key: ValueKey(_generation),
            styleString: ExploreMapStyle.day,
            initialCameraPosition: const CameraPosition(
                target: LatLng(10.8231, 106.6297), zoom: 12),
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            trackCameraPosition: true,
            // Pinch and double-tap zoom; the buttons do the same.
            zoomGesturesEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(4, 19),
            myLocationEnabled: _located,
            onCameraMove: (position) {
              _currentCameraPosition = position.target;
              _zoom = position.zoom;
              if (_picking && !_moving) setState(() => _moving = true);
            },
            onCameraIdle: _cameraIdle,
            onMapClick: _pick,
            onMapLongClick: _pick,
            compassViewMargins: const math.Point(16, 210),
            attributionButtonPosition: AttributionButtonPosition.topRight,
            attributionButtonMargins: const math.Point(12, 210),
          ),
          if (!_picking)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 12, AppSpacing.md, 0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _buildSearch()),
                    const SizedBox(width: 12),
                    _buildFriends(),
                    const SizedBox(width: 8),
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
                                _category != null || _mood != null
                                    ? Icons.filter_list_rounded
                                    : Icons.touch_app_outlined,
                                size: 16,
                                color: AppColors.primaryAction),
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
          // Searching: the results are in front; the sheet waits.
          if (!_picking && !searching) ...[
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: sheetHeight + 12,
              child: AnimatedOpacity(
                opacity: sheetOpen ? 0 : 1,
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: sheetOpen,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Align(
                        alignment: Alignment.centerRight, child: _buildZoom()),
                    const SizedBox(height: 12),
                    if (openPost != null) ...[
                      FriendPostCard(
                        key: ValueKey('friend-post-${openPost.id}'),
                        post: openPost,
                        photo: _postPhotos[openPost.id],
                        onClose: () => setState(() => _openPost = null),
                      ),
                      const SizedBox(height: 12),
                    ],
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
                      _buildPinnedCard(),
                      const SizedBox(height: 12),
                    ],
                    _buildMapButtons(),
                  ]),
                ),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() => _sheetSize = notification.extent);
                return false;
              },
              child: PlacesSheet(
                controller: _sheet,
                collapsed: collapsed,
                // The chosen place's card first, so it is always in view.
                places: [
                  ...visible.where((p) => p.id == _selectedSavedId),
                  ...visible.where((p) => p.id != _selectedSavedId),
                ],
                savedCount: _savedPlaces.length,
                selectedId: _selectedSavedId,
                cardKeys: _cardKeys,
                community: _showAnonymous,
                onCommunity: _toggleAnonymous,
                onSelect: _selectSaved,
                onDetails: (place) => showSavedPlaceSheet(context, place,
                    onShare: () => _showShareBottomSheet(place)),
                onShare: _showShareBottomSheet,
                onAdd: _startPick,
                onClearFilters: () => _filter(),
              ),
            ),
          ],
          if (_picking)
            PlacePickOverlay(
              moving: _moving,
              onCancel: () => setState(() => _picking = false),
              onConfirm: _confirmPick,
            ),
        ]);
      }),
    );
  }

  /// The dropped pin, or a search result shown on the map: what it is, a
  /// way to save it there, and a way to close it.
  Widget _buildPinnedCard() {
    final place = _selected;
    final pin = _draftPin;
    return MapInfoCard(
      icon: place != null ? Icons.place_outlined : Icons.push_pin_outlined,
      title: place?.label ?? ExploreScreen.draftTitle,
      subtitle: place != null
          ? '${place.category} · ${ExploreScreen.sample}'
          : ExploreScreen.draftDetail,
      closeTooltip: place != null
          ? ExploreScreen.closePlaceTooltip
          : ExploreScreen.removeDraftTooltip,
      onClose: () {
        setState(() {
          if (_selected == null) _draftPin = null;
          _selected = null;
        });
        _syncMarkers();
      },
      action: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => place != null
              ? _addPlaceAt(LatLng(place.latitude, place.longitude),
                  name: place.label, pinned: true)
              : pin != null
                  ? _addPlaceAt(pin, pinned: true)
                  : null,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text(ExploreScreen.saveHereLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryAction,
            minimumSize: const Size(48, 40),
            shape: const StadiumBorder(),
            textStyle: AppText.label.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildZoom() => MapZoomButtons(
        onZoomIn: () => _zoomBy(CameraUpdate.zoomIn()),
        onZoomOut: () => _zoomBy(CameraUpdate.zoomOut()),
      );

  Future<void> _zoomBy(CameraUpdate step) async {
    final map = _map;
    if (map == null) return;
    try {
      MediaQuery.disableAnimationsOf(context)
          ? await map.moveCamera(step)
          : await map.animateCamera(step,
              duration: const Duration(milliseconds: 250));
    } catch (_) {
      // The map is not ready yet: nothing to zoom.
    }
  }

  /// "Vị trí của tôi" and "+ Lưu một nơi", on the right above the sheet; on
  /// a narrow screen the save button keeps only its icon.
  Widget _buildMapButtons() => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 340;
        return Row(children: [
          const Spacer(),
          MapCircleButton(
            tooltip: ExploreScreen.locateTooltip,
            busy: _locating,
            onPressed: _locate,
            color: AppColors.primaryAction,
            icon: _located
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: ExploreScreen.saveLabel,
            child: DecoratedBox(
              decoration: const ShapeDecoration(
                  shape: StadiumBorder(), shadows: mapOverlayShadow),
              child: FilledButton(
                onPressed: _startPick,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 20),
                  shape: const StadiumBorder(),
                  textStyle: AppText.label,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 22),
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

  Widget _buildSearch() => MapFloatingSurface(
        child: TextField(
          controller: _searchController,
          onChanged: _queryChanged,
          onSubmitted: (_) => _frameResults(),
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

  /// Friends on the app ("Bạn bè"): requests are answered on that screen.
  Widget _buildFriends() => MapFloatingSurface(
        child: SizedBox.square(
          dimension: 52,
          child: IconButton(
            tooltip: ExploreScreen.friendsTooltip,
            onPressed: () => openFriendSpace(context),
            icon: const Icon(Icons.group_outlined, color: AppColors.textPrimary),
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

  /// "Tất cả", the Nudaeng felt there (a chip that opens the six, early so
  /// it is always in view) and what places are for; the shadow needs a
  /// little room to show.
  Widget _buildMoods() {
    final mood = _mood;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        MapMoodChip(
          label: ExploreScreen.allFilter,
          selected: _category == null && mood == null,
          onTap: () => _filter(),
        ),
        const SizedBox(width: AppSpacing.sm),
        MapMoodChip(
          key: const ValueKey('mood-filter'),
          label: mood?.label ?? ExploreScreen.moodFilter,
          selected: mood != null,
          leading: mood != null
              ? Image.asset(mood.asset, width: 26, height: 26, cacheWidth: 90)
              : const Icon(Icons.sentiment_satisfied_outlined,
                  size: 18, color: AppColors.textSecondary),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textSecondary),
          onTap: _pickMood,
        ),
        for (final (value, label) in placeCategories) ...[
          const SizedBox(width: AppSpacing.sm),
          MapMoodChip(
            label: label,
            selected: _category == value,
            onTap: () => _filter(
                category: _category == value ? null : value, mood: mood),
          ),
        ],
      ]),
    );
  }

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
          if (_places.isEmpty && _savedMatches.isEmpty && _searchError == null)
            const ListTile(
                title: Text(ExploreScreen.noResults,
                    style: AppText.bodySecondary)),
          // The user's own places first.
          for (final place in _savedMatches)
            ListTile(
              leading: SizedBox.square(
                dimension: 36,
                child: place.mood != null
                    ? Image.asset(place.mood!.asset, cacheWidth: 120)
                    : Icon(categoryIcon(place.category),
                        color: AppColors.primaryAction),
              ),
              title: Text(place.name, style: AppText.label),
              subtitle: Text(
                  '${categoryName(place.category)} · ${ExploreScreen.savedResult}',
                  style: AppText.meta),
              onTap: () => _showSaved(place),
            ),
          for (final place in _places)
            ListTile(
              leading: const Icon(Icons.place_outlined,
                  color: AppColors.primaryAction),
              title: Text(place.label, style: AppText.label),
              subtitle: Text(
                  place.sample
                      ? '${place.category} · ${ExploreScreen.sample}'
                      : place.category,
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
}
