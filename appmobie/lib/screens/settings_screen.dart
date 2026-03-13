import 'package:appmobie/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../app.dart'; // để dùng themeModeNotifier

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService.instance.logout();
      // đóng dialog progress nếu còn mở, rồi clear stack và về login
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // đóng progress
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi đăng xuất: $e')));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy người dùng hiện tại.')),
      );
      return;
    }

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) {
          return AlertDialog(
            title: const Text('Đổi mật khẩu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState2(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      hintText: 'ít nhất 6 ký tự',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState2(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState2(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx2, true),
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    final current = currentCtrl.text.trim();
    final newPass = newCtrl.text;
    final confirm = confirmCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin.')),
      );
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 6 ký tự.')),
      );
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp.')),
      );
      return;
    }

    // show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      await user.reload();
      if (context.mounted)
        Navigator.of(context, rootNavigator: true).pop(); // close progress
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      String msg = 'Lỗi: ${e.code}';
      if (e.code == 'wrong-password') msg = 'Mật khẩu hiện tại không đúng.';
      if (e.code == 'requires-recent-login')
        msg = 'Vui lòng đăng nhập lại trước khi đổi mật khẩu.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      // nếu cần, force logout on requires-recent-login
      if (e.code == 'requires-recent-login') {
        // optional: prompt user to re-login
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi đổi mật khẩu: $e')));
    }
  }

  void _showAppInfo(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AppMobie',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(child: Text('A')),
      children: const [
        SizedBox(height: 8),
        Text('AppMobie - Ứng dụng Phân tích CV và định hướng nghề nghiệp.'),
        SizedBox(height: 8),
        Text(
          'Phiên bản này hiển thị danh sách việc làm, cho phép thêm công việc mẫu, thay đổi thông tin người dùng và quản lý tài khoản.',
        ),
        SizedBox(height: 8),
        Text('Liên hệ: support@appmobie.example'),
      ],
    );
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(user.uid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const SizedBox(height: 8),
        // --- Toggle Dark Mode ---
        ValueListenableBuilder(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) => SwitchListTile(
            title: const Text('Giao diện tối'),
            subtitle: Text(
              mode == ThemeMode.dark
                  ? 'Đang bật'
                  : mode == ThemeMode.light
                  ? 'Đang tắt'
                  : 'Theo hệ thống',
            ),
            value: mode == ThemeMode.dark,
            onChanged: (on) {
              themeModeNotifier.value = on ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ),
        const Divider(height: 24),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Đổi mật khẩu'),
          onTap: () => _changePassword(context),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Thông tin ứng dụng'),
          onTap: () => _showAppInfo(context),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('My CVs'),
          onTap: () => Navigator.pushNamed(context, Routes.myCvs),
        ),
        if (!kIsWeb)
          FutureBuilder<bool>(
            future: _isAdmin(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              if (!snap.data!) return const SizedBox();
              return ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin (quản trị)'),
                onTap: () => Navigator.pushNamed(context, Routes.admin),
              );
            },
          ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text(
            'Đăng xuất',
            style: TextStyle(color: Colors.redAccent),
          ),
          onTap: () => _logout(context),
        ),
      ],
    );
  }
}
