import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal.dart';
import '../repositories/supabase_meals_repository.dart';

// Provider for the SupabaseMealsRepository to enable testability
final mealsRepositoryProvider =
    Provider<SupabaseMealsRepository>((ref) => SupabaseMealsRepository());

// Public meals from scope visible to everyone
final allMealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  final repository = ref.watch(mealsRepositoryProvider);
  final meals = await repository.fetchPublicMeals();
  debugPrint('[allMealsProvider] fetched ${meals.length} public meals');
  return meals;
});

// Personal meals owned by the authenticated user
final mealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  final repository = ref.watch(mealsRepositoryProvider);
  final meals = await repository.fetchPersonalMeals();
  debugPrint('[mealsProvider] fetched ${meals.length} personal meals');
  return meals;
});
