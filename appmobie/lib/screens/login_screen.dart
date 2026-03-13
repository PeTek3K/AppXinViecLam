import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtr = TextEditingController();
  final passCtr = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    // Gợi ý auto-fill email đã lưu
    AuthService.instance.getSavedEmail().then((v) {
      if (v != null) emailCtr.text = v;
    });
  }

  @override
  void dispose() {
    emailCtr.dispose();
    passCtr.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtr.text.trim(); // <-- lấy từ controller
    final password = passCtr.text; // <-- lấy từ controller

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthService.instance.login(email: email, password: password);
      // Điều hướng thay thế về màn có bottom nav
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back 👋',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  InputField(
                    controller: emailCtr,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  InputField(
                    controller: passCtr,
                    hint: 'Mật khẩu',
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  loading
                      ? const CircularProgressIndicator()
                      : PrimaryButton(label: 'Đăng nhập', onPressed: _login),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.resetPassword),
                    child: const Text('Quên mật khẩu?'),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.register),
                    child: const Text('Chưa có tài khoản? Đăng ký'),
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
