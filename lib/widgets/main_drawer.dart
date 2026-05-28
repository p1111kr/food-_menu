import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meals/screens/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meals/providers/categories_provider.dart';
import 'package:meals/providers/meals_provider.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key, required this.onSelectScreen});

  final void Function(String identifier) onSelectScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          // Your existing Header
          DrawerHeader(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.fastfood,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 18),
                Text('Cooking Up!',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.restaurant, size: 26),
            title: const Text('Meals', style: TextStyle(fontSize: 24)),
            onTap: () => onSelectScreen('meals'),
          ),
          ListTile(
            leading: const Icon(Icons.settings, size: 26),
            title: const Text('Filters', style: TextStyle(fontSize: 24)),
            onTap: () => onSelectScreen('filters'),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear(); // this Clears UserID from phone memory

                  // This wipes the old users meals from the apps cache
                  ref.invalidate(categoriesProvider);
                  ref.invalidate(allMealsProvider);
                  ref.invalidate(mealsProvider);

                  if (!context.mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (ctx) => const AuthScreen()),
                    (route) => false,
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 124, 60, 26),
                  foregroundColor: const Color.fromARGB(255, 245, 210, 182),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Logout', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
