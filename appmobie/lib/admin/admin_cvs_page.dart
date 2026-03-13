import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// kDebugMode not used in this file
import 'package:flutter/material.dart';
import '../screens/create_cv_screen.dart';

class AdminCvsPage extends StatefulWidget {
  const AdminCvsPage({Key? key}) : super(key: key);

  @override
  State<AdminCvsPage> createState() => _AdminCvsPageState();
}

class _AdminCvsPageState extends State<AdminCvsPage> {
  bool _checking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  Future<void> _verifyAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _checking = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(user.uid)
          .get();
      setState(() {
        _isAdmin = doc.exists;
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text('Require login')));
    if (_checking)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAdmin)
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền quản trị')),
      );

    final stream = FirebaseFirestore.instance
        .collection('cvs')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin - CVs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Không có CV nào'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final owner = (data['ownerId'] ?? '').toString();
              final created = data['createdAt'];
              String createdAtText = '';
              if (created is Timestamp)
                createdAtText = created.toDate().toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['name'] ?? '(No name)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                owner,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                createdAtText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['summary'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // view full CV in dialog
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(data['name'] ?? '(No name)'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (data['summary'] != null)
                                          Text(data['summary']),
                                        const SizedBox(height: 8),
                                        Text('Owner: $owner'),
                                        if (createdAtText.isNotEmpty)
                                          Text('Created: $createdAtText'),
                                        const SizedBox(height: 12),
                                        Text('Full data:'),
                                        const SizedBox(height: 8),
                                        Text(data.toString()),
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
                            },
                            child: const Text('Xem'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateCvScreen(
                                    docId: d.id,
                                    initialData: data,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Sửa'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Xác nhận'),
                                  content: const Text('Xóa CV này?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              try {
                                await FirebaseFirestore.instance
                                    .collection('cvs')
                                    .doc(d.id)
                                    .delete();
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã xóa CV')),
                                  );
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi xóa: $e')),
                                  );
                              }
                            },
                            child: const Text(
                              'Xóa',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
