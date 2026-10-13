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

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _agentIdController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _agentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
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
