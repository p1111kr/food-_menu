import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../repositories/supabase_categories_repository.dart';

Color parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final padded = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  return Color(int.parse(padded, radix: 16));
}

final supabaseCategoriesRepositoryProvider =
    Provider<SupabaseCategoriesRepository>((ref) {
  return SupabaseCategoriesRepository();
});

final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final repository = ref.watch(supabaseCategoriesRepositoryProvider);

  debugPrint('[categoriesProvider] loading categories from Supabase');

  try {
    final listData = await repository.fetchCategories();

    final categories = listData.map((item) {
      final startHex = item['gradient_start'] as String? ??
          item['color'] as String? ??
          '#ff9800';
      final endHex = item['gradient_end'] as String? ?? startHex;

      debugPrint(
          '[categoriesProvider] category id="${item['id']}" title="${item['title']}" start=$startHex end=$endHex');

      return Category(
        id: item['id'],
        title: item['title'],
        color: parseHexColor(startHex),
        gradientStart: parseHexColor(startHex),
        gradientEnd: parseHexColor(endHex),
        gradientStartHex: startHex,
        gradientEndHex: endHex,
      );
    }).toList();

    debugPrint(
      '[categoriesProvider] decoded ${categories.length} categories from Supabase',
    );

    return categories;
  } catch (error, stackTrace) {
    debugPrint('[categoriesProvider] exception: $error');

    debugPrintStack(
      stackTrace: stackTrace,
      label: '[categoriesProvider] stack',
    );
  }

  debugPrint('[categoriesProvider] no categories loaded, returning empty list');
  return [];
});
