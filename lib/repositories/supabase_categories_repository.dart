import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Maps hex color strings to semantic color names for the color column.
// turn to orange if no match is found
String _semanticColorName(String hex) {
  const hexToName = {
    '#9c27b0': 'purple',
    '#6a1b9a': 'purple',
    '#f44336': 'red',
    '#b71c1c': 'red',
    '#8bc34a': 'lightGreen',
    '#33691e': 'lightGreen',
    '#ffc107': 'amber',
    '#ff8f00': 'amber',
    '#2196f3': 'blue',
    '#0d47a1': 'blue',
    '#4caf50': 'green',
    '#1b5e20': 'green',
    '#03a9f4': 'lightBlue',
    '#01579b': 'lightBlue',
    '#ff9800': 'orange',
    '#e65100': 'orange',
    '#e91e63': 'pink',
    '#880e4f': 'pink',
    '#009688': 'teal',
    '#004d40': 'teal',
    '#f57c00': 'orange',
  };
  final cleaned = hex.trim().replaceFirst('#', '').toLowerCase();
  final withHash = '#$cleaned';
  return hexToName[withHash] ?? 'orange';
}

class SupabaseCategoriesRepository {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response =
        await supabase.from('categories').select().order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createCategory({
    required String title,
    required String gradientStart,
    required String gradientEnd,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'color': _semanticColorName(gradientStart),
      'gradient_start': gradientStart,
      'gradient_end': gradientEnd,
    };
    debugPrint(
        '[SupabaseCategoriesRepository.createCategory] payload=$payload');
    await supabase.from('categories').insert(payload);
  }

  Future<void> updateCategory({
    required String id,
    required String title,
    required String gradientStart,
    required String gradientEnd,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'color': _semanticColorName(gradientStart),
      'gradient_start': gradientStart,
      'gradient_end': gradientEnd,
    };
    debugPrint(
        '[SupabaseCategoriesRepository.updateCategory] id=$id payload=$payload');
    await supabase.from('categories').update(payload).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await supabase.from('categories').delete().eq('id', id);
  }
}
