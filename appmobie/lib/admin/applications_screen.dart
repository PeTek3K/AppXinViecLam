import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher_string.dart';
// import 'package:url_launcher/url_launcher.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final _col = FirebaseFirestore.instance.collection('JobApplications');

  Future<void> _updateStatus(String id, String status) async {
    await _col.doc(id).update({
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật trạng thái')));
    }
  }

  Future<void> _delete(String id) async {
    await _col.doc(id).delete();
    if (mounted) {
      }
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa hồ sơ')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text(
            'Yêu cầu ứng tuyển',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('createdAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có hồ sơ'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final d = docs[i];
                    final data = d.data();
                    final status = (data['status'] ?? 'new') as String;
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${data['jobTitle'] ?? '(Không tiêu đề)'} — ${data['jobCompany'] ?? ''}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Người nộp: ${data['applicantName'] ?? ''} (${data['applicantEmail'] ?? ''})',
                            ),
                            const SizedBox(height: 6),
                            Text(data['message'] ?? ''),
                            const SizedBox(height: 6),
                            if (data['cvUrl'] != null)
                              TextButton.icon(
                                icon: const Icon(Icons.download),
                                label: const Text('Tải CV'),
                                onPressed: () async {
                                  final url = data['cvUrl'] as String;
                                  // if image, show preview inline; otherwise offer in-app or external open
                                  final low = url.toLowerCase();
                                  try {
                                    if (low.endsWith('.png') ||
                                        low.endsWith('.jpg') ||
                                        low.endsWith('.jpeg') ||
                                        low.endsWith('.gif')) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          content: InteractiveViewer(
                                            child: Image.network(url),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Đóng'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                await launchUrlString(
                                                  url,
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                              },
                                              child: const Text('Mở ngoài'),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      // likely PDF or other document: open in-app webview or external
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Xem CV'),
                                          content: const Text(
                                            'Mở CV trong app hoặc mở ngoài (trình duyệt).',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                try {
                                                  await launchUrlString(
                                                    url,
                                                    mode:
                                                        LaunchMode.inAppWebView,
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(
                                                    // ignore: use_build_context_synchronously
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Không thể mở CV trong app: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Text('Mở trong app'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                try {
                                                  await launchUrlString(
                                                    url,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(
                                                    // ignore: use_build_context_synchronously
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Không thể mở CV: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Text('Mở ngoài'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Đóng'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Không thể mở CV: $e'),
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') return _delete(d.id);
                            await _updateStatus(d.id, v);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'new',
                              child: Text('Mới'),
                            ),
                            const PopupMenuItem(
                              value: 'reviewed',
                              child: Text('Đã xem'),
                            ),
                            const PopupMenuItem(
                              value: 'accepted',
                              child: Text('Chấp nhận'),
                            ),
                            const PopupMenuItem(
                              value: 'rejected',
                              child: Text('Từ chối'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa'),
                            ),
                          ],
                          child: Chip(label: Text(status)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
