import '../../presentation/providers/dc_console_provider.dart';

class GetWarehouseBatchesUseCase {
  final DCConsoleNotifier notifier;

  const GetWarehouseBatchesUseCase(this.notifier);

  List<DCWarehouseBatch> call() {
    return notifier.warehouseBatches;
  }
}
