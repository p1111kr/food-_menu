import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meals/providers/filters_provider.dart';
import 'package:meals/providers/meals_provider.dart';
import 'package:meals/screens/meal_details.dart';
import 'package:meals/widgets/meal_item.dart';

import '../models/meal.dart';

class MealScreen extends ConsumerWidget {
  const MealScreen({
    super.key,
    this.title,
    this.meals,
    this.categoryId,
    this.showPersonalMeals = false,
  }) : assert(meals != null || categoryId != null);

  final String? title;
  final List<Meal>? meals;
  final String? categoryId;
  final bool showPersonalMeals;

  void selectMeal(BuildContext context, Meal meal) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => MealDetailScreen(
        meal: meal,
      ),
    ));
  }

  List<Meal> _filterMeals(List<Meal> meals, Map<Filter, bool> activeFilters) {
    debugPrint('[MealScreen._filterMeals] categoryId=$categoryId');
    debugPrint(
        '[MealScreen._filterMeals] total meals before filter=${meals.length}');

    final filtered = meals.where((meal) {
      if (categoryId != null) {
        final contains = meal.categories.contains(categoryId);
        if (!contains) {
          return false;
        }
      }
      if (activeFilters[Filter.glutenFree]! && !meal.isGlutenFree) {
        return false;
      }
      if (activeFilters[Filter.lactoseFree]! && !meal.isLactoseFree) {
        return false;
      }
      if (activeFilters[Filter.vegetarian]! && !meal.isVegetarian) {
        return false;
      }
      if (activeFilters[Filter.vegan]! && !meal.isVegan) {
        return false;
      }
      return true;
    }).toList();

    debugPrint(
        '[MealScreen._filterMeals] meals after filter=${filtered.length}');
    return filtered;
  }

  Widget _buildContent(BuildContext context, List<Meal> meals) {
    Widget content = Center(
      child: Text(
        'No meals available',
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );

    if (meals.isNotEmpty) {
      content = ListView.builder(
        itemCount: meals.length,
        itemBuilder: (context, index) => MealItem(
          meal: meals[index],
          onSelectMeal: (context, meal) {
            selectMeal(context, meal);
          },
        ),
      );
    }

    if (title == null) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title!),
      ),
      body: content,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If direct meals list provided
    if (categoryId == null) {
      return _buildContent(context, meals!);
    }

    debugPrint('[MealScreen.build] categoryId=$categoryId');

    final activeFilters = ref.watch(filtersProvider);

    // Combine public and personal meals for category based browsing
    // Personal meals with matching category UUIDs will appear alongside public ones
    final publicMealsAsync = ref.watch(allMealsProvider);
    final personalMealsAsync = ref.watch(mealsProvider);

    return personalMealsAsync.when(
      loading: () => Scaffold(
        appBar: title == null ? null : AppBar(title: Text(title!)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: title == null ? null : AppBar(title: Text(title!)),
        body: Center(
          child: Text(
            'Could not load meals: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      data: (personalMeals) {
        return publicMealsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error: $err')),
          data: (publicMeals) {
            // Merge public + personal meals, deduplicate by id
            final allIds = <String>{};
            final combined = <Meal>[];

            for (final meal in publicMeals) {
              if (allIds.add(meal.id)) {
                combined.add(meal);
              }
            }
            for (final meal in personalMeals) {
              if (allIds.add(meal.id)) {
                combined.add(meal);
              }
            }

            debugPrint(
                '[MealScreen.build] public=${publicMeals.length} personal=${personalMeals.length} combined=${combined.length}');

            // Filter by category and active dietary filters
            final filteredMeals = _filterMeals(combined, activeFilters);

            debugPrint(
                '[MealScreen.build] filtered=${filteredMeals.length} meals matching category=$categoryId');

            return _buildContent(context, filteredMeals);
          },
        );
      },
    );
  }
}
