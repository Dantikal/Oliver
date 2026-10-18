import 'package:flutter/material.dart';

/// Иконка категории по её `icon` (ключ или эмодзи от бэкенда).
IconData categoryIcon(String? key) => switch (key) {
      'phone' || '📱' => Icons.smartphone_rounded,
      'car' || '🚗' => Icons.directions_car_rounded,
      'home' || '🏠' => Icons.home_rounded,
      'clothes' || '👟' || '👕' => Icons.checkroom_rounded,
      'furniture' || '🛋️' || '🛋' => Icons.chair_rounded,
      'hobby' || '🎸' => Icons.music_note_rounded,
      'pets' || '🐶' => Icons.pets_rounded,
      'services' || '🛠️' || '🛠' => Icons.handyman_rounded,
      'livestock' || '🐄' || '🐑' => Icons.agriculture_rounded,
      'gift' || '🎁' => Icons.volunteer_activism_rounded,
      'all' => Icons.apps_rounded,
      _ => Icons.sell_rounded,
    };
