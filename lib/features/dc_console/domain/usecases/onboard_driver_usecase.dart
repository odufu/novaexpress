import '../entities/dc_fleet_driver.dart';
import '../../presentation/providers/dc_console_provider.dart';

class OnboardDriverUseCase {
  final DCConsoleNotifier notifier;

  const OnboardDriverUseCase(this.notifier);

  void call(DCFleetDriver driver) {
    notifier.addDriver(driver);
  }
}
