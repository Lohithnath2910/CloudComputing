import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

enum AuthMode { login, signup }

enum UserRole { student, driver, admin }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthMode mode = AuthMode.login;
  UserRole role = UserRole.student;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String? errorMsg;

  Future<void> _submit() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    bool success = false;
    try {
      if (mode == AuthMode.login) {
        success = await ApiService.login(
          emailController.text,
          passwordController.text,
          role.name,
        );

        if (success) {
          // ✅ FIXED: Update FCM token after successful login
          final fcmToken = FcmService.fcmToken;
          if (fcmToken != null) {
            try {
              await ApiService.updateFcmToken(
                fcmToken,
                isDriver: role == UserRole.driver, // ✅ FIXED: Named parameter
              );
              debugPrint('FCM token updated successfully');
            } catch (e) {
              debugPrint('Failed to update FCM token: $e');
            }
          }

          // Navigate to appropriate dashboard based on role
          if (mounted) {
            if (role == UserRole.student) {
              Navigator.pushReplacementNamed(context, '/student');
            } else if (role == UserRole.driver) {
              Navigator.pushReplacementNamed(context, '/driver');
            } else {
              Navigator.pushReplacementNamed(context, '/admin');
            }
          }
        }
      } else if (role == UserRole.student) {
        success = await ApiService.signupStudent(
          nameController.text,
          emailController.text,
          passwordController.text,
        );
      } else {
        success = await ApiService.signupDriver(
          nameController.text,
          emailController.text,
          passwordController.text,
        );
      }

      if (!success) {
        setState(() {
          errorMsg = mode == AuthMode.signup
              ? 'Signup failed (email may already exist)'
              : 'Login failed (check credentials and role)';
        });
      }

      if (mode == AuthMode.signup && success) {
        setState(() {
          mode = AuthMode.login;
          errorMsg = 'Signup successful! Please login now.';
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = e.toString();
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = mode == AuthMode.signup;
    final isAdmin = role == UserRole.admin;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppColors.background),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Hero(
                        tag: 'app-logo-hero',
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.nfc_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'NFC Shuttle Pay',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clean operations for student, driver, and admin workflows.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<AuthMode>(
                            segments: const [
                              ButtonSegment(
                                value: AuthMode.login,
                                label: Text('Login'),
                                icon: Icon(Icons.login),
                              ),
                              ButtonSegment(
                                value: AuthMode.signup,
                                label: Text('Sign up'),
                                icon: Icon(Icons.person_add_alt_1),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (value) {
                              setState(() => mode = value.first);
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<UserRole>(
                            value: role,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: UserRole.student,
                                child: Text('Student'),
                              ),
                              DropdownMenuItem(
                                value: UserRole.driver,
                                child: Text('Bus Driver'),
                              ),
                              DropdownMenuItem(
                                value: UserRole.admin,
                                child: Text('Admin'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => role = val);
                              }
                            },
                          ),
                          if (isAdmin && isSignup) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'Admin signup is disabled. Use login only.',
                              ),
                            ),
                          ],
                          if (isSignup && !isAdmin) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (errorMsg != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                errorMsg!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: loading || (isAdmin && isSignup)
                                ? null
                                : _submit,
                            child: Text(
                              loading
                                  ? 'Please wait...'
                                  : (isSignup ? 'Sign up' : 'Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
