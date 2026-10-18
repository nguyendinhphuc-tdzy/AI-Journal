import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/nudaeng_map_marker.dart';
import 'widgets/share_dialog.dart';

Future<void> showShareDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const ShareDialog());

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _query = '';
  String? _filter;
  BitmapDescriptor _markerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  static const _places = [
    (
      id: 'food',
      name: 'Bếp cô Ba ân',
      category: 'Food',
      position: LatLng(10.7740, 106.7000)
    ),
    (
      id: 'cafe',
      name: 'Quiet corner',
      category: 'Study Cafe',
      position: LatLng(10.7790, 106.6960)
    ),
    (
      id: 'park',
      name: 'Riverside park',
      category: 'Entertainment',
      position: LatLng(10.7760, 106.7060)
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMarker();
  }

  Future<void> _loadMarker() async {
    try {
      final icon = await createNudaengMarker();
      if (mounted) setState(() => _markerIcon = icon);
    } catch (error) {
      // Preserve usable pink pins if the asset cannot be decoded.
      debugPrint('Could not load Nudaeng map marker: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = _places.where((place) =>
        (_filter == null || place.category == _filter) &&
        place.name.toLowerCase().contains(_query.toLowerCase().trim()));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(fit: StackFit.expand, children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(10.7769, 106.7009), zoom: 14.5),
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          padding: const EdgeInsets.only(top: 80, bottom: 16),
          markers: {
            for (final place in places)
              Marker(
                markerId: MarkerId(place.id),
                position: place.position,
                icon: _markerIcon,
                anchor: const Offset(.5, 1),
                infoWindow:
                    InfoWindow(title: place.name, snippet: place.category),
              ),
          },
          onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 2,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(
                      hintText: 'Search places',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: PopupMenuButton<String>(
                    tooltip: 'Filter places',
                    icon: Icon(Icons.menu,
                        color: _filter == null
                            ? AppColors.textPrimary
                            : AppColors.primaryDark),
                    position: PopupMenuPosition.under,
                    onSelected: (category) => setState(
                        () => _filter = _filter == category ? null : category),
                    itemBuilder: (_) => [
                      for (final category in [
                        'Study Cafe',
                        'Entertainment',
                        'Food'
                      ])
                        CheckedPopupMenuItem(
                            value: category,
                            checked: _filter == category,
                            child: Text(category)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (places.isEmpty)
          const Center(
              child: Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No places found')))),
      ]),
    );
  }
}
