import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService({
    SupabaseClient? client,
  }) : supabase = client ?? Supabase.instance.client;

  final SupabaseClient supabase;

  Future<String> uploadMealImage(File imageFile) async {
    final user = supabase.auth.currentUser;

    debugPrint('[SupabaseStorageService] uploadMealImage start');
    debugPrint('[SupabaseStorageService] authenticated user id=${user?.id}');
    debugPrint('[SupabaseStorageService] local file path=${imageFile.path}');

    if (user == null) {
      throw StateError(
          'Cannot upload a meal image without an authenticated user.');
    }

    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final filePath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    debugPrint('[SupabaseStorageService] uploading to meal-images/$filePath');

    try {
      await supabase.storage.from('meal-images').upload(
            filePath,
            imageFile,
          );
    } catch (error, stackTrace) {
      debugPrint('[SupabaseStorageService] upload failed: $error');
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[SupabaseStorageService] upload stack',
      );
      rethrow;
    }

    final publicUrl =
        supabase.storage.from('meal-images').getPublicUrl(filePath);

    debugPrint('[SupabaseStorageService] upload success url=$publicUrl');

    return publicUrl;
  }
}
