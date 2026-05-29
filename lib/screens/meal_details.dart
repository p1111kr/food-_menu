import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal.dart';
import '../providers/favorites.dart';
import '../providers/meals_provider.dart';
import '../repositories/supabase_meals_repository.dart';
import '../widgets/meal_image_provider.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteMeals = ref.watch(favoriteMealsProvider);
    final bool isFavorite = favoriteMeals.any((m) => m.id == meal.id);
    debugPrint(
        '[MealDetailScreen] build: meal.id=${meal.id} meal.title="${meal.title}" isPublic=${!meal.isPersonal}');
    debugPrint(
        '[MealDetailScreen] favoriteMeals count=${favoriteMeals.length}');
    debugPrint('[MealDetailScreen] isFavorite=$isFavorite');

    return Scaffold(
      appBar: AppBar(
        title: Text(meal.title),
        actions: [
          // DELETE FEATURE shown for personal meals based on scope not categories
          if (meal.isPersonal)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () async {
                final bool? confirm = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      'Delete Recipe',
                      style: TextStyle(color: Color.fromARGB(255, 134, 79, 76)),
                    ),
                    content: const Text(
                      'Are you sure you want to delete your creation?',
                      style: TextStyle(color: Color.fromARGB(255, 134, 79, 76)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final repository = SupabaseMealsRepository();
                  final userId = Supabase.instance.client.auth.currentUser?.id;

                  try {
                    debugPrint('[MealDetailScreen] delete personal meal start');
                    debugPrint('[MealDetailScreen] mealId: ${meal.id}');
                    debugPrint('[MealDetailScreen] userId: $userId');

                    await repository.deleteMeal(meal.id, 'personal');

                    debugPrint('[MealDetailScreen] delete success');

                    if (!context.mounted) return;

                    try {
                      debugPrint(
                          '[MealDetailScreen] invalidating mealsProvider');
                      ref.invalidate(mealsProvider);
                      await ref.read(mealsProvider.future);
                      debugPrint(
                          '[MealDetailScreen] mealsProvider refresh success');
                    } catch (error) {
                      debugPrint(
                          '[MealDetailScreen] mealsProvider refresh failed: $error');
                      ref.invalidate(mealsProvider);
                    }

                    if (!context.mounted) return;

                    Navigator.of(context).pop(); // Go back
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meal deleted.')),
                    );
                  } catch (error) {
                    debugPrint('[MealDetailScreen] delete failed: $error');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Could not delete meal: $error')),
                      );
                    }
                  }
                }
              },
            ),

          if (!meal.isPersonal)
            IconButton(
              color: Colors.white,
              onPressed: () async {
                debugPrint('\n=== FAVORITE BUTTON PRESSED ===');
                debugPrint(
                    'meal.id="${meal.id}" meal.title="${meal.title}" isPublic=${!meal.isPersonal}');
                debugPrint(
                    'isFavorite (captured at build) BEFORE toggle=$isFavorite');

                final wasAdded = await ref
                    .read(favoriteMealsProvider.notifier)
                    .toggleMealFavoriteStatus(meal);

                debugPrint(
                    'toggleMealFavoriteStatus returned: wasAdded=$wasAdded');
                debugPrint(
                    'This means the snackbar will show: "${wasAdded ? "Meal added as favorite" : "Meal removed"}"');

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      wasAdded ? 'Meal added as favorite' : 'Meal removed',
                    ),
                  ),
                );
                debugPrint('=== FAVORITE BUTTON DONE ===\n');
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween(begin: 0.8, end: 1.0).animate(animation),
                  child: child,
                ),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  key: ValueKey(isFavorite),
                  color: isFavorite ? Colors.amber : Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: meal.id,
              child: Image(
                image: mealImageProvider(meal.imageUrl),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),
            for (final ingredient in meal.ingredients)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  ingredient,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Steps',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),
            for (final step in meal.steps)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  step,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
