import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryMealSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final categoryMealSearchProvider =
    NotifierProvider.autoDispose<CategoryMealSearchNotifier, String>(
  CategoryMealSearchNotifier.new,
);
