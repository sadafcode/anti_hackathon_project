import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/mock_providers.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _islamabadCenter = LatLng(33.7215, 73.0433);

  static const Map<String, LatLng> _sectorCoords = {
    'G-11': LatLng(33.7215, 73.0433),
    'G-13': LatLng(33.6844, 73.0479),
    'F-10': LatLng(33.7121, 72.9754),
    'F-8': LatLng(33.7273, 72.9902),
    'I-8': LatLng(33.6738, 73.0781),
    'G-9': LatLng(33.7032, 73.0272),
    'F-7': LatLng(33.7294, 72.9756),
    'E-7': LatLng(33.7389, 73.0001),
    'H-8': LatLng(33.6890, 73.0150),
    'I-10': LatLng(33.6640, 73.0350),
  };

  GoogleMapController? _mapController;
  LatLng _currentCenter = _islamabadCenter;
  String _selectedAddress = 'G-11, Islamabad';
  bool _isMoving = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    for (var i = 0; i < mockProviders.length; i++) {
      final provider = mockProviders[i];
      final base = _sectorCoords[provider.area];
      if (base == null) continue;
      // slight jitter so markers from the same sector don't stack
      final jitter = i * 0.0018;
      final pos = LatLng(base.latitude + jitter, base.longitude - jitter);
      markers.add(Marker(
        markerId: MarkerId(provider.id),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          provider.blueTick
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: provider.name,
          snippet:
              '${provider.displayPrice} • ${provider.rating}⭐${provider.blueTick ? " ✓ Verified" : ""}',
        ),
      ));
    }
    setState(() => _markers = markers);
  }

  String _nearestSector(LatLng pos) {
    String nearest = 'Islamabad';
    double minDist = double.infinity;
    for (final entry in _sectorCoords.entries) {
      final dlat = pos.latitude - entry.value.latitude;
      final dlng = pos.longitude - entry.value.longitude;
      final dist = dlat * dlat + dlng * dlng;
      if (dist < minDist) {
        minDist = dist;
        nearest = entry.key;
      }
    }
    return '$nearest, Islamabad';
  }

  void _onCameraMove(CameraPosition pos) {
    setState(() {
      _isMoving = true;
      _currentCenter = pos.target;
    });
  }

  void _onCameraIdle() {
    setState(() {
      _isMoving = false;
      _selectedAddress = _nearestSector(_currentCenter);
    });
  }

  void _goToMyLocation() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_islamabadCenter, 14),
    );
  }

  void _confirmLocation() {
    Navigator.pop(context, _selectedAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Chunein'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _islamabadCenter,
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // ── Center pin (Uber-style) ─────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSlide(
                  offset: _isMoving ? const Offset(0, -0.15) : Offset.zero,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppTheme.primary,
                    size: 52,
                  ),
                ),
                // shadow under pin
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isMoving ? 10 : 7,
                  height: _isMoving ? 5 : 3,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),

          // ── Legend (top-left) ───────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(AppTheme.primary),
                  const SizedBox(width: 4),
                  const Text('Verified',
                      style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 10),
                  _legendDot(Colors.orange),
                  const SizedBox(width: 4),
                  const Text('Unverified',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),

          // ── My-location FAB ─────────────────────────────────────────
          Positioned(
            bottom: 152,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              child:
                  const Icon(Icons.my_location, color: AppTheme.primary),
            ),
          ),

          // ── Bottom location card ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCard(
              address: _selectedAddress,
              isMoving: _isMoving,
              onConfirm: _confirmLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Bottom card widget ────────────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final String address;
  final bool isMoving;
  final VoidCallback onConfirm;

  const _BottomCard({
    required this.address,
    required this.isMoving,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Chunida Location',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.location_on,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isMoving ? 'Location dhundh raha hoon...' : address,
                    key: ValueKey(isMoving ? 'moving' : address),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isMoving
                          ? AppTheme.textGrey
                          : AppTheme.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Map ko drag karein apni exact jagah ke liye',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isMoving ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: Icon(
                Icons.check_circle_outline,
                color: isMoving ? Colors.grey : Colors.white,
                size: 18,
              ),
              label: Text(
                'Confirm Karo',
                style: TextStyle(
                  color: isMoving ? Colors.grey : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
