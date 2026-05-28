import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meals/screens/category_screen.dart';
import 'package:meals/screens/meals.dart';
import 'package:meals/widgets/main_drawer.dart';
import 'package:meals/screens/filters.dart';
import 'package:meals/providers/filters_provider.dart';
import 'package:meals/providers/favorites.dart';
import 'package:meals/providers/meals_provider.dart';
import 'package:meals/screens/new_meal.dart';

class TabScreen extends ConsumerStatefulWidget {
  const TabScreen({super.key});

  @override
  ConsumerState<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends ConsumerState<TabScreen> {
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(favoriteMealsProvider.notifier).fetchAndSetFavorites();
      ref.read(filtersProvider.notifier).fetchAndSetFilters();
    });
  }

  void _selectPage(int index) {
    setState(() {
      _selectedPageIndex = index;
    });
  }

  void _setScreen(String identifier) async {
    Navigator.of(context).pop();
    if (identifier == 'filters') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => const FilterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget activePage = const CategoriesScreen();
    var activePageTitle = 'Categories';

    if (_selectedPageIndex == 1) {
      final favoriteMeals = ref.watch(favoriteMealsProvider);
      activePage = MealScreen(
        meals: favoriteMeals,
      );
      activePageTitle = 'Your Favorites';
    } else if (_selectedPageIndex == 2) {
      // "Your Meals" tab — shows personal meals owned by the authenticated user
      activePage = const _PersonalMealsWrapper();
      activePageTitle = 'Your Meals';
    } else if (_selectedPageIndex == 3) {
      activePage = const NewMealScreen();
      activePageTitle = 'Add New Recipe';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activePageTitle),
      ),
      drawer: MainDrawer(
        onSelectScreen: _setScreen,
      ),
      body: activePage,
      bottomNavigationBar: BottomNavigationBar(
        onTap: _selectPage,
        currentIndex: _selectedPageIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.set_meal),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Your Meals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Add Meal',
          ),
        ],
      ),
    );
  }
}

// Wraps the personal meals list with a Consumer for Riverpod access
class _PersonalMealsWrapper extends ConsumerWidget {
  const _PersonalMealsWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalMealsAsync = ref.watch(mealsProvider);

    return personalMealsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Could not load your meals: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (personalMeals) {
        debugPrint(
            '[PersonalMealsWrapper] loaded ${personalMeals.length} personal meals');
        return MealScreen(
          meals: personalMeals,
        );
      },
    );
  }
}
