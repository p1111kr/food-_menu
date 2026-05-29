import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal.dart';

class SupabaseMealsRepository {
  final supabase = Supabase.instance.client;

  Future<void> _checkAdminRole(String userId) async {
    debugPrint('[SupabaseMealsRepository] checking admin role for $userId');
    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    debugPrint('[SupabaseMealsRepository] fetched profile: $profile');
    final role = profile?['role'] as String?;

    if (role != 'admin') {
      debugPrint('[SupabaseMealsRepository] admin check failed: role=$role');
      throw Exception('Admin access required for this operation.');
    }
    debugPrint('[SupabaseMealsRepository] admin check passed');
  }

  Future<List<Meal>> fetchPublicMeals() async {
    debugPrint(
        '[SupabaseMealsRepository.fetchPublicMeals] fetching public meals');

    final response = await supabase
        .from('meals')
        .select()
        .eq('scope', 'public')
        .order('created_at', ascending: false);

    final meals = response.map((item) {
      final meal = Meal.fromJson(item);
      debugPrint(
          '[SupabaseMealsRepository.fetchPublicMeals] meal="${meal.title}" scope=${meal.scope} categories=${meal.categories}');
      return meal;
    }).toList();

    debugPrint(
        '[SupabaseMealsRepository.fetchPublicMeals] fetched ${meals.length} public meals');
    return meals;
  }

  Future<List<Meal>> fetchPersonalMeals() async {
    final user = supabase.auth.currentUser;

    debugPrint(
        '[SupabaseMealsRepository.fetchPersonalMeals] authenticated user id=${user?.id}');

    if (user == null) {
      debugPrint(
          '[SupabaseMealsRepository.fetchPersonalMeals] no authenticated user, returning empty');
      return [];
    }

    final response = await supabase
        .from('meals')
        .select()
        .eq('user_id', user.id)
        .eq('scope', 'personal')
        .order('created_at', ascending: false);

    final meals = response.map((item) {
      final meal = Meal.fromJson(item);
      debugPrint(
          '[SupabaseMealsRepository.fetchPersonalMeals] meal="${meal.title}" scope=${meal.scope} userId=${meal.userId} categories=${meal.categories}');
      return meal;
    }).toList();

    debugPrint(
        '[SupabaseMealsRepository.fetchPersonalMeals] fetched ${meals.length} personal meals for user ${user.id}');
    return meals;
  }

  Future<void> createPersonalMeal(Meal meal) async {
    final user = supabase.auth.currentUser;

    debugPrint('[SupabaseMealsRepository] createPersonalMeal start');
    debugPrint('[SupabaseMealsRepository] authenticated user id=${user?.id}');
    debugPrint('[SupabaseMealsRepository] meal title=${meal.title}');
    debugPrint('[SupabaseMealsRepository] meal imageUrl=${meal.imageUrl}');

    if (user == null) {
      throw StateError('Cannot create a meal without an authenticated user.');
    }

    final payload = _buildPayload(meal, user.id, 'personal');
    debugPrint(
        '[SupabaseMealsRepository] createPersonalMeal payload keys: ${payload.keys.join(', ')}');

    try {
      await supabase.from('meals').insert(payload);
      debugPrint('[SupabaseMealsRepository] createPersonalMeal success');
    } catch (error, stackTrace) {
      debugPrint('[SupabaseMealsRepository] createPersonalMeal failed: $error');
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[SupabaseMealsRepository] createPersonalMeal stack',
      );
      rethrow;
    }
  }

  Future<void> createPublicMeal(Meal meal) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    debugPrint('[SupabaseMealsRepository] createPublicMeal start');
    debugPrint('[SupabaseMealsRepository] meal categories: ${meal.categories}');
    await _checkAdminRole(user.id);

    final payload = _buildPayload(meal, user.id, 'public');
    debugPrint(
        '[SupabaseMealsRepository] createPublicMeal payload categories: ${payload['categories']}');

    try {
      await supabase.from('meals').insert(payload);
      debugPrint('[SupabaseMealsRepository] createPublicMeal success');
    } catch (e, stackTrace) {
      debugPrint('[SupabaseMealsRepository] createPublicMeal failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateMeal(Meal meal, String scope) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    debugPrint('[SupabaseMealsRepository] updateMeal ($scope) id=${meal.id}');

    if (scope == 'public') {
      await _checkAdminRole(user.id);
    }

    final payload = _buildPayload(meal, user.id, scope);

    try {
      final query = supabase.from('meals').update(payload).eq('id', meal.id);
      // Safety check: users can only update their own personal meals
      if (scope == 'personal') {
        query.eq('user_id', user.id);
      }
      await query;
      debugPrint('[SupabaseMealsRepository] updateMeal success');
    } catch (e, stackTrace) {
      debugPrint('[SupabaseMealsRepository] updateMeal failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteMeal(String mealId, String scope) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot delete a meal without an authenticated user.');
    }

    debugPrint('[SupabaseMealsRepository] deleteMeal ($scope) id=$mealId');

    try {
      if (scope == 'public') {
        await _checkAdminRole(user.id);
        await supabase
            .from('meals')
            .delete()
            .eq('id', mealId)
            .eq('scope', 'public');
      } else {
        await supabase
            .from('meals')
            .delete()
            .eq('id', mealId)
            .eq('user_id', user.id)
            .eq('scope', 'personal');
      }

      debugPrint('[SupabaseMealsRepository] deleteMeal success');
    } catch (error, stackTrace) {
      debugPrint('[SupabaseMealsRepository] deleteMeal failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Map<String, dynamic> _buildPayload(Meal meal, String userId, String scope) {
    return {
      'user_id': userId,
      'title': meal.title,
      'image_url': meal.imageUrl,
      'categories': meal.categories,
      'ingredients': meal.ingredients,
      'steps': meal.steps,
      'duration': meal.duration,
      'complexity': meal.complexity.name,
      'affordability': meal.affordability.name,
      'is_gluten_free': meal.isGlutenFree,
      'is_lactose_free': meal.isLactoseFree,
      'is_vegan': meal.isVegan,
      'is_vegetarian': meal.isVegetarian,
      'scope': scope,
    };
  }
}
