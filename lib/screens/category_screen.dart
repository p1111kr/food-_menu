import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meals/models/category.dart';
import 'package:meals/providers/categories_provider.dart';
import 'package:meals/providers/category_meal_search_provider.dart';
import 'package:meals/providers/meals_provider.dart';
import 'package:meals/screens/meals.dart';
import 'package:meals/widgets/meal_item.dart';
import '../widgets/category_grid_item.dart';
import '../models/meal.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0,
      upperBound: 1,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectedCategory(BuildContext context, Category category) {
    debugPrint(
        '[CategoriesScreen._selectedCategory] selected category UUID="${category.id}" title="${category.title}"');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => MealScreen(
          title: category.title,
          categoryId: category.id,
        ),
      ),
    );
  }

  List<Meal> _searchMeals(List<Meal> meals, String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return meals;
    }

    return meals.where((meal) {
      return meal.title.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final searchQuery = ref.watch(categoryMealSearchProvider);

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: searchQuery.trim().isEmpty
              ? categoriesAsync.when(
                  loading: () {
                    debugPrint('[CategoriesScreen] categories loading');
                    return const Center(child: CircularProgressIndicator());
                  },
                  error: (error, stackTrace) {
                    debugPrint('[CategoriesScreen] categories error: $error');
                    return Center(
                      child: Text(
                        'Failed to load categories: $error',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                  data: (categories) {
                    debugPrint(
                      '[CategoriesScreen] categories data count=${categories.length}',
                    );
                    if (categories.isEmpty) {
                      return const Center(
                        child: Text(
                          'No categories found. Please add categories in the Admin Dashboard.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return _buildGrid(categories);
                  },
                )
              : _buildSearchResults(searchQuery),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        key: const ValueKey('categories-meal-search-field'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        onChanged: (value) {
          ref.read(categoryMealSearchProvider.notifier).setQuery(value);
        },
        decoration: InputDecoration(
          hintText: 'Search meals...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    final mealsAsync = ref.watch(allMealsProvider);

    return mealsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Could not load meals: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
      data: (meals) {
        final matchingMeals = _searchMeals(meals, query);

        if (matchingMeals.isEmpty) {
          return Center(
            child: Text(
              'No meals found',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: matchingMeals.length,
          itemBuilder: (context, index) {
            return MealItem(
              meal: matchingMeals[index],
              onSelectMeal: (context, meal) {},
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(List<Category> categories) {
    return AnimatedBuilder(
      animation: _animationController,
      child: GridView(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3 / 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        children: [
          for (final category in categories)
            CategoryGridItem(
              category: category,
              onSelectCategory: () => _selectedCategory(context, category),
            )
        ],
      ),
      builder: (context, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: child,
      ),
    );
  }
}
