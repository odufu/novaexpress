import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../providers/stock_provider.dart';

class RequestStockPage extends ConsumerStatefulWidget {
  const RequestStockPage({super.key});

  @override
  ConsumerState<RequestStockPage> createState() => _RequestStockPageState();
}

class _RequestStockPageState extends ConsumerState<RequestStockPage> {
  int _currentStep = 0;
  String _selectedDC = 'Wuse Distribution Center';
  final Map<String, int> _requestedQuantities = {};

  final List<String> _distributionCenters = [
    'Wuse Distribution Center',
    'Garki Distribution Center',
    'Kubwa Distribution Center',
    'Ikeja Distribution Center',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final authState = ref.watch(authProvider);

    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? '${user.firstName} ${user.lastName}' : 'John Okafor';
    const agentId = 'PDA-0042';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _getStepTitle(),
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Row(
              children: [
                _buildStepIndicator(0, 'Select DC', isDark),
                _buildStepConnector(_currentStep >= 1, isDark),
                _buildStepIndicator(1, 'Products', isDark),
                _buildStepConnector(_currentStep >= 2, isDark),
                _buildStepIndicator(2, 'Review', isDark),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Step Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepBody(stockState, agentName, agentId, isDark),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _onNextPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _currentStep == 2 ? 'Submit Stock Request' : 'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Select Distribution Center';
      case 1:
        return 'Select Products & Quantity';
      case 2:
        return 'Review Stock Request';
      default:
        return 'Request Stock';
    }
  }

  Widget _buildStepIndicator(int stepIndex, String title, bool isDark) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? const Color(0xFF16A34A)
                : (isActive ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.primary : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isFilled, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        color: isFilled ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildStepBody(StockState stockState, String agentName, String agentId, bool isDark) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authorized Distribution Centers',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the hub you will physically collect restocked items from.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ..._distributionCenters.map((dc) {
              final isSelected = _selectedDC == dc;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedDC = dc),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEEF4FF))
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warehouse_rounded,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dc,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF2563EB) : null,
                                ),
                              ),
                              Text(
                                'Open 07:00 AM - 08:00 PM • Verified Hub',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Restock Quantities',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Fulfillment DC: $_selectedDC',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...stockState.stockItems.map((item) {
              final qty = _requestedQuantities[item.name] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.imageAsset != null
                              ? Image.asset(item.imageAsset!, fit: BoxFit.contain)
                              : const Icon(Icons.inventory_2_rounded, size: 24, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Owner: ${item.ownerName} • Current: ${item.availableCount} avail',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE11D48), size: 22),
                            onPressed: () {
                              if (qty > 0) {
                                setState(() => _requestedQuantities[item.name] = qty - 1);
                              }
                            },
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            alignment: Alignment.center,
                            child: Text(
                              '$qty',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
                            onPressed: () {
                              setState(() => _requestedQuantities[item.name] = qty + 1);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );

      case 2:
        final selectedItems = _requestedQuantities.entries.where((e) => e.value > 0).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  _buildReviewRow('Requester', '$agentId — $agentName', isDark),
                  const Divider(height: 16),
                  _buildReviewRow('Fulfillment DC', _selectedDC, isDark),
                  const Divider(height: 16),
                  _buildReviewRow('Request Date', 'Today (Instant Dispatch)', isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Requested Products (${selectedItems.length})',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (selectedItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48)),
                    SizedBox(width: 10),
                    Expanded(child: Text('No products selected. Please go back and select at least 1 unit.')),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = selectedItems[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.key, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            '+${item.value} Units',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF16A34A),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReviewRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _onNextPressed() {
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      final hasSelected = _requestedQuantities.values.any((qty) => qty > 0);
      if (!hasSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one item quantity to request.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Submit stock request
      final cleanQuantities = Map<String, int>.fromEntries(
        _requestedQuantities.entries.where((e) => e.value > 0),
      );

      final auth = ref.read(authProvider);
      final agentId = auth.user?.deliveryAgentId ?? auth.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
      final companyId = auth.user?.companyId ?? '11111111-1111-4111-8111-111111111111';

      ref.read(stockProvider.notifier).addStockRequest(
            dcName: _selectedDC,
            quantities: cleanQuantities,
          );

      // Call Edge Function
      ref.read(stockProvider.notifier).requestStockTransfer(
        agentId: agentId,
        companyId: companyId,
        sourceWarehouseId: '22222222-2222-4222-8222-222222222222',
        items: cleanQuantities.entries.map((e) => {
          'productId': e.key,
          'quantityRequested': e.value,
        }).toList(),
        notes: 'Restock request submitted to $_selectedDC',
      );

      ref.read(notificationsProvider.notifier).emitNotification(
            title: 'Stock Transfer Requested 🏷️',
            message: 'Inventory replenishment request submitted to $_selectedDC.',
            category: 'stock',
            actionRoute: '/orders/scan',
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock Request submitted successfully to $_selectedDC!',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      context.pop();
    }
  }
}
