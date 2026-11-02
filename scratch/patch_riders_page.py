with open('lib/features/dc_console/presentation/pages/dc_riders_page.dart', 'r', encoding='utf-8') as f:
    code = f.read()

target1 = "final activeCount = dcDrivers.where((d) => d.isActive).length;"
repl1 = """final activeCount = dcDrivers.where((d) => d.isActive).length;
    final unavailableCount = dcDrivers.where((d) => d.isUnavailable).length;"""

target2 = "_buildFilterChip('Active ($activeCount)', 'active', dcState.fleetFilter, dcNotifier, color: const Color(0xFF10B981)),"
repl2 = """_buildFilterChip('Active ($activeCount)', 'active', dcState.fleetFilter, dcNotifier, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildFilterChip('Unavailable ($unavailableCount)', 'unavailable', dcState.fleetFilter, dcNotifier, color: const Color(0xFFEF4444)),"""

assert target1 in code, 'target1 not found'
assert target2 in code, 'target2 not found'

code = code.replace(target1, repl1, 1).replace(target2, repl2, 1)

with open('lib/features/dc_console/presentation/pages/dc_riders_page.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print('Successfully patched dc_riders_page.dart via scratch script')

