import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  final initialUser = await bootstrapApp();
  runApp(
    ProviderScope(
      overrides: [
        if (initialUser != null)
          initialUserProvider.overrideWithValue(initialUser),
      ],
      child: const NovaXpressApp(),
    ),
  );
}
