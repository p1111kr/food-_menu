import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

ImageProvider mealImageProvider(String imageUrl) {
  final trimmedUrl = imageUrl.trim();

  if (trimmedUrl.isEmpty) {
    return MemoryImage(kTransparentImage);
  }

  final uri = Uri.tryParse(trimmedUrl);

  if (uri != null && uri.scheme == 'data') {
    final commaIndex = trimmedUrl.indexOf(',');
    if (commaIndex != -1) {
      final metadata = trimmedUrl.substring(0, commaIndex).toLowerCase();
      final data = trimmedUrl.substring(commaIndex + 1).replaceAll(
            RegExp(r'\s+'),
            '',
          );

      if (metadata.contains(';base64')) {
        try {
          return MemoryImage(base64Decode(data));
        } on FormatException {
          return MemoryImage(kTransparentImage);
        }
      }
    }
  }

  return NetworkImage(trimmedUrl);
}
