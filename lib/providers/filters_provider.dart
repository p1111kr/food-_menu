import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum Filter { glutenFree, lactoseFree, vegetarian, vegan }

class FiltersNotifier extends Notifier<Map<Filter, bool>> {
  @override
  Map<Filter, bool> build() => const {
        Filter.glutenFree: false,
        Filter.lactoseFree: false,
        Filter.vegetarian: false,
        Filter.vegan: false,
      };

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> fetchAndSetFilters() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('filters')
          .eq('id', user.id)
          .maybeSingle();

      final filters = profile?['filters'] as Map<String, dynamic>?;

      if (filters != null) {
        state = {
          Filter.glutenFree: filters['glutenFree'] ?? false,
          Filter.lactoseFree: filters['lactoseFree'] ?? false,
          Filter.vegan: filters['vegan'] ?? false,
          Filter.vegetarian: filters['vegetarian'] ?? false,
        };
      }

      debugPrint('[FiltersNotifier] loaded filters: $state');
    } catch (error) {
      debugPrint('[FiltersNotifier] Error fetching filters: $error');
    }
  }

  void setFilter(Filter filter, bool isActive) {
    // Correctly update the Map by replacing the entry for the given enum key
    final newState = Map<Filter, bool>.from(state);
    newState[filter] = isActive;
    state = newState;
    _syncWithBackend();
  }

  Future<void> _syncWithBackend() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'filters': {
          'glutenFree': state[Filter.glutenFree],
          'lactoseFree': state[Filter.lactoseFree],
          'vegan': state[Filter.vegan],
          'vegetarian': state[Filter.vegetarian],
        },
      });

      debugPrint('[FiltersNotifier] synced filters to Supabase: $state');
    } catch (error) {
      debugPrint('[FiltersNotifier] Failed to sync filters: $error');
    }
  }
}

final filtersProvider = NotifierProvider<FiltersNotifier, Map<Filter, bool>>(
    () => FiltersNotifier());
