import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/client_marketer.dart';
import '../providers/client_portal_provider.dart';

class ClientEditMarketerProfileModal extends ConsumerStatefulWidget {
  final ClientMarketer? marketer;

  const ClientEditMarketerProfileModal({
    super.key,
    this.marketer,
  });

  static Future<void> show(BuildContext context, {ClientMarketer? marketer}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClientEditMarketerProfileModal(marketer: marketer),
      ),
    );
  }

  @override
  ConsumerState<ClientEditMarketerProfileModal> createState() =>
      _ClientEditMarketerProfileModalState();
}

class _ClientEditMarketerProfileModalState
    extends ConsumerState<ClientEditMarketerProfileModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;

  String? _selectedAvatarUrl;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  static const List<Map<String, String>> _avatarPresets = [
    {
      'label': 'Executive',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    },
    {
      'label': 'Strategist',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
    },
    {
      'label': 'Growth',
      'url': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=256&q=80',
    },
    {
      'label': 'Digital',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=256&q=80',
    },
    {
      'label': 'Performance',
      'url': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=256&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authProvider).user;
    final m = widget.marketer;

    final initialName = m?.fullName ?? authUser?.fullName ?? '';
    final initialPhone = m?.phone ?? authUser?.phone ?? '';
    final initialBank = m?.bankName ?? authUser?.bankName ?? '';
    final initialAccNum = m?.accountNumber ?? authUser?.bankAccountNumber ?? '';
    final initialAccName = m?.accountName ?? authUser?.bankAccountName ?? '';

    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: initialPhone);
    _bankNameController = TextEditingController(text: initialBank);
    _accountNumberController = TextEditingController(text: initialAccNum);
    _accountNameController = TextEditingController(text: initialAccName);

    _selectedAvatarUrl = m?.avatarUrl ?? authUser?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      Uint8List? bytes;
      String? ext;

      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          bytes = await pickedFile.readAsBytes();
          ext = pickedFile.name.contains('.')
              ? pickedFile.name.split('.').last.toLowerCase()
              : 'jpg';
        }
      } catch (e) {
        debugPrint('[MARKETER_PROFILE] Notice with ImagePicker: $e');
      }

      if (bytes == null || bytes.isEmpty) {
        final fileResult = await FilePickerPlatform.instance.pickFiles(type: FileType.image);
        if (fileResult.isNotEmpty) {
          final file = fileResult.first;
          bytes = await file.readAsBytes();
          ext = file.extension?.toLowerCase() ?? 'jpg';
        }
      }

      if (bytes == null || bytes.isEmpty) return;

      setState(() => _isUploadingPhoto = true);

      final cleanExt = ext ?? 'jpg';
      final contentType = cleanExt == 'png'
          ? 'image/png'
          : (cleanExt == 'webp'
              ? 'image/webp'
              : (cleanExt == 'gif' ? 'image/gif' : 'image/jpeg'));

      final authUser = ref.read(authProvider).user;
      final userId = widget.marketer?.userId ?? authUser?.id ?? 'marketer';

      final uploadedUrl = await SignatureStorageService.uploadAvatarImage(
        imageBytes: bytes,
        userId: userId,
        ext: cleanExt,
        contentType: contentType,
      );

      if (mounted) {
        setState(() {
          _selectedAvatarUrl = uploadedUrl;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text('✓ Profile photo uploaded! Tap "Save Changes" below to apply.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to upload image: $e'),
          ),
        );
      }
    }
  }

  void _showAvatarOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Profile Picture',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Take a photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF6366F1),
                  child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Choose from Photo Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              Text(
                'OR CHOOSE A PROFESSIONAL AVATAR',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _avatarPresets.map((p) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatarUrl = p['url']);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(p['url']!),
                        ),
                        const SizedBox(height: 4),
                        Text(p['label']!, style: GoogleFonts.inter(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = ref.read(authProvider).user;
    final marketerId = widget.marketer?.id ?? authUser?.marketerId ?? authUser?.id;

    if (marketerId == null || marketerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Unable to identify marketer account.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final bank = _bankNameController.text.trim();
      final accNum = _accountNumberController.text.trim();
      final accName = _accountNameController.text.trim();

      await ref.read(clientPortalProvider.notifier).updateMarketerProfile(
        marketerId: marketerId,
        fullName: name,
        phone: phone,
        avatarUrl: _selectedAvatarUrl,
        bankName: bank,
        accountNumber: accNum,
        accountName: accName,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Text('✓ Marketer Profile, DP & Settlement Bank updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to save profile: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Digital Marketer';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MARKETER PROFILE & DP',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Your profile picture displays on conversations for orders from your forms',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture (DP) Avatar Section
                    Center(
                      child: Stack(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: _selectedAvatarUrl,
                            fullName: displayName,
                            radius: 46,
                            showBorder: true,
                            borderColor: const Color(0xFF10B981),
                            borderWidth: 3,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _showAvatarOptionsSheet,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF111827) : Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isUploadingPhoto ? null : _showAvatarOptionsSheet,
                        icon: const Icon(Icons.photo_camera_back_outlined, size: 16, color: Color(0xFF10B981)),
                        label: Text(
                          'Change Profile Picture / Choose Avatar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section: Personal Details
                    Text(
                      'PERSONAL & CONTACT INFORMATION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 24),

                    // Section: Settlement Bank Details (Commission Payouts)
                    Text(
                      'COMMISSION SETTLEMENT BANK ACCOUNT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your earned lead and marketing commissions will be paid into this verified bank account.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g. Access Bank, Zenith, OPay',
                        prefixIcon: const Icon(Icons.account_balance_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Account Number',
                        hintText: '10-digit NUBAN number',
                        prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _accountNameController,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'Account Name as on Bank Record',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Save Marketer Profile Changes',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
