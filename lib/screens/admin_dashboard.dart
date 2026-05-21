import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/category.dart';
import '../models/meal.dart';
import '../providers/categories_provider.dart';
import '../providers/meals_provider.dart';
import '../screens/auth.dart';
import '../widgets/meal_image_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const _panelColor = Color(0xFF1F1408);
  static const _fieldFillColor = Color(0xFF2A1A10);
  static const _labelColor = Color(0xFFFFB74D);
  static const _textColor = Colors.white;
  static const _hintColor = Colors.white70;

  final _titleController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _durationController = TextEditingController();
  final _categoryTitleController = TextEditingController();
  final _gradientStartController = TextEditingController(text: '#ff9800');
  final _gradientEndController = TextEditingController(text: '#f57c00');

  List<Meal> _publicMeals = [];
  bool _isLoadingMeals = true;
  bool _isSavingMeal = false;
  bool _isSavingCategory = false;
  String? _editingMealId;
  String? _editingCategoryId;
  String? _selectedCategoryId;
  Uint8List? _pickedImage;
  String? _existingImageUrl;
  String _complexity = 'simple';
  String _affordability = 'affordable';
  bool _isGlutenFree = false;
  bool _isLactoseFree = false;
  bool _isVegan = false;
  bool _isVegetarian = false;

  @override
  void initState() {
    super.initState();
    _loadAdminMeals();
  }

  Future<Map<String, String>> _adminHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';

    return {
      'Content-Type': 'application/json',
      'user-id': userId,
    };
  }

  Future<void> _loadAdminMeals() async {
    setState(() => _isLoadingMeals = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/meals'),
        headers: await _adminHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> listData = json.decode(response.body);
        setState(() {
          _publicMeals = listData.map((item) => Meal.fromJson(item)).toList();
        });
      } else {
        _showMessage('Could not load public meals');
      }
    } catch (_) {
      _showMessage('Server connection failed');
    } finally {
      if (mounted) setState(() => _isLoadingMeals = false);
    }
  }

  List<String> _lines(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35,
      maxWidth: 900,
      maxHeight: 900,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImage = bytes;
        _existingImageUrl = null;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _existingImageUrl = null;
    });
  }

  String? _currentImageUrl() {
    if (_pickedImage != null) {
      return 'data:image/jpeg;base64,${base64Encode(_pickedImage!)}';
    }

    return _existingImageUrl;
  }

  int? _parseDurationMinutes(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final plainNumber = int.tryParse(trimmed);
    if (plainNumber != null) return plainNumber;

    final timeParts = trimmed.split(':');
    if (timeParts.length == 2) {
      final hours = int.tryParse(timeParts[0].trim());
      final minutes = int.tryParse(timeParts[1].trim());
      if (hours != null && minutes != null) {
        return (hours * 60) + minutes;
      }
    }

    final numberMatch = RegExp(r'\d+').firstMatch(trimmed);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(0)!);
    }

    return null;
  }

  List<String> _missingMealFields(int? duration, String? imageUrl) {
    final missing = <String>[];

    if (_titleController.text.trim().isEmpty) missing.add('title');
    if (imageUrl == null || imageUrl.trim().isEmpty) missing.add('image');
    if (_selectedCategoryId == null) missing.add('category');
    if (_lines(_ingredientsController).isEmpty) missing.add('ingredients');
    if (_lines(_stepsController).isEmpty) missing.add('steps');
    if (duration == null || duration <= 0) missing.add('duration');

    return missing;
  }

  Future<void> _saveMeal() async {
    final duration = _parseDurationMinutes(_durationController.text);
    final imageUrl = _currentImageUrl();
    final missingFields = _missingMealFields(duration, imageUrl);

    if (missingFields.isNotEmpty) {
      _showMessage('Missing: ${missingFields.join(', ')}');
      return;
    }

    setState(() => _isSavingMeal = true);

    final body = {
      'title': _titleController.text.trim(),
      'imageUrl': imageUrl,
      'categories': [_selectedCategoryId],
      'ingredients': _lines(_ingredientsController),
      'steps': _lines(_stepsController),
      'duration': duration,
      'complexity': _complexity,
      'affordability': _affordability,
      'isGlutenFree': _isGlutenFree,
      'isLactoseFree': _isLactoseFree,
      'isVegan': _isVegan,
      'isVegetarian': _isVegetarian,
    };

    try {
      final editingId = _editingMealId;
      final response = editingId == null
          ? await http.post(
              Uri.parse('${ApiConfig.baseUrl}/admin/meals'),
              headers: await _adminHeaders(),
              body: json.encode({
                ...body,
                'id': 'm${DateTime.now().millisecondsSinceEpoch}',
              }),
            )
          : await http.put(
              Uri.parse('${ApiConfig.baseUrl}/admin/meals/$editingId'),
              headers: await _adminHeaders(),
              body: json.encode(body),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _clearMealForm();
        ref.invalidate(allMealsProvider);
        await _loadAdminMeals();
        _showMessage(
            editingId == null ? 'Public meal created' : 'Meal updated');
      } else {
        final error = json.decode(response.body);
        final details = error['details']?.toString();
        _showMessage(
          details == null || details.isEmpty
              ? error['error'] ?? 'Could not save meal'
              : '${error['error']}: $details',
        );
      }
    } catch (_) {
      _showMessage('Server connection failed');
    } finally {
      if (mounted) setState(() => _isSavingMeal = false);
    }
  }

  void _editMeal(Meal meal) {
    setState(() {
      _editingMealId = meal.id;
      _titleController.text = meal.title;
      _existingImageUrl = meal.imageUrl;
      _pickedImage = null;
      _ingredientsController.text = meal.ingredients.join('\n');
      _stepsController.text = meal.steps.join('\n');
      _durationController.text = meal.duration.toString();
      _selectedCategoryId =
          meal.categories.isNotEmpty ? meal.categories.first : null;
      _complexity = meal.complexity.name;
      _affordability = meal.affordability.name;
      _isGlutenFree = meal.isGlutenFree;
      _isLactoseFree = meal.isLactoseFree;
      _isVegan = meal.isVegan;
      _isVegetarian = meal.isVegetarian;
    });
  }

  Future<void> _deleteMeal(Meal meal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete public meal?'),
        content: Text('Remove ${meal.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/admin/meals/${meal.id}'),
        headers: await _adminHeaders(),
      );

      if (response.statusCode == 200) {
        ref.invalidate(allMealsProvider);
        await _loadAdminMeals();
        _showMessage('Public meal deleted');
      } else {
        _showMessage('Could not delete meal');
      }
    } catch (_) {
      _showMessage('Server connection failed');
    }
  }

  Future<void> _saveCategory() async {
    if (_categoryTitleController.text.trim().isEmpty ||
        _gradientStartController.text.trim().isEmpty ||
        _gradientEndController.text.trim().isEmpty) {
      _showMessage('Fill in category title and gradient colors');
      return;
    }

    setState(() => _isSavingCategory = true);

    final body = {
      'title': _categoryTitleController.text.trim(),
      'gradientStart': _gradientStartController.text.trim(),
      'gradientEnd': _gradientEndController.text.trim(),
    };

    try {
      final editingId = _editingCategoryId;
      final response = editingId == null
          ? await http.post(
              Uri.parse('${ApiConfig.baseUrl}/admin/categories'),
              headers: await _adminHeaders(),
              body: json.encode({
                ...body,
                'id': 'c${DateTime.now().millisecondsSinceEpoch}',
              }),
            )
          : await http.put(
              Uri.parse('${ApiConfig.baseUrl}/admin/categories/$editingId'),
              headers: await _adminHeaders(),
              body: json.encode(body),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _clearCategoryForm();
        ref.invalidate(categoriesProvider);
        _showMessage(
            editingId == null ? 'Category created' : 'Category updated');
      } else {
        final error = json.decode(response.body);
        _showMessage(error['error'] ?? 'Could not save category');
      }
    } catch (_) {
      _showMessage('Server connection failed');
    } finally {
      if (mounted) setState(() => _isSavingCategory = false);
    }
  }

  void _editCategory(Category category) {
    setState(() {
      _editingCategoryId = category.id;
      _categoryTitleController.text = category.title;
      _gradientStartController.text = category.gradientStartHex ?? '#ff9800';
      _gradientEndController.text = category.gradientEndHex ?? '#f57c00';
    });
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/admin/categories/${category.id}'),
        headers: await _adminHeaders(),
      );

      if (response.statusCode == 200) {
        ref.invalidate(categoriesProvider);
        _showMessage('Category deleted');
      } else {
        final error = json.decode(response.body);
        _showMessage(error['error'] ?? 'Could not delete category');
      }
    } catch (_) {
      _showMessage('Server connection failed');
    }
  }

  void _clearMealForm() {
    setState(() {
      _editingMealId = null;
      _titleController.clear();
      _pickedImage = null;
      _existingImageUrl = null;
      _ingredientsController.clear();
      _stepsController.clear();
      _durationController.clear();
      _selectedCategoryId = null;
      _complexity = 'simple';
      _affordability = 'affordable';
      _isGlutenFree = false;
      _isLactoseFree = false;
      _isVegan = false;
      _isVegetarian = false;
    });
  }

  void _clearCategoryForm() {
    setState(() {
      _editingCategoryId = null;
      _categoryTitleController.clear();
      _gradientStartController.text = '#ff9800';
      _gradientEndController.text = '#f57c00';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _durationController.dispose();
    _categoryTitleController.dispose();
    _gradientStartController.dispose();
    _gradientEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _panelColor,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadAdminMeals,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Meals'),
              Tab(icon: Icon(Icons.edit), text: 'Meal Form'),
              Tab(icon: Icon(Icons.category), text: 'Categories'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMealsList(),
            categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _buildMealForm(fallbackCategories),
              data: _buildMealForm,
            ),
            categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  _buildCategories(fallbackCategories),
              data: _buildCategories,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsList() {
    if (_isLoadingMeals) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicMeals.isEmpty) {
      return const Center(child: Text('No public meals yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _publicMeals.length,
      itemBuilder: (context, index) {
        final meal = _publicMeals[index];

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image(
              image: mealImageProvider(meal.imageUrl),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
            ),
          ),
          title: Text(meal.title),
          subtitle: Text('${meal.duration} min - ${meal.complexity.name}'),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _editMeal(meal),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteMeal(meal),
                icon: const Icon(Icons.delete, color: Colors.redAccent),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealForm(List<Category> categories) {
    final publicCategories =
        categories.where((category) => category.id != 'c11').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingMealId == null ? 'Create Public Meal' : 'Edit Public Meal',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _field(_titleController, 'Title'),
          _buildImagePicker(),
          _formControl(
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              dropdownColor: _fieldFillColor,
              iconEnabledColor: _labelColor,
              menuMaxHeight: 280,
              isExpanded: true,
              style: const TextStyle(color: _textColor),
              decoration: _inputDecoration('Category'),
              items: [
                for (final category in publicCategories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(
                      category.title,
                      style: const TextStyle(color: _textColor),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
          ),
          _field(_ingredientsController, 'Ingredients, one per line', lines: 4),
          _field(_stepsController, 'Steps, one per line', lines: 5),
          _field(
            _durationController,
            'Duration in minutes, e.g. 15',
            keyboardType: TextInputType.text,
          ),
          _formControl(
            DropdownButtonFormField<String>(
              value: _complexity,
              dropdownColor: _fieldFillColor,
              iconEnabledColor: _labelColor,
              menuMaxHeight: 240,
              isExpanded: true,
              style: const TextStyle(color: _textColor),
              decoration: _inputDecoration('Complexity'),
              items: const [
                DropdownMenuItem(
                  value: 'simple',
                  child: Text('Simple', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: 'challenging',
                  child:
                      Text('Challenging', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: 'hard',
                  child: Text('Hard', style: TextStyle(color: _textColor)),
                ),
              ],
              onChanged: (value) => setState(() => _complexity = value!),
            ),
          ),
          _formControl(
            DropdownButtonFormField<String>(
              value: _affordability,
              dropdownColor: _fieldFillColor,
              iconEnabledColor: _labelColor,
              menuMaxHeight: 240,
              isExpanded: true,
              style: const TextStyle(color: _textColor),
              decoration: _inputDecoration('Affordability'),
              items: const [
                DropdownMenuItem(
                  value: 'affordable',
                  child:
                      Text('Affordable', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: 'pricey',
                  child: Text('Pricey', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: 'luxurious',
                  child: Text('Luxurious', style: TextStyle(color: _textColor)),
                ),
              ],
              onChanged: (value) => setState(() => _affordability = value!),
            ),
          ),
          const SizedBox(height: 8),
          _checkboxTile(
            value: _isGlutenFree,
            label: 'Gluten free',
            onChanged: (value) => setState(() => _isGlutenFree = value),
          ),
          _checkboxTile(
            value: _isLactoseFree,
            label: 'Lactose free',
            onChanged: (value) => setState(() => _isLactoseFree = value),
          ),
          _checkboxTile(
            value: _isVegan,
            label: 'Vegan',
            onChanged: (value) => setState(() => _isVegan = value),
          ),
          _checkboxTile(
            value: _isVegetarian,
            label: 'Vegetarian',
            onChanged: (value) => setState(() => _isVegetarian = value),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSavingMeal ? null : _saveMeal,
            icon: const Icon(Icons.save),
            label: Text(_editingMealId == null ? 'Create Meal' : 'Save Meal'),
          ),
          if (_editingMealId != null)
            TextButton(
              onPressed: _clearMealForm,
              child: const Text('Cancel edit'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories(List<Category> categories) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _editingCategoryId == null ? 'Create Category' : 'Edit Category',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _field(_categoryTitleController, 'Category title'),
        _field(_gradientStartController, 'Gradient start hex'),
        _field(_gradientEndController, 'Gradient end hex'),
        ElevatedButton.icon(
          onPressed: _isSavingCategory ? null : _saveCategory,
          icon: const Icon(Icons.save),
          label: Text(
            _editingCategoryId == null ? 'Create Category' : 'Save Category',
          ),
        ),
        if (_editingCategoryId != null)
          TextButton(
            onPressed: _clearCategoryForm,
            child: const Text('Cancel edit'),
          ),
        const SizedBox(height: 24),
        for (final category in categories)
          if (category.id != 'c11')
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [category.gradientStart, category.gradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.32),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: ListTile(
                  title: Text(
                    category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${category.id}  ${category.gradientStartHex ?? ''} ${category.gradientEndHex ?? ''}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        color: Colors.white,
                        onPressed: () => _editCategory(category),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        color: Colors.redAccent,
                        onPressed: () => _deleteCategory(category),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildImagePicker() {
    Widget preview = const Center(
      child: Text(
        'No image selected',
        style: TextStyle(color: Colors.white70),
      ),
    );

    if (_pickedImage != null) {
      preview = Image.memory(_pickedImage!, fit: BoxFit.cover);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      preview = Image(
        image: mealImageProvider(_existingImageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined, color: Colors.white70),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 180,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                preview,
                if (_pickedImage != null || _existingImageUrl != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove image',
                      onPressed: _removeImage,
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: Text(_existingImageUrl == null && _pickedImage == null
                ? 'Add Image'
                : 'Change Image'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboardType,
        style: const TextStyle(color: _textColor),
        cursorColor: _labelColor,
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _formControl(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: child,
    );
  }

  Widget _checkboxTile({
    required bool value,
    required String label,
    required void Function(bool value) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _fieldFillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (newValue) => onChanged(newValue ?? false),
        activeColor: _labelColor,
        checkColor: Colors.black,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          label,
          style: const TextStyle(color: _textColor),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _labelColor),
      floatingLabelStyle: const TextStyle(color: _labelColor),
      hintStyle: const TextStyle(color: _hintColor),
      filled: true,
      fillColor: _fieldFillColor,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _labelColor, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
