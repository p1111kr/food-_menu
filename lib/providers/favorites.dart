import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';

// Provider for the Supabase client to enable testability
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class FavoriteMealsNotifier extends Notifier<List<Meal>> {
  @override
  List<Meal> build() {
    return [];
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> fetchAndSetFavorites() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get favorite meal ID from the users profile in Supabase
      final profile = await _supabase
          .from('profiles')
          .select('favorites')
          .eq('id', user.id)
          .maybeSingle();

      final favoriteIds = (profile?['favorites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      if (favoriteIds.isEmpty) {
        state = [];
        return;
      }

      // Fetch all meals whose IDs are in the favorites list
      final response =
          await _supabase.from('meals').select().inFilter('id', favoriteIds);

      final loadedFavorites = (response as List)
          .map((item) => Meal.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint(
          '[FavoritesNotifier] loaded ${loadedFavorites.length} favorites');
      state = loadedFavorites;
    } catch (error) {
      debugPrint('[FavoritesNotifier] Error fetching favorites: $error');
    }
  }

  Future<bool> toggleMealFavoriteStatus(Meal meal) async {
    final mealIsFavorite = state.any((m) => m.id == meal.id);

    // 1. Update UI state locally for speed
    if (mealIsFavorite) {
      state = state.where((m) => m.id != meal.id).toList();
    } else {
      state = [...state, meal];
    }

    // 2. Sync with Supabase
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return !mealIsFavorite;

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'favorites': state.map((m) => m.id).toList(),
      });

      debugPrint(
          '[FavoritesNotifier] synced ${state.length} favorites to Supabase');
    } catch (error) {
      debugPrint('[FavoritesNotifier] Failed to sync favorites: $error');
      // Revert local state on sync failure to keep UI consistent
      if (mealIsFavorite) {
        state = [...state, meal];
      } else {
        state = state.where((m) => m.id != meal.id).toList();
      }
      return mealIsFavorite;
    }

    return !mealIsFavorite;
  }
}

final favoriteMealsProvider =
    NotifierProvider<FavoriteMealsNotifier, List<Meal>>(() {
  return FavoriteMealsNotifier();
});
