import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final editProfileAvatarUrlProvider = StateProvider.autoDispose<String?>((ref) => null);
final editProfileSavingProvider = StateProvider.autoDispose<bool>((ref) => false);
final editProfileUploadingPhotoProvider = StateProvider.autoDispose<bool>((ref) => false);

class EditProfileModal extends ConsumerStatefulWidget {
  final UserEntity user;
  final int initialTabIndex;

  const EditProfileModal({
    super.key,
    required this.user,
    this.initialTabIndex = 0,
  });

  static void show(BuildContext context, UserEntity user, {int initialTabIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditProfileModal(user: user, initialTabIndex: initialTabIndex),
      ),
    );
  }

  @override
  ConsumerState<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<EditProfileModal> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _stateController;
  late TextEditingController _cityController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _plateNoController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNoController;
  late TextEditingController _bankAccountNameController;

  static const List<String> nigerianBanks = [
    'Guaranty Trust Bank (GTBank)',
    'Access Bank',
    'First Bank of Nigeria',
    'Zenith Bank',
    'United Bank for Africa (UBA)',
    'Kuda Microfinance Bank',
    'Moniepoint Microfinance Bank',
    'OPay Digital Services',
    'Stanbic IBTC Bank',
    'Fidelity Bank',
    'First City Monument Bank (FCMB)',
    'Sterling Bank',
    'Union Bank of Nigeria',
    'Wema Bank / ALAT',
    'Palmpay',
  ];

  static const List<String> vehicleTypes = [
    'Motorcycle (Bajaj Boxer)',
    'Motorcycle (TVS HLX / Max)',
    'Electric Motorcycle',
    'Delivery Van / Mini Van',
    'Bicycle / E-Bike',
    'Sedan / Car',
  ];

  final List<Map<String, String>> _avatarPresets = [
    {
      'label': 'Rider Standard',
      'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=RiderStd',
    },
    {
      'label': 'Rider Pro',
      'url': 'https://api.dicebear.com/7.x/avataaars/png?seed=RiderPro',
    },
    {
      'label': 'Captain',
      'url': 'https://api.dicebear.com/7.x/personas/png?seed=RiderCaptain',
    },
    {
      'label': 'Executive',
      'url': 'https://api.dicebear.com/7.x/micah/png?seed=RiderExec',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 2));
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _stateController = TextEditingController(text: widget.user.operatingState);
    _cityController = TextEditingController(text: widget.user.operatingCity);
    _vehicleTypeController = TextEditingController(text: widget.user.vehicleType.isNotEmpty ? widget.user.vehicleType : 'Motorcycle (Bajaj Boxer)');
    _plateNoController = TextEditingController(text: widget.user.vehiclePlateNumber);
    _bankNameController = TextEditingController(text: widget.user.bankName.isNotEmpty ? widget.user.bankName : 'Guaranty Trust Bank (GTBank)');
    _bankAccountNoController = TextEditingController(text: widget.user.bankAccountNumber);
    _bankAccountNameController = TextEditingController(text: widget.user.bankAccountName.isNotEmpty ? widget.user.bankAccountName : '${widget.user.firstName} ${widget.user.lastName}'.trim());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editProfileAvatarUrlProvider.notifier).state = widget.user.avatarUrl;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _vehicleTypeController.dispose();
    _plateNoController.dispose();
    _bankNameController.dispose();
    _bankAccountNoController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      ref.read(editProfileUploadingPhotoProvider.notifier).state = true;

      final bytes = await pickedFile.readAsBytes();

      // 1. Client-Side Size Restriction: 5 MB Max
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ref.read(editProfileUploadingPhotoProvider.notifier).state = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFDC2626),
              content: Text('⚠️ Selected image exceeds the 5MB file size limit. Please choose a smaller photo.'),
            ),
          );
        }
        return;
      }

      // 2. MIME & Extension Restriction
      final ext = pickedFile.name.contains('.') ? pickedFile.name.split('.').last.toLowerCase() : 'jpg';
      final allowedExts = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      if (!allowedExts.contains(ext)) {
        if (mounted) {
          ref.read(editProfileUploadingPhotoProvider.notifier).state = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFDC2626),
              content: Text('⚠️ Unsupported image format. Only JPG, PNG, WEBP, and GIF are allowed.'),
            ),
          );
        }
        return;
      }

      final contentType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : (ext == 'gif' ? 'image/gif' : 'image/jpeg'));
      final fileName = 'avatar_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      String? uploadedUrl;

      // 3. Attempt upload to Supabase Storage 'avatars' bucket
      try {
        final client = Supabase.instance.client;
        await client.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
        uploadedUrl = client.storage.from('avatars').getPublicUrl(fileName);
        debugPrint('[EDIT_PROFILE] ✅ Uploaded avatar to Supabase Storage: $uploadedUrl');
      } catch (storageErr) {
        debugPrint('[EDIT_PROFILE] ℹ️ Storage bucket upload notice ($storageErr). Storing as encoded data URI.');
        // 4. Resilient data URI fallback so DP works on any device and connection
        uploadedUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
      }

      if (mounted) {
        ref.read(editProfileAvatarUrlProvider.notifier).state = uploadedUrl;
        ref.read(editProfileUploadingPhotoProvider.notifier).state = false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('✓ New photo chosen! Tap "Save Profile Changes" below to apply.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(editProfileUploadingPhotoProvider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to select photo: $e'),
          ),
        );
      }
    }
  }

  void _saveProfile(String? selectedAvatarUrl) async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(editProfileSavingProvider.notifier).state = true;

    final success = await ref.read(authProvider.notifier).updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          operatingState: _stateController.text.trim(),
          operatingCity: _cityController.text.trim(),
          vehicleType: _vehicleTypeController.text.trim(),
          vehiclePlateNumber: _plateNoController.text.trim(),
          bankName: _bankNameController.text.trim(),
          bankAccountNumber: _bankAccountNoController.text.trim(),
          bankAccountName: _bankAccountNameController.text.trim(),
          avatarUrl: selectedAvatarUrl,
        );

    if (mounted) {
      ref.read(editProfileSavingProvider.notifier).state = false;
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('✓ Profile details, Settlement Bank & DP successfully updated!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFDC2626),
            content: Text('Failed to save profile changes. Please try again.'),
          ),
        );
      }
    }
  }

  void _showAvatarOptionsSheet(BuildContext parentContext, String? selectedAvatarUrl) {
    final theme = Theme.of(parentContext);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Change Profile Photo',
                  style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Camera / Gallery Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.orange),
                      foregroundColor: AppColors.orange,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickAndUploadImage(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickAndUploadImage(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Preset Avatars Section
            Text(
              'Or Choose Preset 3D Avatar',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _avatarPresets.map((preset) {
                final isSelected = selectedAvatarUrl == preset['url'];
                return GestureDetector(
                  onTap: () {
                    ref.read(editProfileAvatarUrlProvider.notifier).state = preset['url'];
                    Navigator.pop(ctx);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.orange : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            preset['label']!.isNotEmpty ? preset['label']!.substring(0, 1) : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset['label']!,
                        style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Clear Photo Option
            if (selectedAvatarUrl != null)
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFBA1A1A)),
                  onPressed: () {
                    ref.read(editProfileAvatarUrlProvider.notifier).state = '';
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove Photo (Use Initials)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedAvatarUrl = ref.watch(editProfileAvatarUrlProvider);
    final isSaving = ref.watch(editProfileSavingProvider);
    final isUploadingPhoto = ref.watch(editProfileUploadingPhotoProvider);
    final displayName = '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.orange, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'EDIT RIDER PROFILE',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
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

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.orange,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            indicatorColor: AppColors.orange,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Personal', icon: Icon(Icons.person_outline_rounded, size: 18)),
              Tab(text: 'Settlement Bank', icon: Icon(Icons.account_balance_wallet_outlined, size: 18)),
              Tab(text: 'Vehicle & Fleet', icon: Icon(Icons.two_wheeler_rounded, size: 18)),
            ],
          ),
          const Divider(height: 1),

          // Scrollable Tab View
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Personal & Contact Info
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Picture (DP) Section
                        Center(
                          child: Stack(
                            children: [
                              UserAvatarWidget(
                                avatarUrl: selectedAvatarUrl,
                                fullName: displayName.isNotEmpty ? displayName : widget.user.fullName,
                                radius: 44,
                                showBorder: true,
                                borderColor: AppColors.orange,
                                borderWidth: 2.5,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: isUploadingPhoto ? null : () => _showAvatarOptionsSheet(context, selectedAvatarUrl),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.cardColor, width: 2),
                                    ),
                                    child: isUploadingPhoto
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tap camera icon to change DP or choose 3D avatar',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // First Name
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            prefixIcon: Icon(Icons.person_rounded, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Last name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Operating Region / State
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                decoration: const InputDecoration(
                                  labelText: 'State / Region',
                                  prefixIcon: Icon(Icons.map_rounded, size: 18),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'State is required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  labelText: 'City / Hub Hub',
                                  prefixIcon: Icon(Icons.location_city_rounded, size: 18),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Settlement Bank Account
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_rounded, color: Color(0xFF16A34A), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Payout earnings, milestone bonuses, and transport allowances will be settled directly to this account.',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF16A34A), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: nigerianBanks.contains(_bankNameController.text) ? _bankNameController.text : nigerianBanks.first,
                          decoration: const InputDecoration(
                            labelText: 'Receiving Bank',
                            prefixIcon: Icon(Icons.account_balance_rounded, size: 18),
                          ),
                          items: nigerianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _bankNameController.text = val;
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _bankAccountNoController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: '10-Digit Account Number',
                            prefixIcon: Icon(Icons.credit_card_rounded, size: 18),
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Account number is required';
                            if (v.trim().length != 10) return 'Account number must be 10 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _bankAccountNameController,
                          decoration: const InputDecoration(
                            labelText: 'Account Beneficiary Name',
                            prefixIcon: Icon(Icons.person_pin_outlined, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Account name is required' : null,
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Vehicle & Fleet License
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VEHICLE SPECIFICATIONS',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: vehicleTypes.contains(_vehicleTypeController.text) ? _vehicleTypeController.text : vehicleTypes.first,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Category',
                            prefixIcon: Icon(Icons.directions_bike_rounded, size: 18),
                          ),
                          items: vehicleTypes.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _vehicleTypeController.text = val;
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _plateNoController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Registration / Plate Number',
                            prefixIcon: Icon(Icons.subtitles_outlined, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Plate number is required' : null,
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Safety gear & fleet verification is logged in parent DC inventory.',
                                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Save Action Button Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSaving ? null : () => _saveProfile(selectedAvatarUrl),
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  isSaving ? 'SAVING PROFILE...' : 'SAVE PROFILE CHANGES',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
