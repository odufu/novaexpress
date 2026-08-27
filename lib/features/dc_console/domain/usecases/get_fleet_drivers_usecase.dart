import '../entities/dc_fleet_driver.dart';
import '../../presentation/providers/dc_console_provider.dart';

class GetFleetDriversUseCase {
  final DCConsoleNotifier notifier;

  const GetFleetDriversUseCase(this.notifier);

  List<DCFleetDriver> call() {
    return notifier.drivers;
  }
}
