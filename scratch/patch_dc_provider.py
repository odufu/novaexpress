with open('lib/features/dc_console/presentation/providers/dc_console_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = """  void addDriver(DCFleetDriver driver) {
    final updated = [
      driver,
      ...state.drivers.where((d) => d.id != driver.id && d.driverCode != driver.driverCode && (driver.email.isEmpty || d.email != driver.email)),
    ];
    state = state.copyWith(drivers: updated);
    _storageService.cacheFleetDrivers(updated);
    _storageService.cacheDriverCompensationTerms(driver.driverCode, driver.toJson());
    if (driver.email.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(driver.email, driver.toJson());
    }
    if (driver.id.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(driver.id, driver.toJson());
    }
  }"""

replace1 = """  void addDriver(DCFleetDriver driver) {
    final authUser = _ref.read(authProvider).user;
    final isSuperAdmin = authUser != null && (authUser.isSuperAdmin || authUser.role == 'super_admin' || authUser.role == 'admin');
    final isGrandDcAdmin = state.isCurrentHubGrandDc || state.activeHub.isGrandDc;
    final canManageOtherDcs = isSuperAdmin || isGrandDcAdmin;

    final enforcedDcId = canManageOtherDcs
        ? (driver.distributionCenterId.isNotEmpty ? driver.distributionCenterId : state.activeHubId)
        : state.activeHubId;
    final effectiveDriver = driver.copyWith(distributionCenterId: enforcedDcId);

    final updated = [
      effectiveDriver,
      ...state.drivers.where((d) => d.id != effectiveDriver.id && d.driverCode != effectiveDriver.driverCode && (effectiveDriver.email.isEmpty || d.email != effectiveDriver.email)),
    ];
    state = state.copyWith(drivers: updated);
    _storageService.cacheFleetDrivers(updated);
    _storageService.cacheDriverCompensationTerms(effectiveDriver.driverCode, effectiveDriver.toJson());
    if (effectiveDriver.email.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(effectiveDriver.email, effectiveDriver.toJson());
    }
    if (effectiveDriver.id.isNotEmpty) {
      _storageService.cacheDriverCompensationTerms(effectiveDriver.id, effectiveDriver.toJson());
    }
  }"""

target2 = """    final cleanPhone = phone.trim();
    final cleanPass = password.trim();
    final targetDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : state.activeHubId;"""

replace2 = """    final cleanPhone = phone.trim();
    final cleanPass = password.trim();
    final authUser = _ref.read(authProvider).user;
    final isSuperAdmin = authUser != null && (authUser.isSuperAdmin || authUser.role == 'super_admin' || authUser.role == 'admin');
    final isGrandDcAdmin = state.isCurrentHubGrandDc || state.activeHub.isGrandDc;
    final canManageOtherDcs = isSuperAdmin || isGrandDcAdmin;

    final targetDcId = canManageOtherDcs
        ? ((distributionCenterId != null && distributionCenterId.isNotEmpty) ? distributionCenterId : state.activeHubId)
        : state.activeHubId;"""

content = content.replace(target1.replace('\r\n', '\n'), replace1.replace('\r\n', '\n'))
content = content.replace(target2.replace('\r\n', '\n'), replace2.replace('\r\n', '\n'))

with open('lib/features/dc_console/presentation/providers/dc_console_provider.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

print("Updated dc_console_provider.dart")

