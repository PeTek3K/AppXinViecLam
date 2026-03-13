import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  User? _user;
  bool _showAll = false; // false = only unread, true = all
  DateTime? _selectedDate; // null = no date filter

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.userChanges().listen((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // Bỏ locale nếu không cần tiếng Việt
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: Text('Vui lòng đăng nhập để xem thông báo'));
    }

    var colQuery = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: _user!.uid);

    if (!_showAll) {
      // show only unread by default
      colQuery = colQuery.where('read', isEqualTo: false);
    }

    final col = colQuery
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (m, _) => m,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data?.docs ?? [];

        // Apply date filter if selected
        if (_selectedDate != null) {
          final startOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
          );
          final endOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            23,
            59,
            59,
            999,
          );

          docs = docs.where((d) {
            final data = d.data();
            final ts = data['createdAt'] as Timestamp?;
            if (ts == null) return false;
            final date = DateTime.fromMillisecondsSinceEpoch(
              ts.millisecondsSinceEpoch,
            ).toLocal();
            return date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                date.isBefore(endOfDay.add(const Duration(seconds: 1)));
          }).toList();
        }

        // If the current query returned empty, check if there are any
        // notifications at all (read or unread). If none exist, show
        // a simple empty message and hide the toggle buttons. If there
        // are notifications but current filter returned none (e.g., no
        // unread), show the toggle buttons so user can switch to 'Tất cả'.
        if (docs.isEmpty) {
          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('notifications')
                .where('toUid', isEqualTo: _user!.uid)
                .limit(1)
                .get(),
            builder: (ctx2, totalSnap) {
              if (totalSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final hasAny = (totalSnap.data?.docs.isNotEmpty ?? false);
              if (!hasAny) {
                // No notifications at all: show empty text and no buttons
                return const Center(child: Text('Không có thông báo'));
              }

              // There are notifications but current filter returned none
              // (e.g., no unread). Show the toggle buttons and a message.
              return Column(
                children: [
                  _buildFilterButtons(),
                  Expanded(
                    child: Center(
                      child: Text(
                        _selectedDate != null
                            ? 'Không có thông báo trong ngày này'
                            : 'Không có thông báo chưa đọc',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        // Group docs by date key (yyyy-MM-dd)
        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        final order = <String>[]; // keep order of groups

        for (final d in docs) {
          final data = d.data();
          Timestamp? ts = data['createdAt'] as Timestamp?;
          DateTime date = ts != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  ts.millisecondsSinceEpoch,
                ).toLocal()
              : DateTime.now();
          final key = _dateKey(date);
          if (!grouped.containsKey(key)) {
            grouped[key] = [];
            order.add(key);
          }
          grouped[key]!.add(d);
        }

        // Flatten to a list of widgets with headers
        final items = <Widget>[];
        for (final key in order) {
          final list = grouped[key]!;
          final firstDate = _parseKeyToDate(key);
          items.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                _formatHeader(firstDate),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          );
          for (final d in list) {
            final data = d.data();
            final title = data['title']?.toString() ?? 'Thông báo';
            final body = data['body']?.toString() ?? '';
            final read = data['read'] as bool? ?? false;
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null
                ? DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch)
                : null;

            items.add(
              ListTile(
                tileColor: read
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer,
                leading: read
                    ? const SizedBox(width: 8)
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                title: Text(title),
                subtitle: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: time != null ? Text(_formatTime(time)) : null,
                onTap: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(d.id)
                        .set({'read': true}, SetOptions(merge: true));
                  } catch (_) {}
                },
              ),
            );
            items.add(const Divider(height: 1, indent: 16));
          }
        }

        return Column(
          children: [
            _buildFilterButtons(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) => items[i],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterButtons() {
    return Column(
      children: [
        // Read/Unread toggle buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showAll = false),
                style: TextButton.styleFrom(
                  backgroundColor: !_showAll
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Chỉ chưa đọc'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                style: TextButton.styleFrom(
                  backgroundColor: _showAll
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Tất cả'),
              ),
            ],
          ),
        ),
        // Date filter section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedDate != null
                      ? 'Ngày: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Tất cả các ngày',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearDateFilter,
                  tooltip: 'Xóa bộ lọc',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Chọn ngày'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _dateKey(DateTime t) {
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseKeyToDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _formatHeader(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(t.year, t.month, t.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${t.day}/${t.month}/${t.year}';
  }
}