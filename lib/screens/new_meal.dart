import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meals/models/meal.dart';
import 'package:meals/providers/meals_provider.dart';
import 'package:meals/repositories/supabase_meals_repository.dart';
import 'package:meals/services/supabase_storage_service.dart';

class NewMealScreen extends ConsumerStatefulWidget {
  const NewMealScreen({super.key});

  @override
  ConsumerState<NewMealScreen> createState() => _NewMealScreenState();
}

class _NewMealScreenState extends ConsumerState<NewMealScreen> {
  final _titleController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _durationController = TextEditingController();
  final _supabaseMealsRepository = SupabaseMealsRepository();
  final _supabaseStorageService = SupabaseStorageService();

  Uint8List? _webImage;
  File? _selectedImageFile;
  bool _isUploading = false;

  Complexity _selectedComplexity = Complexity.simple;
  Affordability _selectedAffordability = Affordability.affordable;

  bool _hasInteractedWithDuration = false;

  static const Color _fieldFillColor = Color(0xFF2A1A10);
  static const Color _labelColor = Color(0xFFFFB74D);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _webImage = bytes;
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _webImage = null;
      _selectedImageFile = null;
    });
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

  List<String> _missingRequiredFields(int? duration) {
    final missing = <String>[];

    if (_titleController.text.trim().isEmpty) missing.add('title');
    if (_selectedImageFile == null && _webImage == null) missing.add('image');
    if (_ingredientsController.text.trim().isEmpty) {
      missing.add('ingredients');
    }
    if (_stepsController.text.trim().isEmpty) missing.add('steps');
    if (duration == null || duration <= 0) {
      missing.add('duration (>0)');
    }

    return missing;
  }

  Future<void> _saveMeal() async {
    final duration = _parseDurationMinutes(_durationController.text);

    final missingFields = _missingRequiredFields(duration);

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Missing: ${missingFields.join(', ')}'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      debugPrint('[NewMealScreen] save personal meal start');
      final ingredientsList = _ingredientsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final stepsList = _stepsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();

      debugPrint('[NewMealScreen] image upload start');
      final imageUrl =
          await _supabaseStorageService.uploadMealImage(_selectedImageFile!);
      debugPrint('[NewMealScreen] image upload success imageUrl=$imageUrl');

      debugPrint(
          '[NewMealScreen] personal meal metadata: duration=$duration complexity=${_selectedComplexity.name} affordability=${_selectedAffordability.name}');

      final meal = Meal(
        id: '', // Supabase generates the UUID
        title: _titleController.text.trim(),
        imageUrl: imageUrl,
        categories: [],
        ingredients: ingredientsList,
        steps: stepsList,
        duration: duration!,
        complexity: _selectedComplexity,
        affordability: _selectedAffordability,
        isGlutenFree: true,
        isLactoseFree: true,
        isVegan: true,
        isVegetarian: true,
      );

      debugPrint('[NewMealScreen] meal insert start');
      await _supabaseMealsRepository.createPersonalMeal(meal);
      debugPrint('[NewMealScreen] meal insert success');

      try {
        debugPrint('[NewMealScreen] invalidating mealsProvider');
        ref.invalidate(mealsProvider);
        await ref.read(mealsProvider.future);
        debugPrint('[NewMealScreen] mealsProvider refetch success');
      } catch (error, stackTrace) {
        debugPrint('[NewMealScreen] mealsProvider refetch failed: $error');
        debugPrintStack(
          stackTrace: stackTrace,
          label: '[NewMealScreen] mealsProvider refetch stack',
        );
        ref.invalidate(mealsProvider);
      }

      if (!mounted) return;

      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe Added successfully!')),
      );
    } catch (error, stackTrace) {
      debugPrint('[NewMealScreen] save personal meal failed: $error');
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[NewMealScreen] save personal meal stack',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _ingredientsController.clear();
    _stepsController.clear();
    _durationController.clear();
    setState(() {
      _webImage = null;
      _selectedImageFile = null;
      _selectedComplexity = Complexity.simple;
      _selectedAffordability = Affordability.affordable;
      _hasInteractedWithDuration = false;
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _labelColor),
      floatingLabelStyle: const TextStyle(color: _labelColor),
      hintStyle: const TextStyle(color: _hintColor),
      filled: true,
      fillColor: _fieldFillColor,
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _labelColor, width: 1.5),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Your Recipe',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 20),

            // -- Title --
            TextField(
              controller: _titleController,
              style: const TextStyle(color: _textColor),
              cursorColor: _labelColor,
              decoration: _inputDecoration('Meal Title'),
            ),
            const SizedBox(height: 20),

            // -- Ingredients --
            TextField(
              controller: _ingredientsController,
              maxLines: 3,
              style: const TextStyle(color: _textColor),
              cursorColor: _labelColor,
              decoration: _inputDecoration('Ingredients (one per line)'),
            ),
            const SizedBox(height: 20),

            // -- Steps --
            TextField(
              controller: _stepsController,
              maxLines: 4,
              style: const TextStyle(color: _textColor),
              cursorColor: _labelColor,
              decoration: _inputDecoration('Cooking Steps (one per line)'),
            ),
            const SizedBox(height: 20),

            // Image picker
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(10)),
                  child: _webImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_webImage!, fit: BoxFit.cover))
                      : const Center(
                          child: Text('No image selected',
                              style: TextStyle(color: Colors.white70))),
                ),
                if (_webImage != null)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: IconButton(
                      onPressed: _removeImage,
                      icon:
                          const Icon(Icons.cancel, color: Colors.red, size: 30),
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image, color: _labelColor),
              label:
                  const Text('Add Image', style: TextStyle(color: _labelColor)),
            ),
            const SizedBox(height: 20),

            //  Duration
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: _textColor),
              cursorColor: _labelColor,
              decoration: _inputDecoration('Duration in minutes, e.g. 30'),
              onChanged: (_) {
                if (!_hasInteractedWithDuration) {
                  setState(() => _hasInteractedWithDuration = true);
                }
              },
            ),
            if (_hasInteractedWithDuration &&
                _durationController.text.isNotEmpty &&
                (_parseDurationMinutes(_durationController.text) == null ||
                    (_parseDurationMinutes(_durationController.text) ?? 0) <=
                        0))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'Please enter a valid duration greater than 0',
                  style: TextStyle(
                    color: Colors.redAccent.shade200,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Complexity dropdown
            DropdownButtonFormField<Complexity>(
              initialValue: _selectedComplexity,
              dropdownColor: _fieldFillColor,
              iconEnabledColor: _labelColor,
              menuMaxHeight: 200,
              isExpanded: true,
              style: const TextStyle(color: _textColor),
              decoration: _inputDecoration('Complexity'),
              items: const [
                DropdownMenuItem(
                  value: Complexity.simple,
                  child: Text('Simple', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: Complexity.challenging,
                  child:
                      Text('Challenging', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: Complexity.hard,
                  child: Text('Hard', style: TextStyle(color: _textColor)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedComplexity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            //  Affordability dropdown
            DropdownButtonFormField<Affordability>(
              initialValue: _selectedAffordability,
              dropdownColor: _fieldFillColor,
              iconEnabledColor: _labelColor,
              menuMaxHeight: 200,
              isExpanded: true,
              style: const TextStyle(color: _textColor),
              decoration: _inputDecoration('Affordability'),
              items: const [
                DropdownMenuItem(
                  value: Affordability.affordable,
                  child:
                      Text('Affordable', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: Affordability.pricey,
                  child: Text('Pricey', style: TextStyle(color: _textColor)),
                ),
                DropdownMenuItem(
                  value: Affordability.luxurious,
                  child: Text('Luxurious', style: TextStyle(color: _textColor)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAffordability = value;
                  });
                }
              },
            ),
            const SizedBox(height: 30),

            //  Submit button
            Center(
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveMeal,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _labelColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 15)),
                      child: const Text('Save Recipe',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
