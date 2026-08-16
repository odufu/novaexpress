import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/stock_repository.dart';

class StockState {
  final bool isLoading;
  final List<StockItemEntity> stockItems;
  final String? errorMessage;

  const StockState({
    this.isLoading = true,
    this.stockItems = const [],
    this.errorMessage,
  });

  int get totalUnitsHeld {
    return stockItems.fold(0, (sum, item) => sum + item.quantityHeld);
  }

  StockState copyWith({
    bool? isLoading,
    List<StockItemEntity>? stockItems,
    String? errorMessage,
  }) {
    return StockState(
      isLoading: isLoading ?? this.isLoading,
      stockItems: stockItems ?? this.stockItems,
      errorMessage: errorMessage,
    );
  }
}

class StockNotifier extends StateNotifier<StockState> {
  final StockRepository repository;

  StockNotifier({required this.repository}) : super(const StockState()) {
    fetchStockItems();
  }

  Future<void> fetchStockItems() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await repository.getVehicleStockItems();
      state = state.copyWith(isLoading: false, stockItems: items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sync vehicle stock.',
      );
    }
  }
}

final stockRemoteDataSourceProvider = Provider<StockRemoteDataSource>((ref) {
  return StockRemoteDataSourceImpl(
    supabaseClient: Supabase.instance.client,
  );
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  final remote = ref.watch(stockRemoteDataSourceProvider);
  return StockRepositoryImpl(remoteDataSource: remote);
});

final stockProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  final repo = ref.watch(stockRepositoryProvider);
  return StockNotifier(repository: repo);
});
