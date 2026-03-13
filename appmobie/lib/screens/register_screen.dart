import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtr = TextEditingController();
  final passCtr = TextEditingController();
  final pass2Ctr = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtr.dispose();
    passCtr.dispose();
    pass2Ctr.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (passCtr.text != pass2Ctr.text) {
      setState(() => error = 'Mật khẩu nhập lại không khớp');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthService.instance.register(
        email: emailCtr.text.trim(),
        password: passCtr.text,
      );
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
                    'Tạo tài khoản ✨',
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
                  const SizedBox(height: 12),
                  InputField(
                    controller: pass2Ctr,
                    hint: 'Nhập lại mật khẩu',
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  loading
                      ? const CircularProgressIndicator()
                      : PrimaryButton(label: 'Đăng ký', onPressed: _register),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, Routes.login),
                    child: const Text('Đã có tài khoản? Đăng nhập'),
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
