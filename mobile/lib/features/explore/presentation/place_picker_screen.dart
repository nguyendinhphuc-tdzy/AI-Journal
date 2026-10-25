import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/place_lookup.dart';

/// E05: choose and confirm a place, for a memory (A06) or a share (A10).
///
/// - The map fills the screen (Explore's MapLibre style); search on a
///   Surface at the top, a pin fixed at the centre, and a Surface panel with
///   the candidate's name, address or coordinates and "Dùng địa điểm này".
///   No Album scene behind, no mascot near the pin or search.
/// - Pick by searching, by dragging the map under the pin, or by tapping a
///   point (the camera moves there). A pin without a name is looked up; a
///   failed lookup says so (it is not "no place") and the coordinates can
///   still be used, labelled as unnamed, or given a name.
/// - "Vị trí của tôi" only when the device can locate; permission is asked
///   only after that tap, and the result still needs "Dùng địa điểm này".
///   Nothing here posts or saves: the place goes back to the caller.
/// - Back returns null (the caller keeps its place). Panel changes 300 ms;
///   reduced motion: none, and the camera is set directly.
class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({
    super.key,
    this.initial,
    this.lookup = const MockPlaceLookup(),
    this.location = const NoDeviceLocation(),
  });

  /// The place already chosen, shown as the candidate.
  final PlaceCandidate? initial;
  final PlaceLookup lookup;
  final DeviceLocation location;

  static const title = 'Chọn địa điểm';
  static const backTooltip = 'Quay lại';
  static const searchHint = 'Tìm địa điểm';
  static const clearTooltip = 'Xóa tìm kiếm';
  static const noResults = 'Không tìm thấy địa điểm nào.';
  static const searchFailed = 'Chưa tìm được. Bạn thử lại nhé.';
  static const retryLabel = 'Thử lại';
  static const sampleLabel = 'Địa điểm mẫu';
  static const nothingYet = 'Chưa chọn địa điểm';
  static const howTo =
      'Kéo bản đồ để đặt ghim ở giữa, chạm vào một điểm, hoặc tìm theo tên.';
  static const unnamed = 'Vị trí chưa có tên';
  static const naming = 'Đang tìm tên địa điểm…';
  static const lookupFailed =
      'Chưa tra được tên cho vị trí này. Bạn vẫn dùng được tọa độ, hoặc tự '
      'đặt tên bên dưới.';
  static const lookupEmpty =
      'Không có tên cho vị trí này. Bạn vẫn dùng được tọa độ, hoặc tự đặt '
      'tên bên dưới.';
  static const nameLabel = 'Tên địa điểm (không bắt buộc)';
  static const nameMax = 60;
  static const myLocation = 'Vị trí của tôi';
  static const locating = 'Đang lấy vị trí của máy…';
  static const locationDenied =
      'Chưa có quyền vị trí. Bạn vẫn chọn được bằng cách tìm hoặc kéo bản đồ.';
  static const locationFailed =
      'Chưa lấy được vị trí của máy. Bạn vẫn chọn được bằng cách tìm hoặc '
      'kéo bản đồ.';
  static const mapFailed =
      'Bản đồ chưa tải được. Bạn vẫn tìm được địa điểm theo tên.';
  static const confirmLabel = 'Dùng địa điểm này';

  static const transition = Duration(milliseconds: 300);
  static const debounce = Duration(milliseconds: 300);

  /// Ho Chi Minh City, as in Explore; never the device's position.
  static const start = LatLng(10.8231, 106.6297);

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

enum _Naming { idle, looking, failed, empty }

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  static const _style = 'https://tiles.openfreemap.org/styles/liberty';

  MapLibreMapController? _map;
  Timer? _loadTimeout;
  var _generation = 0;
  var _mapFailed = false;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  var _searchVersion = 0;
  List<PlaceCandidate>? _results;
  var _searchError = false;

  late PlaceCandidate? _candidate = widget.initial;
  var _naming = _Naming.idle;
  var _nameRequest = 0;
  final _name = TextEditingController();

  var _locating = false;
  String? _locationError;

  /// A finger is on the map: the camera stopping afterwards moves the pin.
  var _gesture = false;
  LatLng? _target;

  @override
  void initState() {
    super.initState();
    // As in Explore: overlays and clipping compose with TextureView.
    MapLibreMap.useHybridComposition = true;
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _name.dispose();
    _map = null;
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  // Map.

  void _created(MapLibreMapController controller) {
    _map = controller;
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && _map == controller) setState(() => _mapFailed = true);
    });
  }

  void _styleLoaded() {
    _loadTimeout?.cancel();
    if (mounted && _mapFailed) setState(() => _mapFailed = false);
  }

  void _retryMap() {
    _loadTimeout?.cancel();
    setState(() {
      _map = null;
      _mapFailed = false;
      _generation++;
    });
  }

  Future<void> _moveCamera(LatLng target, {double? zoom}) async {
    final map = _map;
    if (map == null) return;
    final camera = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newLatLngZoom(target, zoom);
    try {
      _reduced
          ? await map.moveCamera(camera)
          : await map.animateCamera(camera,
              duration: PlacePickerScreen.transition);
    } catch (_) {
      if (mounted && _map == map) setState(() => _mapFailed = true);
    }
  }

  /// A tap on the map: the pin goes there.
  void _tapped(math.Point<double> point, LatLng coordinate) {
    _searchFocus.unfocus();
    _pin(coordinate, PlaceSource.pin);
    _moveCamera(coordinate);
  }

  void _cameraMoved(CameraPosition position) => _target = position.target;

  /// The map stopped after a drag: the place under the pin.
  void _cameraIdle() {
    final target = _target ?? _map?.cameraPosition?.target;
    if (!_gesture || target == null) return;
    _gesture = false;
    final current = _candidate;
    if (current != null &&
        (current.latitude - target.latitude).abs() < 1e-6 &&
        (current.longitude - target.longitude).abs() < 1e-6) {
      return;
    }
    _pin(target, PlaceSource.pin);
  }

  // Candidate.

  /// A point without a name yet: look it up.
  Future<void> _pin(LatLng at, PlaceSource source) async {
    final request = ++_nameRequest;
    _name.clear();
    setState(() {
      _candidate = PlaceCandidate(
          latitude: at.latitude, longitude: at.longitude, source: source);
      _naming = _Naming.looking;
      _locationError = null;
      _results = null;
    });
    _Naming outcome;
    PlaceCandidate? named;
    try {
      named = await widget.lookup.nameAt(at.latitude, at.longitude);
      outcome = named != null && named.named ? _Naming.idle : _Naming.empty;
    } catch (_) {
      outcome = _Naming.failed;
    }
    if (!mounted || request != _nameRequest) return;
    setState(() {
      _naming = outcome;
      if (outcome == _Naming.idle) {
        _candidate =
            _candidate!.copyWith(name: named!.name, address: named.address);
      }
    });
  }

  void _choose(PlaceCandidate place) {
    _nameRequest++;
    _debounce?.cancel();
    _searchVersion++;
    _searchFocus.unfocus();
    _search.clear();
    _name.clear();
    setState(() {
      _candidate = place;
      _naming = _Naming.idle;
      _results = null;
      _searchError = false;
      _locationError = null;
    });
    _moveCamera(LatLng(place.latitude, place.longitude), zoom: 15);
  }

  // Search.

  void _queryChanged(String query) {
    _debounce?.cancel();
    final version = ++_searchVersion;
    setState(() {}); // The clear button.
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _searchError = false;
      });
      return;
    }
    _debounce = Timer(PlacePickerScreen.debounce, () => _runSearch(version));
  }

  Future<void> _runSearch([int? version]) async {
    final run = version ?? ++_searchVersion;
    final query = _search.text.trim();
    if (query.isEmpty) return;
    try {
      final results = await widget.lookup.search(query);
      // An older response never replaces a newer query's.
      if (!mounted || run != _searchVersion) return;
      setState(() {
        _results = results;
        _searchError = false;
      });
    } catch (_) {
      if (!mounted || run != _searchVersion) return;
      setState(() {
        _results = const [];
        _searchError = true;
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchVersion++;
    _search.clear();
    setState(() {
      _results = null;
      _searchError = false;
    });
  }

  // Device location.

  Future<void> _locate() async {
    if (_locating) return;
    _searchFocus.unfocus();
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final fix = await widget.location.current();
    if (!mounted) return;
    setState(() => _locating = false);
    switch (fix) {
      case DeviceFixFound(:final latitude, :final longitude):
        // A candidate like any other: used only after "Dùng địa điểm này".
        final at = LatLng(latitude, longitude);
        _pin(at, PlaceSource.device);
        _moveCamera(at, zoom: 16);
      case DeviceFixDenied():
        setState(() => _locationError = PlacePickerScreen.locationDenied);
      case DeviceFixFailed():
        setState(() => _locationError = PlacePickerScreen.locationFailed);
    }
  }

  void _confirm() {
    final candidate = _candidate;
    if (candidate == null || _naming == _Naming.looking) return;
    final typed = _name.text.trim();
    Navigator.of(context).pop(!candidate.named && typed.isNotEmpty
        ? candidate.copyWith(name: typed)
        : candidate);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(fit: StackFit.expand, children: [
        Listener(
          onPointerDown: (_) => _gesture = true,
          child: MapLibreMap(
            key: ValueKey(_generation),
            styleString: _style,
            initialCameraPosition: CameraPosition(
                target: initial == null
                    ? PlacePickerScreen.start
                    : LatLng(initial.latitude, initial.longitude),
                zoom: initial == null ? 12 : 15),
            trackCameraPosition: true,
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            onMapClick: _tapped,
            onMapLongClick: _tapped,
            onCameraMove: _cameraMoved,
            onCameraIdle: _cameraIdle,
            compassViewMargins: const math.Point(12, 140),
            attributionButtonMargins: const math.Point(12, 8),
          ),
        ),
        // The pin at the centre; above it nothing but the search and panel.
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: _CenterPin(chosen: _candidate != null),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Material(
                  color: AppColors.surface,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: PlacePickerScreen.backTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Material(
                    color: AppColors.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: _queryChanged,
                      onSubmitted: (_) => _runSearch(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: PlacePickerScreen.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: PlacePickerScreen.clearTooltip,
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded)),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ]),
              if (results != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: _resultList(results)),
              ],
              const Spacer(),
              if (_mapFailed) ...[
                _Notice(
                  text: PlacePickerScreen.mapFailed,
                  action: PlacePickerScreen.retryLabel,
                  onAction: _retryMap,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (widget.location.supported)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: FloatingActionButton.small(
                      heroTag: null,
                      tooltip: PlacePickerScreen.myLocation,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: _locating ? null : _locate,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ),
              _panel(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _resultList(List<PlaceCandidate> results) => Material(
        color: AppColors.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            if (_searchError)
              ListTile(
                title: const Text(PlacePickerScreen.searchFailed,
                    style: _Text.body),
                trailing: TextButton(
                    onPressed: _runSearch,
                    child: const Text(PlacePickerScreen.retryLabel)),
              )
            else if (results.isEmpty)
              const ListTile(
                  title: Text(PlacePickerScreen.noResults, style: _Text.body)),
            for (final place in results)
              ListTile(
                leading: const Icon(Icons.place_outlined,
                    color: AppColors.textPrimary),
                title: Text(place.name ?? PlacePickerScreen.unnamed,
                    style: _Text.strong),
                subtitle: Text(
                    [
                      if (place.address case final address?) address,
                      if (place.sample) PlacePickerScreen.sampleLabel,
                    ].join(' · '),
                    style: _Text.small),
                onTap: () => _choose(place),
              ),
          ],
        ),
      );

  Widget _panel() {
    final candidate = _candidate;
    return Material(
      color: AppColors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AnimatedSize(
          duration: _reduced ? Duration.zero : PlacePickerScreen.transition,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (candidate == null) ...[
                const Text(PlacePickerScreen.nothingYet, style: _Text.strong),
                const SizedBox(height: AppSpacing.xs),
                const Text(PlacePickerScreen.howTo, style: _Text.small),
              ] else
                _candidateInfo(candidate),
              if (_locating) ...[
                const SizedBox(height: AppSpacing.sm),
                const _Working(PlacePickerScreen.locating),
              ],
              if (_locationError case final error?) ...[
                const SizedBox(height: AppSpacing.sm),
                _Notice(text: error),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: candidate == null || _naming == _Naming.looking
                    ? null
                    : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  textStyle: _Text.button,
                ),
                child: const Text(PlacePickerScreen.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _candidateInfo(PlaceCandidate candidate) {
    final details = [
      if (candidate.address case final address?) address,
      if (candidate.sample) PlacePickerScreen.sampleLabel,
      candidate.coordinates,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              candidate.source == PlaceSource.device
                  ? Icons.my_location_rounded
                  : Icons.place_rounded,
              color: AppColors.primaryAction),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name ?? PlacePickerScreen.unnamed,
                    style: _Text.strong),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: _Text.small),
              ],
            ),
          ),
        ]),
        if (_naming == _Naming.looking) ...[
          const SizedBox(height: AppSpacing.sm),
          const _Working(PlacePickerScreen.naming),
        ],
        if (_naming == _Naming.failed || _naming == _Naming.empty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Notice(
              text: _naming == _Naming.failed
                  ? PlacePickerScreen.lookupFailed
                  : PlacePickerScreen.lookupEmpty),
        ],
        if (!candidate.named && _naming != _Naming.looking) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            maxLength: PlacePickerScreen.nameMax,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration:
                const InputDecoration(labelText: PlacePickerScreen.nameLabel),
          ),
        ],
      ],
    );
  }
}

/// Primary pin with an ink outline, drawn by Flutter (not a map symbol), so
/// it always marks the centre. Faded until a place is chosen.
class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.chosen});

  final bool chosen;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: chosen ? 1 : .55,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : PlacePickerScreen.transition,
        child: const SizedBox.square(
          dimension: 48,
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.location_on, size: 48, color: AppColors.textPrimary),
            Icon(Icons.location_on, size: 40, color: AppColors.primaryAction),
          ]),
        ),
      );
}

class _Working extends StatelessWidget {
  const _Working(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Row(children: [
          const SizedBox.square(
              dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: _Text.small)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Material(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 20, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: _Text.small)),
              if (action case final action?)
                TextButton(onPressed: onAction, child: Text(action)),
            ]),
          ),
        ),
      );
}

abstract final class _Text {
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const strong = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const small = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 13,
    height: 18 / 13,
    color: AppColors.textPrimary,
  );
  static const button = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
}
