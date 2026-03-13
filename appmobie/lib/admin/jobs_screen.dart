import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _col = FirebaseFirestore.instance.collection('JobCareers');
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  Future<void> _deleteJob(String id) async {
    await _col.doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa việc')));
    }
  }

  Future<void> _showAddEdit([Job? job]) async {
    final company = TextEditingController(text: job?.company ?? '');
    final title = TextEditingController(text: job?.title ?? '');
    final location = TextEditingController(text: job?.location ?? '');
    final salary = TextEditingController(text: job?.salary ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(job == null ? 'Thêm việc' : 'Sửa việc'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: company,
                decoration: const InputDecoration(labelText: 'Công ty'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: salary,
                decoration: const InputDecoration(labelText: 'Lương'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final data = {
      'Company': company.text.trim(),
      'Job': title.text.trim(),
      'Location': location.text.trim(),
      'Salary': salary.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (job == null) {
      await _col.add(data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm việc')));
      }
    } else {
      await _col.doc(job.id).update(data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã cập nhật việc')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quản lý Việc làm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEdit(null),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Tìm theo tiêu đề, công ty hoặc địa điểm',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
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
                var jobs = docs
                    .map((d) => Job.fromMap(d.id, d.data()))
                    .toList();
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  jobs = jobs.where((j) {
                    return j.title.toLowerCase().contains(q) ||
                        j.company.toLowerCase().contains(q) ||
                        j.location.toLowerCase().contains(q);
                  }).toList();
                }
                return ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (c, i) {
                    final job = jobs[i];
                    return Card(
                      child: ListTile(
                        title: Text(job.title),
                        subtitle: Text(
                          '${job.company} • ${job.location} • ${job.salary}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddEdit(job),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteJob(job.id),
                            ),
                          ],
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
