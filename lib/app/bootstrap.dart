import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';

Future<void> bootstrapApp() async {
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
}
