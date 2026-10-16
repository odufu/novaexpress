import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/domain/entities/client_closer.dart';
import '../../../client_portal/domain/entities/client_marketer.dart';
import '../../../client_portal/presentation/providers/client_portal_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/order_conversation.dart';

enum ParticipantRole {
  closer,
  marketer,
  operations,
  rider,
  client,
  unknown,
}

class ChatUserProfileData {
  final String id;
  final String name;
  final String? code;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final ParticipantRole role;
  final String roleLabel;
  final Color roleColor;
  final String? location;
  final String? orderReference;
  final String? notes;

  const ChatUserProfileData({
    required this.id,
    required this.name,
    this.code,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.roleLabel,
    required this.roleColor,
    this.location,
    this.orderReference,
    this.notes,
  });
}

class ChatUserProfileCardModal extends ConsumerWidget {
  final ChatUserProfileData profile;
  final VoidCallback? onMention;

  const ChatUserProfileCardModal({
    super.key,
    required this.profile,
    this.onMention,
  });

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String tag,
    OrderConversationEntity? conversation,
    OrderEntity? order,
    void Function(String mentionText)? onMention,
  }) async {
    final resolved = _resolveProfileData(
      ref: ref,
      tag: tag,
      conv: conversation,
      order: order,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatUserProfileCardModal(
        profile: resolved,
        onMention: onMention != null
            ? () {
                Navigator.of(ctx).pop();
                final insertTag = resolved.code != null && resolved.code!.isNotEmpty
                    ? '@${resolved.code}'
                    : '@${resolved.name.split(' ').first}';
                onMention(insertTag);
              }
            : null,
      ),
    );
  }

  static ChatUserProfileData _resolveProfileData({
    required WidgetRef ref,
    required String tag,
    OrderConversationEntity? conv,
    OrderEntity? order,
  }) {
    final cleanTag = tag.replaceAll('@', '').trim().toLowerCase();
    final portalState = ref.read(clientPortalProvider);
    final authUser = ref.read(authProvider).user;

    // 1. Check Closer match
    ClientCloser? matchedCloser;
    for (final c in portalState.closers) {
      if (c.id == conv?.closerId ||
          c.fullName.toLowerCase().contains(cleanTag) ||
          c.closerCode.toLowerCase().contains(cleanTag) ||
          cleanTag.contains('closer') ||
          (conv?.closerName?.toLowerCase().contains(cleanTag) ?? false)) {
        matchedCloser = c;
        break;
      }
    }

    if (matchedCloser != null || cleanTag.contains('closer') || (conv?.closerName != null && conv!.closerName!.isNotEmpty && cleanTag.contains(conv.closerName!.toLowerCase()))) {
      final name = matchedCloser?.fullName ?? conv?.closerName ?? 'Telesales Closer';
      final code = matchedCloser?.closerCode ?? 'CLS-NOVA';
      final phone = matchedCloser?.phone ?? '0800-NOVA-CLOSER';
      final email = matchedCloser?.email;
      final avatar = matchedCloser?.avatarUrl ?? conv?.closerAvatarUrl;
      return ChatUserProfileData(
        id: matchedCloser?.id ?? conv?.closerId ?? 'closer-id',
        name: name,
        code: code,
        phone: phone,
        email: email,
        avatarUrl: avatar,
        role: ParticipantRole.closer,
        roleLabel: 'Sales Closer',
        roleColor: const Color(0xFF8B5CF6), // Purple
        location: 'Assigned Telesales Closer',
        orderReference: conv?.orderNumber ?? order?.orderNumber,
        notes: 'Closes customer phone confirmations and live dispatch orders.',
      );
    }

    // 2. Check Marketer match
    ClientMarketer? matchedMarketer;
    for (final m in portalState.marketers) {
      if (m.id == conv?.marketerId ||
          m.fullName.toLowerCase().contains(cleanTag) ||
          m.marketerCode.toLowerCase().contains(cleanTag) ||
          cleanTag.contains('marketer') ||
          (conv?.marketerName?.toLowerCase().contains(cleanTag) ?? false)) {
        matchedMarketer = m;
        break;
      }
    }

    if (matchedMarketer != null || cleanTag.contains('marketer') || (conv?.marketerName != null && conv!.marketerName!.isNotEmpty && cleanTag.contains(conv.marketerName!.toLowerCase()))) {
      final name = matchedMarketer?.fullName ?? conv?.marketerName ?? 'Digital Marketer';
      final code = matchedMarketer?.marketerCode ?? 'MKT-GROWTH';
      final phone = matchedMarketer?.phone ?? '0800-MKT-ADS';
      final email = matchedMarketer?.email;
      final avatar = matchedMarketer?.avatarUrl ?? conv?.marketerAvatarUrl;
      return ChatUserProfileData(
        id: matchedMarketer?.id ?? conv?.marketerId ?? 'marketer-id',
        name: name,
        code: code,
        phone: phone,
        email: email,
        avatarUrl: avatar,
        role: ParticipantRole.marketer,
        roleLabel: 'Digital Marketer',
        roleColor: const Color(0xFF10B981), // Emerald
        location: 'Meta / TikTok Media Buyer',
        orderReference: conv?.orderNumber ?? order?.orderNumber,
        notes: 'Generated landing page checkout form & incoming ad traffic.',
      );
    }

    // 3. Check Operations / DC match
    if (cleanTag.contains('operations') ||
        cleanTag.contains('dc') ||
        cleanTag.contains('manager') ||
        cleanTag.contains('abigail') ||
        cleanTag.contains('wuse') ||
        cleanTag.contains('garki')) {
      final dcName = conv?.distributionCenterName ?? order?.distributionCenterName ?? 'Wuse Grand Central Distribution Center';
      return ChatUserProfileData(
        id: conv?.distributionCenterId ?? 'dc-operations',
        name: 'DC Operations Control',
        code: 'OPS-WUSE-01',
        phone: '0812-400-3321',
        email: 'operations@novaxpress.net',
        avatarUrl: null,
        role: ParticipantRole.operations,
        roleLabel: 'DC Operations Officer',
        roleColor: const Color(0xFF6366F1), // Indigo
        location: dcName,
        orderReference: conv?.orderNumber ?? order?.orderNumber,
        notes: 'Manages physical warehouse intake, bin storage, and courier dispatch routing.',
      );
    }

    // 4. Check Rider / Courier match
    if (cleanTag.contains('rider') ||
        cleanTag.contains('courier') ||
        cleanTag.contains('driver') ||
        cleanTag.contains('agent') ||
        cleanTag.contains('musa') ||
        (conv?.deliveryAgentName != null && cleanTag.contains(conv!.deliveryAgentName!.toLowerCase()))) {
      final riderName = conv?.deliveryAgentName ?? order?.deliveryAgentName ?? 'Assigned Dispatch Courier';
      final riderPhone = order?.deliveryAgentPhone ?? '0809-555-RIDER';
      return ChatUserProfileData(
        id: conv?.deliveryAgentId ?? 'rider-agent-id',
        name: riderName,
        code: 'PDA-RIDER',
        phone: riderPhone,
        email: null,
        avatarUrl: null,
        role: ParticipantRole.rider,
        roleLabel: 'Dispatch Courier',
        roleColor: const Color(0xFFF59E0B), // Amber
        location: (order?.deliveryState != null && order!.deliveryState.isNotEmpty)
            ? '${order.deliveryCity}, ${order.deliveryState}'
            : 'Abuja Metro PDA Routing',
        orderReference: conv?.orderNumber ?? order?.orderNumber,
        notes: 'Equipped with PDA mobile terminal for cash collection and proof-of-delivery.',
      );
    }

    // 5. Check Client / Merchant match
    final clientName = conv?.clientName ?? portalState.clientProfile.companyName;
    return ChatUserProfileData(
      id: conv?.clientId ?? portalState.clientProfile.id,
      name: clientName.isNotEmpty ? clientName : (authUser?.clientCompanyName ?? 'Merchant Account'),
      code: portalState.clientProfile.code.isNotEmpty ? portalState.clientProfile.code : 'MERCHANT',
      phone: portalState.clientProfile.phone.isNotEmpty ? portalState.clientProfile.phone : (authUser?.phone ?? '0800-NOVACARE'),
      email: portalState.clientProfile.email.isNotEmpty ? portalState.clientProfile.email : authUser?.email,
      avatarUrl: portalState.clientProfile.logoUrl,
      role: ParticipantRole.client,
      roleLabel: 'Merchant Executive',
      roleColor: const Color(0xFF0D9488), // Teal
      location: portalState.clientProfile.address.isNotEmpty ? portalState.clientProfile.address : 'Corporate Head Office',
      orderReference: conv?.orderNumber ?? order?.orderNumber,
      notes: 'Merchant brand owner managing products, inventory batches, and settlements.',
    );
  }

  void _callNumber(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone $phone copied to clipboard!'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    }
  }

  void _launchWhatsApp(BuildContext context, String phone, String name) async {
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+234')) {
      clean = clean.substring(1);
    } else if (clean.startsWith('0')) {
      clean = '234${clean.substring(1)}';
    } else if (!clean.startsWith('234')) {
      clean = '234$clean';
    }

    final message = Uri.encodeComponent(
      'Hello $name, messaging regarding live order ${profile.orderReference ?? ''} on NoveXPS Pipeline.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WhatsApp number $phone copied to clipboard!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Organic Gradient Header Banner
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    profile.roleColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    profile.roleColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: profile.roleColor.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  // Avatar with status pulse ring
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatarWidget(
                        avatarUrl: profile.avatarUrl,
                        fullName: profile.name,
                        radius: 28,
                        backgroundColor: profile.roleColor.withValues(alpha: 0.2),
                        textColor: profile.roleColor,
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name & Role Tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: profile.roleColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile.roleLabel.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (profile.code != null && profile.code!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                profile.code!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Content Details List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Contact Details Strip
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    _buildInfoTile(
                      icon: Icons.phone_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'Phone Number',
                      value: profile.phone!,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        color: const Color(0xFF94A3B8),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: profile.phone!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Phone copied to clipboard!')),
                          );
                        },
                      ),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (profile.email != null && profile.email!.isNotEmpty) ...[
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Official Email',
                      value: profile.email!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (profile.location != null && profile.location!.isNotEmpty) ...[
                    _buildInfoTile(
                      icon: Icons.storefront_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Station / Assignment',
                      value: profile.location!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (profile.notes != null && profile.notes!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: profile.roleColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              profile.notes!,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            // Primary Quick Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Call button
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _callNumber(context, profile.phone!),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(
                          'Call Direct',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // WhatsApp button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _launchWhatsApp(context, profile.phone!, profile.name),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: Text(
                          'WhatsApp',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],

                  // Mention in chat button
                  if (onMention != null) ...[
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Tag in chat',
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: profile.roleColor.withValues(alpha: 0.15),
                          foregroundColor: profile.roleColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: profile.roleColor.withValues(alpha: 0.3)),
                          ),
                          elevation: 0,
                        ),
                        onPressed: onMention,
                        child: const Icon(Icons.alternate_email_rounded, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Widget? trailing,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
