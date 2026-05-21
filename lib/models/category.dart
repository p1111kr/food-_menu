import 'package:flutter/material.dart';

// our origional map
Map<String, Color> colorMap = {
  'purple': Colors.purple,
  'red': Colors.red,
  'orange': Colors.orange,
  'amber': Colors.amber,
  'blue': Colors.blue,
  'green': Colors.green,
  'lightBlue': Colors.lightBlue,
  'lightGreen': Colors.lightGreen,
  'pink': Colors.pink,
  'teal': Colors.teal,
};

Color colorFromHex(String? value, Color fallback) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }

  final cleaned = value.trim().replaceFirst('#', '');
  if (cleaned.length != 6 && cleaned.length != 8) {
    return fallback;
  }

  final withAlpha = cleaned.length == 6 ? 'ff$cleaned' : cleaned;
  final parsed = int.tryParse(withAlpha, radix: 16);
  if (parsed == null) {
    return fallback;
  }

  return Color(parsed);
}

class Category {
  const Category({
    required this.id,
    required this.title,
    this.color = Colors.orange,
    Color? gradientStart,
    Color? gradientEnd,
    this.gradientStartHex,
    this.gradientEndHex,
  })  : gradientStart = gradientStart ?? color,
        gradientEnd = gradientEnd ?? color;

  final String id;
  final String title;
  final Color color;
  final Color gradientStart;
  final Color gradientEnd;
  final String? gradientStartHex;
  final String? gradientEndHex;

  factory Category.fromJson(Map<String, dynamic> json) {
    final fallbackColor = colorMap[json['color']] ?? Colors.orange;
    final startHex = json['gradientStart']?.toString();
    final endHex = json['gradientEnd']?.toString();

    return Category(
      id: json['id'],
      title: json['title'],
      color: fallbackColor,
      gradientStart: colorFromHex(startHex, fallbackColor.withOpacity(0.55)),
      gradientEnd: colorFromHex(endHex, fallbackColor.withOpacity(0.9)),
      gradientStartHex: startHex,
      gradientEndHex: endHex,
    );
  }
}
