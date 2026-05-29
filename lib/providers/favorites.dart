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

    debugPrint('=== FAVORITES TOGGLE START ===');
    debugPrint('meal.id="${meal.id}" meal.title="${meal.title}"');
    debugPrint('favorites state has ${state.length} meals');
    debugPrint('current favorite IDs: [${state.map((m) => m.id).join(", ")}]');
    debugPrint('mealIsFavorite BEFORE toggle: $mealIsFavorite');
    debugPrint(
        'expected behavior: mealIsFavorite=$mealIsFavorite -> should ${mealIsFavorite ? "REMOVE" : "ADD"}');
    // 1. Update UI state locally for speed
    if (mealIsFavorite) {
      state = state.where((m) => m.id != meal.id).toList();
    } else {
      state = [...state, meal];
    }

    debugPrint('state AFTER local update has ${state.length} meals');
    debugPrint(
        'post-toggle state contains meal? ${state.any((m) => m.id == meal.id)}');
    debugPrint(
        'post-toggle favorite IDs: [${state.map((m) => m.id).join(", ")}]');

    // 2. Sync with Supabase
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('NO USER -> returning !mealIsFavorite=${!mealIsFavorite}');
        return !mealIsFavorite;
      }

      final newFavoriteIds = state.map((m) => m.id).toList();
      debugPrint('ABOUT TO UPSERT: id=${user.id} favorites=$newFavoriteIds');
      final response = await _supabase.from('profiles').upsert({
        'id': user.id,
        'favorites': newFavoriteIds,
      }).select();

      debugPrint('UPSERT RESPONSE: $response');
      debugPrint(
          'Sync SUCCESS -> returning !mealIsFavorite=${!mealIsFavorite}');
    } catch (error) {
      debugPrint('SYNC FAILED: $error');
      debugPrint(
          'mealIsFavorite was $mealIsFavorite -> revert will ${mealIsFavorite ? "RE-ADD" : "RE-REMOVE"}');

      // Revert local state on sync failure to keep UI consistent
      if (mealIsFavorite) {
        state = [...state, meal];
      } else {
        state = state.where((m) => m.id != meal.id).toList();
      }

      debugPrint('state AFTER revert has ${state.length} meals');
      debugPrint(
          'Returning: $mealIsFavorite (this will make wasAdded=$mealIsFavorite)');
      return mealIsFavorite;
    }

    debugPrint('=== FAVORITES TOGGLE END (returning ${!mealIsFavorite}) ===');
    return !mealIsFavorite;
  }
}

final favoriteMealsProvider =
    NotifierProvider<FavoriteMealsNotifier, List<Meal>>(() {
  return FavoriteMealsNotifier();
});
