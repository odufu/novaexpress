import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ProductsListPage extends StatelessWidget {
  const ProductsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDA Stock Products'),
      ),
      body: const Center(
        child: Text(
          'Products inventory ledger loaded from Supabase.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}
