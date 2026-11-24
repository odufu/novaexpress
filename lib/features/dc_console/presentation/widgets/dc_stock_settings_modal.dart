import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../users/presentation/widgets/edit_profile_modal.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';

class DCStockSettingsModal extends ConsumerStatefulWidget {
  final int initialDcMinThreshold;
  final int initialRiderSafetyThreshold;
  final Map<String, int> initialProductThresholds;
  final Map<String, int> initialRiderProductThresholds;
  final Function({
    required int dcMinThreshold,
    required int riderSafetyThreshold,
    required Map<String, int> productThresholds,
    required Map<String, int> riderProductThresholds,
  }) onSaveSettings;

  const DCStockSettingsModal({
    super.key,
    required this.initialDcMinThreshold,
    required this.initialRiderSafetyThreshold,
    this.initialProductThresholds = const {},
    this.initialRiderProductThresholds = const {},
    required this.onSaveSettings,
  });

  static Future<void> show({
    required BuildContext context,
    required int initialDcMinThreshold,
    required int initialRiderSafetyThreshold,
    Map<String, int> initialProductThresholds = const {},
    Map<String, int> initialRiderProductThresholds = const {},
    required Function({
      required int dcMinThreshold,
      required int riderSafetyThreshold,
      required Map<String, int> productThresholds,
      required Map<String, int> riderProductThresholds,
    }) onSaveSettings,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
            child: DCStockSettingsModal(
              initialDcMinThreshold: initialDcMinThreshold,
              initialRiderSafetyThreshold: initialRiderSafetyThreshold,
              initialProductThresholds: initialProductThresholds,
              initialRiderProductThresholds: initialRiderProductThresholds,
              onSaveSettings: onSaveSettings,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: DCStockSettingsModal(
            initialDcMinThreshold: initialDcMinThreshold,
            initialRiderSafetyThreshold: initialRiderSafetyThreshold,
            initialProductThresholds: initialProductThresholds,
            initialRiderProductThresholds: initialRiderProductThresholds,
            onSaveSettings: onSaveSettings,
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<DCStockSettingsModal> createState() => _DCStockSettingsModalState();
}

class _DCStockSettingsModalState extends ConsumerState<DCStockSettingsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _dcMinCtrl;
  late TextEditingController _riderBufferCtrl;

  late Map<String, int> _productThresholds;
  late Map<String, int> _riderProductThresholds;

  // Form selections for new rules
  String? _selectedProductIdForDc;
  final TextEditingController _productDcMinCtrl = TextEditingController();

  String? _selectedRiderIdForRider;
  String? _selectedProductIdForRider;
  final TextEditingController _riderCustomMinCtrl = TextEditingController();

  // Notification switches
  bool _notifyDcLowStock = true;
  bool _notifyRiderLowStock = true;
  bool _notifyInboundManifest = true;
  bool _notifySpoilage = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _dcMinCtrl = TextEditingController(text: widget.initialDcMinThreshold.toString());
    _riderBufferCtrl = TextEditingController(text: widget.initialRiderSafetyThreshold.toString());
    _productThresholds = Map<String, int>.from(widget.initialProductThresholds);
    _riderProductThresholds = Map<String, int>.from(widget.initialRiderProductThresholds);
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifyDcLowStock = prefs.getBool('dc_notify_low_stock') ?? true;
        _notifyRiderLowStock = prefs.getBool('dc_notify_rider_low_stock') ?? true;
        _notifyInboundManifest = prefs.getBool('dc_notify_inbound') ?? true;
        _notifySpoilage = prefs.getBool('dc_notify_spoilage') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _saveNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dc_notify_low_stock', _notifyDcLowStock);
      await prefs.setBool('dc_notify_rider_low_stock', _notifyRiderLowStock);
      await prefs.setBool('dc_notify_inbound', _notifyInboundManifest);
      await prefs.setBool('dc_notify_spoilage', _notifySpoilage);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dcMinCtrl.dispose();
    _riderBufferCtrl.dispose();
    _productDcMinCtrl.dispose();
    _riderCustomMinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);

    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Deduplicated items
    final seenIds = <String>{};
    final uniqueProducts = stockState.stockItems.where((i) => seenIds.add(i.id)).toList();
    final seenDrivers = <String>{};
    final uniqueDrivers = dcState.drivers.where((d) => seenDrivers.add(d.id)).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Modal Handle Bar
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Keeper Settings',
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${dcState.activeHubName} • Operational Rules & Controls',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF0284C7),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0284C7),
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(icon: Icon(Icons.alarm_rounded, size: 16), text: 'Restock Rules'),
                Tab(icon: Icon(Icons.notifications_active_outlined, size: 16), text: 'Notifs & Audio'),
                Tab(icon: Icon(Icons.palette_outlined, size: 16), text: 'Theme & Mode'),
                Tab(icon: Icon(Icons.person_outline_rounded, size: 16), text: 'Profile'),
              ],
            ),

            const Divider(height: 1),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Restock Rules & Reminders
                  _buildRestockRulesTab(uniqueProducts, uniqueDrivers, isDark),

                  // Tab 2: Notifications & Sound
                  _buildNotificationsAudioTab(isDark),

                  // Tab 3: Appearance & Theme
                  _buildThemeTab(isDark),

                  // Tab 4: Profile
                  _buildProfileTab(user, dcState.activeHubName, isDark),
                ],
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _saveAndApplySettings,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Save & Apply Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: RESTOCK RULES & REMINDER SETTINGS
  // ==========================================
  Widget _buildRestockRulesTab(List<StockItemEntity> products, List<DCFleetDriver> drivers, bool isDark) {
    // Deduplicate lists by ID to ensure exactly one DropdownMenuItem per entry
    final uniqueProducts = <StockItemEntity>[];
    final seenProductIds = <String>{};
    for (final p in products) {
      if (seenProductIds.add(p.id)) uniqueProducts.add(p);
    }

    final uniqueDrivers = <DCFleetDriver>[];
    final seenDriverIds = <String>{};
    for (final d in drivers) {
      if (seenDriverIds.add(d.id)) uniqueDrivers.add(d);
    }

    // Safety checks for selected dropdown values
    final effectiveDcProductId = (_selectedProductIdForDc != null && uniqueProducts.any((p) => p.id == _selectedProductIdForDc))
        ? _selectedProductIdForDc
        : null;
    final effectiveRiderId = (_selectedRiderIdForRider != null && uniqueDrivers.any((d) => d.id == _selectedRiderIdForRider))
        ? _selectedRiderIdForRider
        : null;
    final effectiveRiderProductId = (_selectedProductIdForRider != null && uniqueProducts.any((p) => p.id == _selectedProductIdForRider))
        ? _selectedProductIdForRider
        : null;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // 2-Week Lead Time Advisory Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF37021).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF37021), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Merchant restock redistribution across covering states requires ~2 weeks lead time. Configuring minimum thresholds sends automatic advance notices to ensure continuous fulfillment.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF9A3412),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // SECTION 1: DC MAIN STORAGE RESTOCK REMINDER
        Text(
          '1. DC Main Storage Restock Threshold',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Default facility minimum units before restock warnings are dispatched to merchant & station keeper.',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dcMinCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Default Station Minimum (Units)',
            hintText: 'e.g. 50',
            prefixIcon: const Icon(Icons.warehouse_rounded, size: 18, color: Color(0xFF16A34A)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Product-Specific Threshold Overrides
        Text(
          'Custom Product Restock Overrides',
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Set a custom storage threshold for high-velocity or priority products.',
          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: effectiveDcProductId,
                isExpanded: true,
                hint: const Text('Select Product', style: TextStyle(fontSize: 11.5)),
                items: uniqueProducts
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedProductIdForDc = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _productDcMinCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Min Qty',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                if (_selectedProductIdForDc != null) {
                  final qty = int.tryParse(_productDcMinCtrl.text.trim()) ?? 20;
                  setState(() {
                    _productThresholds[_selectedProductIdForDc!] = qty;
                    _productDcMinCtrl.clear();
                  });
                }
              },
            ),
          ],
        ),

        // List of custom product thresholds
        if (_productThresholds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _productThresholds.entries.map((entry) {
              final prod = products.where((p) => p.id == entry.key).firstOrNull;
              final pName = prod?.name ?? 'Product #${entry.key.substring(0, 6)}';
              return Chip(
                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                label: Text(
                  '$pName: ≤ ${entry.value} units',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _productThresholds.remove(entry.key));
                },
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 14),

        // SECTION 2: RIDER RESTOCK REMINDERS
        Text(
          '2. Courier Restock Reminder Settings',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Default minimum custody before warning the rider & stock keeper to restock or rebalance.',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _riderBufferCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Default Courier Safety Buffer (Units)',
            hintText: 'e.g. 5',
            prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF0284C7)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Specific Rider + Specific Product Rule
        Text(
          'Specific Courier + Product Restock Rule',
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Set a dedicated alert trigger for a specific rider holding a specific product.',
          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: effectiveRiderId,
                    isExpanded: true,
                    hint: const Text('Select Courier', style: TextStyle(fontSize: 11.5)),
                    items: uniqueDrivers
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRiderIdForRider = val),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: effectiveRiderProductId,
                    isExpanded: true,
                    hint: const Text('Select Product', style: TextStyle(fontSize: 11.5)),
                    items: uniqueProducts
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedProductIdForRider = val),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _riderCustomMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Alert when rider reaches ≤ X units (e.g. 3)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_alert_rounded, size: 16),
                  label: const Text('Add Rule', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (_selectedRiderIdForRider != null && _selectedProductIdForRider != null) {
                      final key = '${_selectedRiderIdForRider}_$_selectedProductIdForRider';
                      final qty = int.tryParse(_riderCustomMinCtrl.text.trim()) ?? 3;
                      setState(() {
                        _riderProductThresholds[key] = qty;
                        _riderCustomMinCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        // List of custom rider-product rules
        if (_riderProductThresholds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _riderProductThresholds.entries.map((entry) {
              final parts = entry.key.split('_');
              final rId = parts.isNotEmpty ? parts[0] : '';
              final pId = parts.length > 1 ? parts[1] : '';
              final driver = drivers.where((d) => d.id == rId).firstOrNull;
              final prod = products.where((p) => p.id == pId).firstOrNull;
              final rName = driver?.name ?? 'Courier';
              final pName = prod?.name ?? 'Product';
              return Chip(
                backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
                label: Text(
                  '$rName • $pName: ≤ ${entry.value}u',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _riderProductThresholds.remove(entry.key));
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // TAB 2: NOTIFICATIONS & AUDIO SETTINGS
  // ==========================================
  Widget _buildNotificationsAudioTab(bool isDark) {
    final audioSettings = ref.watch(audioSettingsProvider);
    final audioNotifier = ref.read(audioSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Stock Keeper Notification Triggers',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Select which operational events produce immediate notifications.',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // DC Storage Restock Alerts
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('DC Storage Restock Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Notify when warehouse items drop below facility minimum', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _notifyDcLowStock,
          activeColor: const Color(0xFF0284C7),
          onChanged: (v) => setState(() => _notifyDcLowStock = v),
        ),
        const Divider(height: 1),

        // Courier Low Stock Alerts
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Courier Low-Stock Warnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Notify when any rider hits minimum safety buffer in the field', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _notifyRiderLowStock,
          activeColor: const Color(0xFF0284C7),
          onChanged: (v) => setState(() => _notifyRiderLowStock = v),
        ),
        const Divider(height: 1),

        // Inbound Shipments
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Inbound Manifest & Transfer Arrivals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Alert when consignments are scheduled or arrive at DC station', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _notifyInboundManifest,
          activeColor: const Color(0xFF0284C7),
          onChanged: (v) => setState(() => _notifyInboundManifest = v),
        ),
        const Divider(height: 1),

        // Spoilage & Damaged
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Spoiled & Damaged Stock Notices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Alert when defective or damaged items are returned by couriers', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _notifySpoilage,
          activeColor: const Color(0xFF0284C7),
          onChanged: (v) => setState(() => _notifySpoilage = v),
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 14),

        // Audio & Sound Settings
        Text(
          'Sound & Audio Effects',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Play Sound Effects', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Audible chime on restock alerts and stock receipts', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: audioSettings.soundEnabled,
          activeColor: const Color(0xFF0284C7),
          onChanged: (val) => audioNotifier.setSoundEnabled(val),
        ),

        if (audioSettings.soundEnabled) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, size: 18, color: Color(0xFF64748B)),
              Expanded(
                child: Slider(
                  value: audioSettings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (v) => audioNotifier.setVolume(v),
                ),
              ),
              const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF0284C7)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: const Text('Test Alert Chime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              audioNotifier.previewSound('soft_melody');
            },
          ),
        ],
      ],
    );
  }

  // ==========================================
  // TAB 3: APPEARANCE & THEME
  // ==========================================
  Widget _buildThemeTab(bool isDark) {
    final currentThemeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Display & Color Theme',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your preferred workspace appearance for daytime or warehouse conditions.',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),

        // Light Mode Option
        _buildThemeOptionTile(
          title: 'Light Theme',
          subtitle: 'Clean high-contrast layout for daytime and bright office desks',
          icon: Icons.light_mode_rounded,
          iconColor: const Color(0xFFF59E0B),
          isSelected: currentThemeMode == ThemeMode.light,
          onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Dark Mode Option
        _buildThemeOptionTile(
          title: 'Dark Theme',
          subtitle: 'Deep OLED palette for low-light warehouses and reduced eye strain',
          icon: Icons.dark_mode_rounded,
          iconColor: const Color(0xFF38BDF8),
          isSelected: currentThemeMode == ThemeMode.dark,
          onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // System Default Option
        _buildThemeOptionTile(
          title: 'System Automatic',
          subtitle: 'Follow device OS display schedule',
          icon: Icons.brightness_auto_rounded,
          iconColor: const Color(0xFF10B981),
          isSelected: currentThemeMode == ThemeMode.system,
          onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildThemeOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: PROFILE SETTINGS
  // ==========================================
  Widget _buildProfileTab(dynamic user, String activeHubName, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              UserAvatarWidget(
                avatarUrl: user?.avatarUrl,
                fullName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Stock Keeper',
                radius: 36,
                showBorder: true,
                borderColor: const Color(0xFF0284C7),
                borderWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                user?.fullName.isNotEmpty == true ? user!.fullName : 'Distribution Center Stock Keeper',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                user?.email ?? 'stockkeeper@novaxpress.ng',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DC Stock Controller • $activeHubName',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Station Phone & Info
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Phone: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(user?.phone ?? '+234 800 000 0000', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Assigned Hub: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Expanded(
                    child: Text(activeHubName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Edit Profile Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (user != null) {
                      EditProfileModal.show(context, user);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveAndApplySettings() async {
    final dcMin = int.tryParse(_dcMinCtrl.text.trim()) ?? 50;
    final rBuf = int.tryParse(_riderBufferCtrl.text.trim()) ?? 5;

    await _saveNotificationPreferences();

    widget.onSaveSettings(
      dcMinThreshold: dcMin,
      riderSafetyThreshold: rBuf,
      productThresholds: _productThresholds,
      riderProductThresholds: _riderProductThresholds,
    );

    Navigator.pop(context);

    // Audit and dispatch stock notifications if enabled
    if (_notifyDcLowStock || _notifyRiderLowStock) {
      final stockState = ref.read(stockProvider);
      final notifRepo = ref.read(notificationsRepositoryProvider);
      final activeHubName = ref.read(dcConsoleProvider).activeHubName;

      int lowDcProducts = 0;
      if (_notifyDcLowStock) {
        for (final item in stockState.stockItems) {
          final threshold = _productThresholds[item.id] ?? dcMin;
          if (item.availableCount <= threshold) {
            lowDcProducts++;
            await notifRepo.emitNotification(
              title: '⚠️ Restock Warning: ${item.name} (${item.availableCount} units left)',
              message: 'Station shelf at $activeHubName is below facility minimum of $threshold units. (2-week lead time). Requisition inbound stock from ${item.ownerName}.',
              category: 'stock',
              agentId: item.clientId,
            );
          }
        }
      }

      int lowRidersCount = 0;
      if (_notifyRiderLowStock) {
        for (final alloc in stockState.riderAllocations) {
          final customKey = '${alloc.riderId}_${alloc.productId}';
          final threshold = _riderProductThresholds[customKey] ?? rBuf;
          if (alloc.inCustodyUnits > 0 && alloc.inCustodyUnits <= threshold) {
            lowRidersCount++;
            await notifRepo.emitNotification(
              title: '⚠️ Courier Low Stock: ${alloc.riderName}',
              message: '${alloc.riderName} holds only ${alloc.inCustodyUnits} units of ${alloc.productName} (below safety buffer of $threshold units). Restock recommended.',
              category: 'stock',
            );
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Settings saved! Audit complete: $lowDcProducts low DC items, $lowRidersCount low couriers flagged.'),
          ),
        );
      }
    }
  }
}
