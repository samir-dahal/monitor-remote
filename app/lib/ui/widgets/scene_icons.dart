import 'package:flutter/material.dart';

/// Icons a scene can use, keyed by the names stored with the scene.
abstract final class SceneIcons {
  static const _icons = <String, IconData>{
    'briefcase': Icons.work_outline,
    'moon': Icons.nightlight_outlined,
    'movie': Icons.movie_outlined,
    'gamepad': Icons.sports_esports_outlined,
    'sun': Icons.wb_sunny_outlined,
    'book': Icons.menu_book_outlined,
    'coffee': Icons.coffee_outlined,
    'sparkles': Icons.auto_awesome_outlined,
  };

  static IconData of(String key) => _icons[key] ?? Icons.auto_awesome_outlined;
}
