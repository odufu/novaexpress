import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/dc_operations_officer.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_onboard_operations_officer_modal.dart';

class DCOperationsPage extends ConsumerStatefulWidget {
  const DCOperationsPage({super.key});

  @override
  ConsumerState<DCOperationsPage> createState() => _DCOperationsPageState();
}

class _DCOperationsPageState extends ConsumerState<DCOperationsPage> {
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendViaWhatsApp(DCOperationsOfficer officer, String dcName) async {
    final cleanPhone = officer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    String intlPhone = cleanPhone;
    if (intlPhone.startsWith('0')) {
      intlPhone = '234${intlPhone.substring(1)}';
    } else if (!intlPhone.startsWith('234')) {
      intlPhone = '234$intlPhone';
    }

    final message = '''*NovaXpress DC Operations Portal - Login Details*
----------------------------------------
Hello ${officer.name},
Your login details for the *NovaXpress DC Operations Portal* at *${dcName.isNotEmpty ? dcName : 'Assigned DC'}*:

📱 *Mobile Portal:* Access strictly from your phone browser or mobile app
👤 *Staff Code:* ${officer.staffCode}
📧 *Email:* ${officer.email}
🔑 *Password:* ${officer.rawPassword ?? 'Use your registered password'}
🏢 *Assigned DC:* $dcName

*Your Operations Scope:*
• View live incoming orders targeting this DC
• Route and dispatch orders to active delivery riders
• Reroute orders to other distribution centers

----------------------------------------
*NovaXpress Logistics Operations*''';

    final uri = Uri.parse(
        'https://wa.me/$intlPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _copyCredentials(DCOperationsOfficer officer, String dcName) {
    final text = '''NovaXpress DC Operations Officer Credentials
----------------------------------------
Officer Name: ${officer.name}
Staff Code: ${officer.staffCode}
Email: ${officer.email}
Password: ${officer.rawPassword ?? '(Registered Password)'}
Assigned DC: $dcName
Portal Route: /ops (Strictly Mobile)
Scope: Incoming Order Routing & Dispatch Only
----------------------------------------''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Credentials copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);

    // Officers for current DC
    var officers = dcState.dcOperationsOfficers;

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      officers = officers.where((o) =>
          o.name.toLowerCase().contains(query) ||
          o.email.toLowerCase().contains(query) ||
          o.phone.contains(query) ||
          o.staffCode.toLowerCase().contains(query)).toList();
    }

    // Filter by status
    if (_statusFilter == 'active') {
      officers = officers.where((o) => o.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      officers = officers.where((o) => !o.isActive).toList();
    }

    final totalOfficers = dcState.dcOperationsOfficers.length;
    final activeOfficers = dcState.dcOperationsOfficers.where((o) => o.isActive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final headerContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Color(0xFF0D9488),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DC Operations Department',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Strictly Mobile Dispatch & Live Routing Hub (${dcState.activeHubName})',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final onboardBtn = ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const DCOnboardOperationsOfficerModal(),
                  );
                },
                icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Onboard Operations Officer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerContent,
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: onboardBtn),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerContent),
                  const SizedBox(width: 14),
                  onboardBtn,
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Overview Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 950) {
                cardWidth = (constraints.maxWidth - 14) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 42) / 4;
              }

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      title: 'Operations Officers',
                      value: '$totalOfficers Staff',
                      subtext: '$activeOfficers active on duty',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF0D9488),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      title: 'Mobile Access Portal',
                      value: '/ops',
                      subtext: 'Strictly mobile interface',
                      icon: Icons.phone_android_rounded,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      title: 'Dispatch Scope',
                      value: dcState.activeHubCode,
                      subtext: dcState.activeHubName,
                      icon: Icons.hub_rounded,
                      color: const Color(0xFFF37021),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      title: 'Access Restriction',
                      value: 'Scoped to DC',
                      subtext: 'Zero access to other DCs/finance',
                      icon: Icons.security_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Search and Filters Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search operations officers by name, code, phone, or email...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0D9488)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter chips
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFilterChip('All ($totalOfficers)', 'all', isDark),
                    _buildFilterChip('Active ($activeOfficers)', 'active', isDark),
                    _buildFilterChip('Inactive (${totalOfficers - activeOfficers})', 'inactive', isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Officers Roster List
          if (officers.isEmpty)
            _buildEmptyState(isDark)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: officers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final officer = officers[index];
                return _buildOfficerCard(
                  officer: officer,
                  isDark: isDark,
                  dcName: dcState.activeHubName,
                  onToggleStatus: (val) async {
                    await dcNotifier.toggleOperationsOfficerStatus(officer.id, val);
                  },
                  onDelete: () => _confirmDeleteOfficer(officer),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF0D9488)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = value);
        }
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerCard({
    required DCOperationsOfficer officer,
    required bool isDark,
    required String dcName,
    required ValueChanged<bool> onToggleStatus,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          final avatarAndInfo = Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                child: Text(
                  officer.name.isNotEmpty ? officer.name[0].toUpperCase() : 'O',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            officer.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            officer.staffCode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: officer.isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            officer.isActive ? 'Active' : 'Disabled',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: officer.isActive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alternate_email_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              officer.email,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              officer.phone,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              officer.assignedZone ?? dcName,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Copy Credentials
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Login Details',
                onPressed: () => _copyCredentials(officer, dcName),
              ),
              // WhatsApp
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                tooltip: 'Send Login Details via WhatsApp',
                onPressed: () => _sendViaWhatsApp(officer, dcName),
              ),
              // Active toggle
              Switch.adaptive(
                value: officer.isActive,
                activeColor: const Color(0xFF0D9488),
                onChanged: onToggleStatus,
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Remove Officer',
                onPressed: onDelete,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatarAndInfo,
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [actionButtons],
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: avatarAndInfo),
              const SizedBox(width: 12),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteOfficer(DCOperationsOfficer officer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Operations Officer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${officer.name} (${officer.staffCode}) from the operations roster? They will lose access to the /ops mobile portal immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(dcConsoleProvider.notifier).deleteOperationsOfficer(officer.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${officer.name} from operations roster'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            child: const Text('Remove Officer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF0D9488),
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Operations Officers Onboarded Yet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Operations officers have strictly mobile access (/ops) to route incoming orders to riders and reroute orders across distribution centers.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DCOnboardOperationsOfficerModal(),
              );
            },
            icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Onboard First Operations Officer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
