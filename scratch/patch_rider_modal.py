with open('lib/features/dc_console/presentation/widgets/dc_onboard_rider_modal.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = """    final dcState = ref.read(dcConsoleProvider);
    final targetDcId = draftState.selectedDcId ?? dcState.activeHubId;
    final targetDc = dcState.distributionCenters.firstWhere(
      (dc) => dc.id == targetDcId,
      orElse: () => dcState.distributionCenters.isNotEmpty
          ? dcState.distributionCenters.first
          : defaultDistributionCenters.first,
    );"""

replace1 = """    final dcState = ref.read(dcConsoleProvider);
    final currentUser = ref.read(authProvider).user;
    final isSuperAdmin = currentUser != null && (currentUser.isSuperAdmin || currentUser.role == 'super_admin' || currentUser.role == 'admin');
    final isGrandDcAdmin = dcState.isCurrentHubGrandDc || (currentUser?.isDcManager == true && (currentUser?.distributionCenterId == '22222222-2222-4222-8222-222222222222' || dcState.activeHub.isGrandDc));
    final canManageOtherDcs = isSuperAdmin || isGrandDcAdmin;

    final targetDcId = canManageOtherDcs
        ? (draftState.selectedDcId ?? dcState.activeHubId)
        : dcState.activeHubId;
    final targetDc = dcState.distributionCenters.firstWhere(
      (dc) => dc.id == targetDcId,
      orElse: () => dcState.distributionCenters.isNotEmpty
          ? dcState.distributionCenters.first
          : defaultDistributionCenters.first,
    );"""

target2 = """          builder: (context) {
            final dcState = ref.watch(dcConsoleProvider);
            final dcs = dcState.distributionCenters.isNotEmpty
                ? dcState.distributionCenters
                : defaultDistributionCenters;
            final currentDcId = draftState.selectedDcId ?? dcState.activeHubId;
            final currentDc = dcs.firstWhere(
              (dc) => dc.id == currentDcId,
              orElse: () => dcs.first,
            );"""

replace2 = """          builder: (context) {
            final dcState = ref.watch(dcConsoleProvider);
            final currentUser = ref.watch(authProvider).user;
            final isSuperAdmin = currentUser != null && (currentUser.isSuperAdmin || currentUser.role == 'super_admin' || currentUser.role == 'admin');
            final isGrandDcAdmin = dcState.isCurrentHubGrandDc || (currentUser?.isDcManager == true && (currentUser?.distributionCenterId == '22222222-2222-4222-8222-222222222222' || dcState.activeHub.isGrandDc));
            final canManageOtherDcs = isSuperAdmin || isGrandDcAdmin;

            final dcs = dcState.distributionCenters.isNotEmpty
                ? dcState.distributionCenters
                : defaultDistributionCenters;
            final currentDcId = canManageOtherDcs
                ? (draftState.selectedDcId ?? dcState.activeHubId)
                : dcState.activeHubId;
            final currentDc = dcs.firstWhere(
              (dc) => dc.id == currentDcId,
              orElse: () => dcs.first,
            );"""

target3 = """                  DropdownButtonFormField<String>(
                    value: currentDc.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Parent Distribution Hub *'),
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: dcs.map((dc) {
                      return DropdownMenuItem<String>(
                        value: dc.id,
                        child: Text(
                            '${dc.name} (${dc.state}) - ${dc.coveredLgas.length} LGAs',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (newDcId) {
                      if (newDcId != null) {
                        final found = dcs.firstWhere((dc) => dc.id == newDcId);
                        ref.read(dcOnboardDraftProvider.notifier).setSelectedDc(
                              found.id,
                              found.state,
                              found.coveredLgas,
                            );
                      }
                    },
                  ),"""

replace3 = """                  if (canManageOtherDcs)
                    DropdownButtonFormField<String>(
                      value: currentDc.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Parent Distribution Hub *'),
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: dcs.map((dc) {
                        return DropdownMenuItem<String>(
                          value: dc.id,
                          child: Text(
                              '${dc.name} (${dc.state}) - ${dc.coveredLgas.length} LGAs',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (newDcId) {
                        if (newDcId != null) {
                          final found = dcs.firstWhere((dc) => dc.id == newDcId);
                          ref.read(dcOnboardDraftProvider.notifier).setSelectedDc(
                                found.id,
                                found.state,
                                found.coveredLgas,
                              );
                        }
                      },
                    )
                  else
                    Tooltip(
                      message: 'Riders are strictly assigned to your operational facility.',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${currentDc.name} (${currentDc.state}) • ${currentDc.code}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'LOCKED',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),"""

content = content.replace(target1.replace('\r\n', '\n'), replace1.replace('\r\n', '\n'))
content = content.replace(target2.replace('\r\n', '\n'), replace2.replace('\r\n', '\n'))
content = content.replace(target3.replace('\r\n', '\n'), replace3.replace('\r\n', '\n'))

with open('lib/features/dc_console/presentation/widgets/dc_onboard_rider_modal.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

print("Updated dc_onboard_rider_modal.dart")

