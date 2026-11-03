with open('lib/features/dc_console/presentation/pages/dc_distribution_centers_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Initialize selectedCoveredStates
old_init = """    List<String> availableLgas = LocationLookupService.getLgasForState(selectedState);
    if (cityCtrl.text.isEmpty && availableLgas.isNotEmpty) {
      cityCtrl.text = availableLgas.first;
    }
    List<String> selectedLgas = existingDc != null && existingDc.operatingZones.isNotEmpty
        ? List<String>.from(existingDc.operatingZones)
        : (availableLgas.isNotEmpty ? List<String>.from(availableLgas) : ['Abuja Municipal (AMAC)']);"""

new_init = """    List<String> selectedCoveredStates = existingDc != null && existingDc.effectiveCoveredStates.isNotEmpty
        ? List<String>.from(existingDc.effectiveCoveredStates)
        : [selectedState];
    if (!selectedCoveredStates.contains(selectedState)) {
      selectedCoveredStates.insert(0, selectedState);
    }

    List<String> getAllAvailableLgas() {
      final all = <String>[];
      for (final st in selectedCoveredStates) {
        all.addAll(LocationLookupService.getLgasForState(st));
      }
      return all;
    }

    List<String> availableLgas = getAllAvailableLgas();
    if (cityCtrl.text.isEmpty && availableLgas.isNotEmpty) {
      cityCtrl.text = availableLgas.first;
    }
    List<String> selectedLgas = existingDc != null && existingDc.operatingZones.isNotEmpty
        ? List<String>.from(existingDc.operatingZones.where((z) => !z.startsWith('STATE:')))
        : (availableLgas.isNotEmpty ? List<String>.from(availableLgas) : ['Abuja Municipal (AMAC)']);"""

if old_init in content:
    content = content.replace(old_init, new_init, 1)

# 2. Update when primary state changes
old_state_change = """                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedState = val;
                                  availableLgas = LocationLookupService.getLgasForState(val);
                                  selectedLgas = List.from(availableLgas);
                                  cityCtrl.text = availableLgas.isNotEmpty ? availableLgas.first : val;
                                });
                              }
                            },"""

new_state_change = """                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedState = val;
                                  if (!selectedCoveredStates.contains(val)) {
                                    selectedCoveredStates.insert(0, val);
                                  }
                                  availableLgas = getAllAvailableLgas();
                                  cityCtrl.text = availableLgas.isNotEmpty ? availableLgas.first : val;
                                });
                              }
                            },"""

if old_state_change in content:
    content = content.replace(old_state_change, new_state_change, 1)

# 3. Add Multi-State Chips UI right below line 1567
target_row_end = """                        Expanded(
                          child: TextField(
                            controller: capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Storage Capacity (Units)',
                              hintText: 'e.g. 50000',
                            ),
                          ),
                        ),
                      ],
                    ),"""

new_multi_state_section = """                        Expanded(
                          child: TextField(
                            controller: capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Storage Capacity (Units)',
                              hintText: 'e.g. 50000',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Multi-State Regional Coverage Chips
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hub_rounded, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                'Covered States (Multi-State Delivery Coverage) *',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...selectedCoveredStates.map((st) {
                                final isPrimary = st == selectedState;
                                return Chip(
                                  backgroundColor: isPrimary ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  label: Text(
                                    isPrimary ? '$st (HQ)' : st,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPrimary ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  deleteIcon: isPrimary ? null : const Icon(Icons.close_rounded, size: 14),
                                  onDeleted: isPrimary ? null : () {
                                    setState(() {
                                      selectedCoveredStates.remove(st);
                                      availableLgas = getAllAvailableLgas();
                                      final stLgas = LocationLookupService.getLgasForState(st);
                                      selectedLgas.removeWhere((l) => stLgas.contains(l));
                                    });
                                  },
                                );
                              }),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 15, color: Color(0xFF2563EB)),
                                label: const Text('+ Add State', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                onPressed: () async {
                                  final unselectedStates = LocationLookupService.getAllStates()
                                      .where((s) => !selectedCoveredStates.contains(s))
                                      .toList();
                                  if (unselectedStates.isEmpty) return;
                                  final picked = await showDialog<String>(
                                    context: ctx,
                                    builder: (dCtx) => SimpleDialog(
                                      title: const Text('Add Covered State'),
                                      children: unselectedStates.map((s) {
                                        return SimpleDialogOption(
                                          onPressed: () => Navigator.pop(dCtx, s),
                                          child: Text(s),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      selectedCoveredStates.add(picked);
                                      availableLgas = getAllAvailableLgas();
                                      selectedLgas.addAll(LocationLookupService.getLgasForState(picked));
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),"""

assert target_row_end in content, 'target_row_end not found'
content = content.replace(target_row_end, new_multi_state_section, 1)

# 4. Update save handler to attach STATE: tags and coveredStates
old_save_zones = """                  final capacity = int.tryParse(capacityCtrl.text.replaceAll(',', '')) ?? 25000;
                  final zones = List<String>.from(selectedLgas);"""

new_save_zones = """                  final capacity = int.tryParse(capacityCtrl.text.replaceAll(',', '')) ?? 25000;
                  final zones = List<String>.from(selectedLgas);
                  for (final st in selectedCoveredStates) {
                    final tag = 'STATE:$st';
                    if (!zones.contains(tag)) {
                      zones.add(tag);
                    }
                  }"""

if old_save_zones in content:
    content = content.replace(old_save_zones, new_save_zones, 1)

old_updated_dc = """                          final updated = existingDc.copyWith(
                            name: name,
                            code: code,
                            state: selectedState,
                            city: city,
                            address: address,
                            contactPhone: phoneCtrl.text.trim(),
                            contactEmail: supEmail.isNotEmpty ? supEmail : emailCtrl.text.trim(),
                            managerName: managerCtrl.text.trim(),
                            isHub: isHub,
                            isActive: isActive,
                            storageCapacityUnits: capacity,
                            operatingZones: zones,
                            updatedAt: DateTime.now(),
                          );"""

new_updated_dc = """                          final updated = existingDc.copyWith(
                            name: name,
                            code: code,
                            state: selectedState,
                            coveredStates: selectedCoveredStates,
                            city: city,
                            address: address,
                            contactPhone: phoneCtrl.text.trim(),
                            contactEmail: supEmail.isNotEmpty ? supEmail : emailCtrl.text.trim(),
                            managerName: managerCtrl.text.trim(),
                            isHub: isHub,
                            isActive: isActive,
                            storageCapacityUnits: capacity,
                            operatingZones: zones,
                            updatedAt: DateTime.now(),
                          );"""

if old_updated_dc in content:
    content = content.replace(old_updated_dc, new_updated_dc, 1)

with open('lib/features/dc_console/presentation/pages/dc_distribution_centers_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('dc_distribution_centers_page.dart updated successfully!')
