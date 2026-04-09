import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

enum AuthMode { login, signup }
enum UserRole { student, driver }

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
              isDriver: role == UserRole.driver,  // ✅ FIXED: Named parameter
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
          } else {
            Navigator.pushReplacementNamed(context, '/driver');
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
    return Scaffold(
      appBar: AppBar(title: Text(isSignup ? 'Sign Up' : 'Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<UserRole>(
                    value: role,
                    items: const [
                      DropdownMenuItem(
                          value: UserRole.student, child: Text("Student")),
                      DropdownMenuItem(
                          value: UserRole.driver, child: Text("Bus Driver")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => role = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  ToggleButtons(
                    isSelected: [
                      mode == AuthMode.login,
                      mode == AuthMode.signup,
                    ],
                    children: const [Text("Login"), Text("Sign Up")],
                    onPressed: (idx) {
                      setState(() => mode = idx == 0 ? AuthMode.login : AuthMode.signup);
                    },
                  ),
                  if (isSignup) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: "Name"),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 20),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(errorMsg!,
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ElevatedButton(
                    onPressed: loading ? null : _submit,
                    child: Text(loading ? "Please wait..." : (isSignup ? "Sign Up" : "Login")),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
