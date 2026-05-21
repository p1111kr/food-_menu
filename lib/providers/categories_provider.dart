import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/category.dart';

const fallbackCategories = [
  Category(
    id: 'c1',
    title: 'Italian',
    color: Colors.purple,
    gradientStart: Colors.purple,
    gradientEnd: Color(0xFF6A1B9A),
    gradientStartHex: '#9c27b0',
    gradientEndHex: '#6a1b9a',
  ),
  Category(id: 'c2', title: 'Quick & easy', color: Colors.red),
  Category(id: 'c3', title: 'Ethiopian', color: Colors.lightGreen),
  Category(id: 'c4', title: 'German', color: Colors.amber),
  Category(id: 'c5', title: 'Light & Lovely', color: Colors.blue),
  Category(id: 'c6', title: 'Exotic', color: Colors.green),
  Category(id: 'c7', title: 'Breakfast', color: Colors.lightBlue),
  Category(id: 'c8', title: 'Asian', color: Colors.orange),
  Category(id: 'c9', title: 'French', color: Colors.pink),
  Category(id: 'c10', title: 'Summer', color: Colors.teal),
  Category(id: 'c11', title: 'My Meals', color: Colors.orange),
];

final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/categories'));

  if (response.statusCode == 200) {
    final List<dynamic> listData = json.decode(response.body);
    final categories = listData.map((item) => Category.fromJson(item)).toList();

    if (categories.isNotEmpty) {
      return categories;
    }
  }

  return fallbackCategories;
});
