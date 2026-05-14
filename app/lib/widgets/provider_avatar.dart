import 'package:flutter/material.dart';
import '../models/provider_model.dart';

class ProviderAvatar extends StatelessWidget {
  final ProviderModel provider;
  final double radius;

  const ProviderAvatar({
    super.key,
    required this.provider,
    required this.radius,
  });

  static const List<Color> _colors = [
    Color(0xFF1D9E75),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFFF44336),
  ];

  Color get _bgColor => _colors[provider.colorIndex % _colors.length];

  String get _photoUrl {
    if (provider.photoUrl != null && provider.photoUrl!.isNotEmpty) {
      return provider.photoUrl!;
    }
    final seed = provider.name.toLowerCase().replaceAll(' ', '_');
    if (provider.gender == 'female') {
      return 'https://api.dicebear.com/7.x/lorelei/png?seed=$seed&size=200';
    }
    return 'https://api.dicebear.com/7.x/avataaars/png?seed=$seed&size=200&top=shortHair,shortCurly,shortFlat,shortRound,shortWaved&facialHairProbability=30';
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          _photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _initialsBox(size),
        ),
      ),
    );
  }

  Widget _initialsBox(double size) {
    return Container(
      width: size,
      height: size,
      color: _bgColor,
      alignment: Alignment.center,
      child: Text(
        provider.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
