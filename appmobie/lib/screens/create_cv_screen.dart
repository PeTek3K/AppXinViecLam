import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateCvScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;
  const CreateCvScreen({Key? key, this.docId, this.initialData})
    : super(key: key);

  @override
  State<CreateCvScreen> createState() => _CreateCvScreenState();
}

class _CreateCvScreenState extends State<CreateCvScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  String _template = 'Basic';
  bool _saving = false;

  final List<String> _templates = ['Basic', 'Professional', 'Creative'];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nameCtrl.text = (d['name'] ?? '').toString();
      _emailCtrl.text = (d['email'] ?? '').toString();
      _phoneCtrl.text = (d['phone'] ?? '').toString();
      _summaryCtrl.text = (d['summary'] ?? '').toString();
      _template = (d['template'] ?? 'Basic').toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCv() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cần đăng nhập'),
          content: const Text(
            'Bạn cần đăng nhập trước khi lưu CV. Bạn muốn đến màn hình đăng nhập?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đến đăng nhập'),
            ),
          ],
        ),
      );
      if (goLogin == true) Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _saving = true);
    try {
      final col = FirebaseFirestore.instance.collection('cvs');
      final data = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
        'template': _template,
        'ownerId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        await col.doc(widget.docId).set(data, SetOptions(merge: true));
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu CV')));
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quyền bị từ chối'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Không thể lưu CV do Firestore rules chặn. Giải pháp:'),
                  SizedBox(height: 8),
                  Text('1) Đảm bảo người dùng đã đăng nhập.'),
                  SizedBox(height: 6),
                  Text(
                    '2) Cập nhật rules để cho phép user tạo/sửa CV của họ hoặc admin quản lý.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu CV: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu CV: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildPreview() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final summary = _summaryCtrl.text.trim();
    switch (_template) {
      case 'Professional':
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email + (phone.isNotEmpty ? ' • $phone' : ''),
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(),
                Text(summary),
              ],
            ),
          ),
        );
      case 'Creative':
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(summary),
              const SizedBox(height: 8),
              Text(
                email + (phone.isNotEmpty ? ' • $phone' : ''),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        );
      default:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(email),
                const SizedBox(height: 8),
                Text(summary),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId != null ? 'Sửa CV' : 'Tạo CV mới'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập email'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _template,
                items: _templates
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _template = v ?? 'Basic'),
                decoration: const InputDecoration(labelText: 'Mẫu CV'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tóm tắt/giới thiệu',
                ),
                maxLines: 5,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              const Text(
                'Xem trước',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPreview(),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _saveCv,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.docId != null ? 'Lưu thay đổi' : 'Lưu CV'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
