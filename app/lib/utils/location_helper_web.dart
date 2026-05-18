import 'dart:html' as html;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng?> getUserWebLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      timeout: const Duration(seconds: 5),
    );
    final coords = position.coords;
    if (coords != null && coords.latitude != null && coords.longitude != null) {
      return LatLng(coords.latitude!.toDouble(), coords.longitude!.toDouble());
    }
    return null;
  } catch (_) {
    return null;
  }
}
