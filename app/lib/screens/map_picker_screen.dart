import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/mock_providers.dart';
import '../theme/app_theme.dart';
import '../utils/location_helper.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _islamabadCenter = LatLng(33.7215, 73.0433);

  GoogleMapController? _mapController;
  LatLng _currentCenter = _islamabadCenter;
  String _selectedAddress = 'G-11, Islamabad';
  bool _isMoving = false;
  bool _isGeocoding = false;
  Set<Marker> _markers = {};

  // Search state
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    final loc = await getUserWebLocation();
    if (loc != null && mounted) {
      _currentCenter = loc;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController?.moveCamera(
          CameraUpdate.newLatLngZoom(loc, 14),
        );
      });
      _reverseGeocode(loc);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS access nahi mila. Upar ilaka type karein ya map drag karein.'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    for (var i = 0; i < mockProviders.length; i++) {
      final p = mockProviders[i];
      final lat = p.coordinates['lat'] as double?;
      final lng = p.coordinates['lng'] as double?;
      if (lat == null || lng == null) continue;
      final jitter = i * 0.0018;
      markers.add(Marker(
        markerId: MarkerId(p.id),
        position: LatLng(lat + jitter, lng - jitter),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          p.blueTick ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: p.name,
          snippet:
              '${p.displayPrice} • ${p.rating}⭐${p.blueTick ? " ✓ Verified" : ""}',
        ),
      ));
    }
    setState(() => _markers = markers);
  }

  // ── Search: autocomplete ────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final baseUrl = kIsWeb ? 'http://localhost:3000' : 'https://khidmatbot-backend-251161399989.us-central1.run.app';
      final url = Uri.parse(
        '$baseUrl/api/places/autocomplete'
        '?input=${Uri.encodeComponent(query)}',
      );
      try {
        final resp = await http.get(url);
        if (!mounted) return;
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final preds = (data['predictions'] as List? ?? []);
          setState(() {
            _suggestions = preds
                .take(5)
                .map((p) => {
                      'description': p['description'] as String,
                      'place_id': p['place_id'] as String,
                    })
                .toList();
            _showSuggestions = _suggestions.isNotEmpty;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _selectSuggestion(Map<String, String> s) async {
    final desc = s['description']!;
    _searchCtrl.text = desc;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _selectedAddress = desc;
    });
    FocusScope.of(context).unfocus();

    // Forward-geocode to get LatLng for the selected suggestion via proxy
    final baseUrl = kIsWeb ? 'http://localhost:3000' : 'https://khidmatbot-backend-251161399989.us-central1.run.app';
    final url = Uri.parse(
      '$baseUrl/api/places/geocode'
      '?address=${Uri.encodeComponent(desc)}',
    );
    try {
      final resp = await http.get(url);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final loc = (results[0]['geometry'] as Map)['location'] as Map;
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          _currentCenter = LatLng(lat, lng);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController?.moveCamera(
              CameraUpdate.newLatLngZoom(_currentCenter, 14),
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _searchAndGo(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    FocusScope.of(context).unfocus();

    final baseUrl = kIsWeb ? 'http://localhost:3000' : 'https://khidmatbot-backend-251161399989.us-central1.run.app';
    final url = Uri.parse(
      '$baseUrl/api/places/geocode'
      '?address=${Uri.encodeComponent(query)}',
    );
    try {
      final resp = await http.get(url);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final loc = (results[0]['geometry'] as Map)['location'] as Map;
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          final formatted = results[0]['formatted_address'] as String;

          setState(() {
            _currentCenter = LatLng(lat, lng);
            _selectedAddress = formatted;
            _searchCtrl.text = formatted;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController?.moveCamera(
              CameraUpdate.newLatLngZoom(_currentCenter, 15),
            );
          });
        } else {
          _showErrorSnackBar();
        }
      } else {
        _showErrorSnackBar();
      }
    } catch (_) {
      _showErrorSnackBar();
    }
  }

  void _showErrorSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address not found'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  // ── Camera events: reverse geocode on idle ──────────────────────────
  void _onCameraMove(CameraPosition pos) {
    setState(() {
      _isMoving = true;
      _currentCenter = pos.target;
    });
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    _reverseGeocode(_currentCenter);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (_isGeocoding) return;
    setState(() => _isGeocoding = true);
    
    final baseUrl = kIsWeb ? 'http://localhost:3000' : 'https://khidmatbot-backend-251161399989.us-central1.run.app';
    final url = Uri.parse(
      '$baseUrl/api/places/geocode'
      '?latlng=${pos.latitude},${pos.longitude}',
    );
    try {
      final resp = await http.get(url);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final comps = results[0]['address_components'] as List? ?? [];
          String? area;
          String? city;
          for (final c in comps) {
            final types = (c['types'] as List).cast<String>();
            final name = c['long_name'] as String;
            if (area == null &&
                (types.contains('sublocality_level_1') ||
                    types.contains('neighborhood') ||
                    types.contains('sublocality'))) {
              area = name;
            }
            if (city == null && types.contains('locality')) {
              city = name;
            }
          }
          final address = (area != null && city != null)
              ? '$area, $city'
              : city ??
                  (results[0]['formatted_address'] as String? ??
                      'Location not found');
          setState(() => _selectedAddress = address);
        } else {
          setState(() => _selectedAddress = 'Location not found');
        }
      } else {
        setState(() => _selectedAddress = 'Location not found');
      }
    } catch (_) {
      if (mounted) setState(() => _selectedAddress = 'Location not found');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _goToMyLocation() async {
    final loc = await getUserWebLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(loc ?? _islamabadCenter, 14),
      );
    });
  }

  void _confirmLocation() => Navigator.pop(context, _selectedAddress);

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
          // ── Full-screen Google Map ────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _islamabadCenter,
              zoom: 13,
            ),
            onMapCreated: (c) {
              _mapController = c;
              if (_currentCenter != _islamabadCenter) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  c.moveCamera(CameraUpdate.newLatLngZoom(_currentCenter, 14));
                });
              }
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // ── Floating center pin (Uber-style) ─────────────────────────
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

          // ── Search bar + autocomplete dropdown ────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search TextField
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) => _searchAndGo(value),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Ilaka likhein — Korangi Karachi, Gulberg Lahore...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppTheme.textGrey),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: AppTheme.textGrey,
                              onPressed: _clearSearch,
                            ),
                          IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            color: AppTheme.primary,
                            onPressed: () => _searchAndGo(_searchCtrl.text),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // Autocomplete suggestions
                if (_showSuggestions && _suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return InkWell(
                          borderRadius: i == 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(12))
                              : i == _suggestions.length - 1
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(12))
                                  : BorderRadius.zero,
                          onTap: () => _selectSuggestion(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppTheme.primary, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s['description']!,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Legend ───────────────────────────────────────────────────
          Positioned(
            bottom: 160,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
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
                  const Text('Verified', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 10),
                  _legendDot(Colors.orange),
                  const SizedBox(width: 4),
                  const Text('Unverified',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),

          // ── My-location FAB ──────────────────────────────────────────
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.my_location, color: AppTheme.primary),
            ),
          ),

          // ── Bottom address card ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCard(
              address: _selectedAddress,
              isMoving: _isMoving || _isGeocoding,
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Bottom card ───────────────────────────────────────────────────────────────
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
              color: Colors.black12, blurRadius: 12, offset: Offset(0, -3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const Text('Chunida Location',
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isMoving ? AppTheme.textGrey : AppTheme.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Map drag karein ya upar ilaka type karein',
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
              icon: Icon(Icons.check_circle_outline,
                  color: isMoving ? Colors.grey : Colors.white, size: 18),
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
