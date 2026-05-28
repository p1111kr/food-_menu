enum Complexity {
  simple,
  challenging,
  hard,
}

enum Affordability {
  affordable,
  pricey,
  luxurious,
}

class Meal {
  const Meal({
    required this.id,
    required this.categories,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.duration,
    required this.complexity,
    required this.affordability,
    required this.isGlutenFree,
    required this.isLactoseFree,
    required this.isVegan,
    required this.isVegetarian,
    this.scope,
    this.userId,
  });

  final String id;
  final List<String> categories;
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final int duration;
  final Complexity complexity;
  final Affordability affordability;
  final bool isGlutenFree;
  final bool isLactoseFree;
  final bool isVegan;
  final bool isVegetarian;
  final String? scope;
  final String? userId;

  bool get isPersonal => scope == 'personal';
  bool get isPublic => scope == 'public';

  // This is the essential Translator method
  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'].toString(),
      categories: List<String>.from(
        json['categories'] ?? [],
      ),
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      ingredients: List<String>.from(
        json['ingredients'] ?? [],
      ),
      steps: List<String>.from(
        json['steps'] ?? [],
      ),
      duration: json['duration'] ?? 0,
      complexity: Complexity.values.firstWhere(
        (e) => e.name == json['complexity'],
        orElse: () => Complexity.simple,
      ),
      affordability: Affordability.values.firstWhere(
        (e) => e.name == json['affordability'],
        orElse: () => Affordability.affordable,
      ),
      isGlutenFree: json['isGlutenFree'] ?? json['is_gluten_free'] ?? false,
      isLactoseFree: json['isLactoseFree'] ?? json['is_lactose_free'] ?? false,
      isVegan: json['isVegan'] ?? json['is_vegan'] ?? false,
      isVegetarian: json['isVegetarian'] ?? json['is_vegetarian'] ?? false,
      scope: json['scope'] as String?,
      userId: json['user_id'] as String?,
    );
  }
}
