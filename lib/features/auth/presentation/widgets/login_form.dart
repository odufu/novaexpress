import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

final loginObscurePasswordProvider = StateProvider.autoDispose<bool>((ref) => true);
final loginRememberMeProvider = StateProvider.autoDispose<bool>((ref) => true);

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _QuickAccount {
  final String roleKey;
  final String title;
  final String personName;
  final String badge;
  final String email;
  final String password;
  final IconData icon;
  final Color themeColor;

  const _QuickAccount({
    required this.roleKey,
    required this.title,
    required this.personName,
    required this.badge,
    required this.email,
    required this.password,
    required this.icon,
    required this.themeColor,
  });
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _agentIdController = TextEditingController(text: 'dc.supervisor@novaexpress.ng');
  final _passwordController = TextEditingController(text: 'Password123!');
  String? _selectedDemoRole = 'dc_manager';

  static const List<_QuickAccount> _primaryAccounts = [
    _QuickAccount(
      roleKey: 'client',
      title: 'Novacare Client',
      personName: 'Dr. Chuka Okafor',
      badge: 'Merchant Portal',
      email: 'merchant@novacare.com',
      password: 'Password123!',
      icon: Icons.storefront_rounded,
      themeColor: Color(0xFF0D9488),
    ),
    _QuickAccount(
      roleKey: 'dc_manager',
      title: 'DC Supervisor',
      personName: 'Ahmed Bello',
      badge: 'Wuse Central Hub',
      email: 'dc.supervisor@novaexpress.ng',
      password: 'Password123!',
      icon: Icons.warehouse_rounded,
      themeColor: Color(0xFF1E3A8A),
    ),
    _QuickAccount(
      roleKey: 'rider',
      title: 'Field Rider (PDA)',
      personName: 'Emeka Rider',
      badge: 'PDA-7000 (Abuja)',
      email: 'rider.emeka@novaexpress.com',
      password: 'Password123!',
      icon: Icons.two_wheeler_rounded,
      themeColor: Color(0xFFEA580C),
    ),
  ];

  @override
  void dispose() {
    _agentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _quickFill(String roleKey, String email, String password) {
    setState(() {
      _selectedDemoRole = roleKey;
      _agentIdController.text = email;
      _passwordController.text = password;
    });
  }

  void _instantLogin(String roleKey, String email, String password) {
    _quickFill(roleKey, email, password);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submit();
    });
  }

  void _submit() async {
    debugPrint('[AUTH_UI] 🚀 Single unified login submitted. Running validation...');
    if (_formKey.currentState!.validate()) {
      final email = _agentIdController.text.trim();
      final password = _passwordController.text;
      final rememberMe = ref.read(loginRememberMeProvider);
      debugPrint('[AUTH_UI] 📝 Form valid. Dispatching login request for: "$email", RememberMe=$rememberMe');

      final success = await ref.read(authProvider.notifier).login(email, password);

      debugPrint('[AUTH_UI] 🎯 authProvider.login() completed -> success: $success');
      if (!success && mounted) {
        return;
      }

      if (success && mounted) {
        final authUser = ref.read(authProvider).user;
        if (authUser == null) return;

        debugPrint('[AUTH_UI] 🔑 User authenticated successfully: "${authUser.email}", Role: "${authUser.role}", Name: "${authUser.fullName}"');

        try {
          final targetRoute = authUser.homeConsoleRoute;
          debugPrint('[AUTH_UI] 🚀 Directing ${authUser.roleDescription} to designated console: $targetRoute');
          context.go(targetRoute);
        } catch (routerErr) {
          debugPrint('[AUTH_UI] ℹ️ Router navigation notice ($routerErr)');
        }
      }
    } else {
      debugPrint('[AUTH_UI] ⚠️ Form validation failed. Missing required fields.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final obscurePassword = ref.watch(loginObscurePasswordProvider);
    final rememberMe = ref.watch(loginRememberMeProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Operations Selector Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 15, color: Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'QUICK OPERATIONS SELECTOR',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '1-Tap Fill',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: _primaryAccounts.map((acc) {
                    final isSelected = _selectedDemoRole == acc.roleKey;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: isSelected
                            ? acc.themeColor.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () {
                            if (_selectedDemoRole == acc.roleKey) {
                              _instantLogin(acc.roleKey, acc.email, acc.password);
                            } else {
                              _quickFill(acc.roleKey, acc.email, acc.password);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? acc.themeColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: acc.themeColor.withValues(alpha: isSelected ? 0.18 : 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(acc.icon, size: 15, color: acc.themeColor),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            acc.title,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: acc.themeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              acc.badge,
                                              style: GoogleFonts.inter(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: acc.themeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '${acc.personName} • ${acc.email}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? acc.themeColor : const Color(0xFFCBD5E1),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 2),
                // Alternate Demos
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Alt:',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    _buildMiniChip(
                      label: 'client@novaexpress.ng',
                      roleKey: 'client_alt',
                      color: const Color(0xFF0D9488),
                      onTap: () => _quickFill('client', 'client@novaexpress.ng', 'Password123!'),
                    ),
                    _buildMiniChip(
                      label: 'emeka.rider@novaexpress.ng',
                      roleKey: 'rider_alt',
                      color: const Color(0xFFEA580C),
                      onTap: () => _quickFill('rider', 'emeka.rider@novaexpress.ng', 'Password123!'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Email / Agent ID Field
          const Text(
            'Account Email or Agent ID',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF181C1E),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _agentIdController,
            style: const TextStyle(color: Color(0xFF181C1E), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. name@novaexpress.ng or PDA-7000',
              hintStyle: const TextStyle(color: Color(0xFF75777E), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF64748B), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your account email or agent ID';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF181C1E),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: obscurePassword,
            style: const TextStyle(color: Color(0xFF181C1E), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: const TextStyle(color: Color(0xFF75777E), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {
                  ref.read(loginObscurePasswordProvider.notifier).state = !obscurePassword;
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your password';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Remember Me & Forgot Password Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: () {
                  ref.read(loginRememberMeProvider.notifier).state = !rememberMe;
                },
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: AppColors.orange,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          ref.read(loginRememberMeProvider.notifier).state = val ?? true;
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Remember me',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Single Unified Sign In Button
          Builder(
            builder: (context) {
              final selectedAcc = _primaryAccounts.where((a) => a.roleKey == _selectedDemoRole).firstOrNull;
              final btnColor = selectedAcc?.themeColor ?? const Color(0xFF0F172A);
              final btnTitle = selectedAcc != null ? 'Sign In as ${selectedAcc.title}' : 'Sign In to Assigned Workspace';

              return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: btnColor.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                btnTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip({
    required String label,
    required String roleKey,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedDemoRole == roleKey;
    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFCBD5E1),
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? color : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
