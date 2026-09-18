import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../features/auth/data/models/user_model.dart';

Future<UserModel?> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[BOOTSTRAP] ⚠️ Supabase initialization timed out after 5s. Proceeding with offline fallback.');
        return Supabase.instance;
      },
    );
  } catch (e) {
    debugPrint('[BOOTSTRAP] ⚠️ Supabase initialization notice: $e. Proceeding with offline fallback.');
  }

  // Pre-warm cached user profile before widget tree mounts
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString('novexps_cache_user_profile');
    if (cachedStr != null && cachedStr.isNotEmpty) {
      final decoded = jsonDecode(cachedStr);
      if (decoded is Map<String, dynamic>) {
        final user = UserModel.fromJson(decoded);
        debugPrint('[BOOTSTRAP] ⚡ Pre-warmed active user: ${user.email} (Role: ${user.role})');
        return user;
      }
    }
  } catch (e) {
    debugPrint('[BOOTSTRAP] ℹ️ Error pre-warming user cache: $e');
  }

  return null;
}
