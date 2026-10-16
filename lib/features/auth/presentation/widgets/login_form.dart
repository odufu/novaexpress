import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

final loginObscurePasswordProvider = StateProvider.autoDispose<bool>((ref) => true);
final loginRememberMeProvider = StateProvider.autoDispose<bool>((ref) => true);

class _DevAccountOption {
  final String name;
  final String code;
  final String roleBadge;
  final String email;
  final String password;
  final String portalRoute;
  final IconData icon;
  final Color roleColor;

  const _DevAccountOption({
    required this.name,
    required this.code,
    required this.roleBadge,
    required this.email,
    required this.password,
    required this.portalRoute,
    required this.icon,
    required this.roleColor,
  });
}

const List<_DevAccountOption> _devTestAccounts = [
  _DevAccountOption(
    name: 'Novacare Merchant',
    code: 'CLIENT-NOVACARE',
    roleBadge: 'MERCHANT',
    email: 'novacare@novaxpress.net',
    password: 'novacare@novaxpress.net',
    portalRoute: '/client (Finance & Logistics)',
    icon: Icons.storefront_rounded,
    roleColor: Color(0xFFD97706),
  ),
  _DevAccountOption(
    name: 'Prestige Godwin Uto',
    code: 'CLS-NOVA-106',
    roleBadge: 'CLOSER',
    email: 'prestige.godwin@novaxpress.net',
    password: 'Closer123!',
    portalRoute: '/closer (Shorp 11 Telesales)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
  ),
  _DevAccountOption(
    name: 'Ojo Modupeolami',
    code: 'CLS-NOVA-103',
    roleBadge: 'CLOSER',
    email: 'ojo.modupeolami@novaxpress.ng',
    password: 'ojo.modupeolami@novaxpress.ng',
    portalRoute: '/closer (Shorp 11 Telesales)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
  ),
  _DevAccountOption(
    name: 'Adewole Ibukun',
    code: 'CLS-NOVA-104',
    roleBadge: 'CLOSER',
    email: 'adewole.ibukun@novaxpress.ng',
    password: 'Closer123!',
    portalRoute: '/closer (Shorp 11 Telesales)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
  ),
  _DevAccountOption(
    name: 'Abigail Kooyon',
    code: 'OPS-WUSE-01-159',
    roleBadge: 'DC OPS',
    email: 'abigail.kooyon@novaxpress.net',
    password: 'CDV8pRxC#b',
    portalRoute: '/ops (Wuse Grand Central)',
    icon: Icons.warehouse_rounded,
    roleColor: Color(0xFF059669),
  ),
  _DevAccountOption(
    name: 'Oladele Omowaye',
    code: 'RDR-501',
    roleBadge: 'RIDER',
    email: 'oladele.omowaye@novaxpress.ng',
    password: 'omowaye123456',
    portalRoute: '/ (Rider PDA • PIN: 1234)',
    icon: Icons.two_wheeler_rounded,
    roleColor: Color(0xFF7C3AED),
  ),
];

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _agentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  _DevAccountOption? _selectedDevAccount;

  bool get _isDevMode =>
      kDebugMode ||
      SupabaseConstants.supabaseUrl.contains('hwyqqjilcifxajruusoa') ||
      !const bool.fromEnvironment('dart.vm.product');

  @override
  void dispose() {
    _agentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectDevAccount(_DevAccountOption account) {
    setState(() {
      _selectedDevAccount = account;
      _agentIdController.text = account.email;
      _passwordController.text = account.password;
    });
  }

  void _clearDevAccount() {
    setState(() {
      _selectedDevAccount = null;
      _agentIdController.clear();
      _passwordController.clear();
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

        debugPrint(
            '[AUTH_UI] 🔑 User authenticated successfully: "${authUser.email}", Role: "${authUser.role}", Name: "${authUser.fullName}"');

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
          // Development Fast-Login Dropdown
          if (_isDevMode) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDevAccount != null
                      ? _selectedDevAccount!.roleColor.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'DEV PILOT LOGIN',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Test Role Selector',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDevAccount != null)
                        InkWell(
                          onTap: _clearDevAccount,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 2),
                                Text(
                                  'Clear',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<_DevAccountOption>(
                    value: _selectedDevAccount,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    hint: Row(
                      children: [
                        const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Choose test role to auto-populate...',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      ),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return _devTestAccounts.map((acc) {
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: acc.roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                acc.roleBadge,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: acc.roleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${acc.name} (${acc.code})',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    items: _devTestAccounts.map((acc) {
                      return DropdownMenuItem<_DevAccountOption>(
                        value: acc,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: acc.roleColor.withValues(alpha: 0.12),
                                child: Icon(acc.icon, size: 16, color: acc.roleColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            acc.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: acc.roleColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            acc.roleBadge,
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: acc.roleColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc.email} • ${acc.portalRoute}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null) {
                        _selectDevAccount(selected);
                      }
                    },
                  ),
                  if (_selectedDevAccount != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filled: ${_selectedDevAccount!.email}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF059669),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedDevAccount!.roleColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: authState.isLoading ? null : _submit,
                          icon: const Icon(Icons.flash_on_rounded, size: 14),
                          label: Text(
                            'Quick Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

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
              hintText: 'e.g. name@novaxpress.ng or PDA-7000',
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.3),
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
                            'Sign In to Assigned Workspace',
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
          ),
        ],
      ),
    );
  }
}
