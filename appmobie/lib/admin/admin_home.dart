import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin/JobSeeder.dart';
import 'admin_cvs_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isAdmin = false;
  bool _checkingAdmin = false;

  List<Widget> get pages {
    final base = <Widget>[
      const ManageJobsPage(),
      const ResetPasswordPage(),
      const NotificationsPage(),
    ];
    if (_isAdmin) base.add(const AdminCvsPage());
    return base;
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _checkAdminAndRefresh(user.uid);
    }

    // pages are provided by the `pages` getter which adds AdminCvsPage when `_isAdmin` is true
  }

  Future<void> _checkAdminAndRefresh(String uid) async {
    if (!mounted) return;
    setState(() => _checkingAdmin = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() => _isAdmin = doc.exists);
    } catch (e) {
      if (mounted) setState(() => _isAdmin = false);
    } finally {
      if (mounted) setState(() => _checkingAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent admin UI usage on web
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('AppMobie Admin')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Admin UI chỉ được hỗ trợ trên ứng dụng (Android/iOS).',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AppMobie Admin'),
        actions: [
          if (user == null) ...[
            TextButton.icon(
              onPressed: _showSignInDialog,
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Sign in',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email ?? ''),
                  const SizedBox(height: 2),
                  SelectableText(
                    'UID: ${user.uid}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (_isAdmin)
                    const Text(
                      'Admin',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                ],
              ),
            ),
            if (!_isAdmin && kDebugMode)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                tooltip: 'Grant admin (dev)',
                onPressed: () async {
                  final uid = user.uid;
                  final docRef = FirebaseFirestore.instance
                      .collection('admin')
                      .doc(uid);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Tạo admin (DEV)'),
                      content: Text(
                        'Tạo document admin/\$uid cho user ${user.email}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Tạo'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  try {
                    await docRef.set({
                      'email': user.email ?? '',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    await _checkAdminAndRefresh(uid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã tạo admin document')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi tạo admin: $e')),
                    );
                  }
                },
              ),
            // Admin CVs moved to bottom navigation when user is admin
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                setState(() => _isAdmin = false);
              },
              tooltip: 'Sign out',
            ),
          ],
        ],
      ),
      body: Builder(
        builder: (context) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bạn chưa đăng nhập.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showSignInDialog,
                    icon: const Icon(Icons.login),
                    label: const Text('Đăng nhập quản trị'),
                  ),
                ],
              ),
            );
          }

          if (_checkingAdmin)
            return const Center(child: CircularProgressIndicator());

          if (!_isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bạn không có quyền truy cập quản trị.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async =>
                        await _checkAdminAndRefresh(user.uid),
                    child: const Text('Kiểm tra lại quyền'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      setState(() => _isAdmin = false);
                    },
                    child: const Text('Đăng xuất'),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Hướng dẫn: Tạo user trong Firebase Authentication, sau đó vào Firestore tạo document tại `admin/{uid}` để cấp quyền quản trị.\nBạn có thể thêm field `email` để ghi chú.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          // Admin UI with left navigation when wide
          return LayoutBuilder(
            builder: (context, constraints) {
              final useRail = constraints.maxWidth >= 600;
              final selected = _selectedIndex.clamp(0, pages.length - 1);
              final content = pages[selected];

              // build rail destinations and bottom nav items dynamically
              final railDestinations = <NavigationRailDestination>[
                const NavigationRailDestination(
                  icon: Icon(Icons.work_outline),
                  label: Text('Quản lý việc làm'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.lock_reset),
                  label: Text('Cấp lại mật khẩu'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.notifications_active),
                  label: Text('Tuyển dụng'),
                ),
              ];
              final bottomItems = <BottomNavigationBarItem>[
                const BottomNavigationBarItem(
                  icon: Icon(Icons.work),
                  label: 'Jobs',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.lock),
                  label: 'Reset',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Notifs',
                ),
              ];

              if (_isAdmin) {
                railDestinations.add(
                  const NavigationRailDestination(
                    icon: Icon(Icons.folder_open),
                    label: Text('Quản lý CVs'),
                  ),
                );
                bottomItems.add(
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.folder),
                    label: 'CVs',
                  ),
                );
              }

              if (useRail) {
                return Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: (i) =>
                          setState(() => _selectedIndex = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: content),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(child: content),
                    BottomNavigationBar(
                      currentIndex: selected,
                      onTap: (i) => setState(() => _selectedIndex = i),
                      items: bottomItems,
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      selectedItemColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary,
                      unselectedItemColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.75),
                      elevation: 8,
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Admin Sign in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              final password = _passwordController.text;
              try {
                final cred = await FirebaseAuth.instance
                    .signInWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                Navigator.of(context).pop();
                await _checkAdminAndRefresh(cred.user!.uid);
                // If running in debug, offer to create admin doc automatically
                if (!_isAdmin && kDebugMode) {
                  final make = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Không có quyền admin'),
                      content: const Text(
                        'Tài khoản này chưa nằm trong collection `admin`.\nBạn có muốn tạo document admin/{uid} tạm (chỉ trong chế độ debug)?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Không'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Tạo'),
                        ),
                      ],
                    ),
                  );
                  if (make == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('admin')
                          .doc(cred.user!.uid)
                          .set({
                            'email': cred.user!.email ?? '',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      await _checkAdminAndRefresh(cred.user!.uid);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã tạo admin document (debug)'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi tạo admin doc: $e')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tài khoản chưa được cấp quyền quản trị'),
                      ),
                    );
                  }
                } else {
                  setState(() {});
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đăng nhập thất bại: $e')),
                );
              }
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------
// Internal pages
// ---------------------------

class ManageJobsPage extends StatefulWidget {
  const ManageJobsPage({Key? key}) : super(key: key);

  @override
  State<ManageJobsPage> createState() => _ManageJobsPageState();
}

class _ManageJobsPageState extends State<ManageJobsPage> {
  // Use the same collection name the mobile app writes to (older code used
  // 'JobCareers'). If your mobile app adds documents to 'JobCareers', the
  // admin UI must read from that collection.
  final CollectionReference<Map<String, dynamic>> jobsRef = FirebaseFirestore
      .instance
      .collection('JobCareers');

  Future<void> _showEditDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    // The mobile app stores job documents with keys: 'Company','Job','Location','Salary'
    // Support that schema so admin UI shows and edits the same fields.
    final companyC = TextEditingController(
      text: doc?.data()['Company'] ?? doc?.data()['company'] ?? '',
    );
    final jobC = TextEditingController(
      text: doc?.data()['Job'] ?? doc?.data()['title'] ?? '',
    );
    final locationC = TextEditingController(
      text: doc?.data()['Location'] ?? doc?.data()['location'] ?? '',
    );
    final salaryC = TextEditingController(
      text: doc?.data()['Salary'] ?? doc?.data()['salary'] ?? '',
    );
    final isNew = doc == null;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isNew ? 'Thêm việc làm' : 'Sửa việc làm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyC,
                decoration: const InputDecoration(labelText: 'Công ty'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: jobC,
                decoration: const InputDecoration(labelText: 'Vị trí / Job'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationC,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: salaryC,
                decoration: const InputDecoration(labelText: 'Lương'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final company = companyC.text.trim();
              final job = jobC.text.trim();
              final location = locationC.text.trim();
              final salary = salaryC.text.trim();
              if (job.isEmpty && company.isEmpty) return;

              // show small progress indicator (use root navigator to avoid being
              // dismissed by subtree rebuilds)
              showDialog<void>(
                context: context,
                useRootNavigator: true,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                if (isNew) {
                  await jobsRef.add({
                    'Company': company,
                    'Job': job,
                    'Location': location,
                    'Salary': salary,
                    'createdAt': FieldValue.serverTimestamp(),
                    'ownerId': FirebaseAuth.instance.currentUser?.uid,
                  });
                } else {
                  await jobsRef.doc(doc.id).set({
                    'Company': company,
                    'Job': job,
                    'Location': location,
                    'Salary': salary,
                  }, SetOptions(merge: true));
                }

                // close progress
                if (Navigator.of(context, rootNavigator: true).canPop())
                  Navigator.of(context, rootNavigator: true).pop();

                // close edit dialog only on success
                Navigator.of(context).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isNew ? 'Đã thêm việc làm' : 'Đã cập nhật việc làm',
                    ),
                  ),
                );
              } catch (e, st) {
                // close progress
                if (Navigator.of(context, rootNavigator: true).canPop())
                  Navigator.of(context, rootNavigator: true).pop();
                debugPrint('Save job failed: $e\n$st');
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Lỗi lưu việc làm: $e')));
                // keep the dialog open so user can fix and retry
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJob(String id) async {
    // Ask for confirmation first (use root navigator so dialog doesn't get
    // dismissed by subtree rebuilds). Then show a small progress dialog
    // while performing the deletion and surface any errors to the user.
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa việc làm này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // show progress
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await jobsRef.doc(id).delete();
      // close progress
      if (Navigator.of(context, rootNavigator: true).canPop())
        Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa việc làm')));
    } catch (e, st) {
      // close progress
      if (Navigator.of(context, rootNavigator: true).canPop())
        Navigator.of(context, rootNavigator: true).pop();
      debugPrint('Delete job failed: $e\n$st');
      if (!mounted) return;
      // If this is a permission error, provide actionable guidance.
      final errMsg = e.toString();
      if (errMsg.contains('permission-denied')) {
        if (kDebugMode) {
          final user = FirebaseAuth.instance.currentUser;
          final create = await showDialog<bool>(
            context: context,
            useRootNavigator: true,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Quyền bị từ chối'),
              content: const Text(
                'Bạn không có quyền xóa tài liệu này. Trong chế độ debug, bạn có thể tạo document `admin/{uid}` cho tài khoản hiện tại để cấp quyền tạm thời.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Tạo admin (DEV)'),
                ),
              ],
            ),
          );
          if (create == true && user != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('admin')
                  .doc(user.uid)
                  .set({
                    'email': user.email ?? '',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã tạo admin document (debug). Vui lòng thử lại.',
                  ),
                ),
              );
            } catch (e2) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi khi tạo admin doc: $e2')),
              );
            }
            return;
          }
        }

        // Non-debug or user chose not to auto-create admin doc: show instructions.
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quyền bị từ chối'),
            content: const Text(
              'Xóa thất bại vì thiếu quyền. Giải pháp:\n'
              '1) Trong Firebase Console, tạo document `admin/{uid}` cho user đã đăng nhập.\n'
              '2) Hoặc cập nhật Firestore rules để cho phép tài khoản quản trị (deploy rules nếu cần).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xóa việc làm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý việc làm'),
        actions: [
          IconButton(
            tooltip: 'Seed jobs',
            icon: const Icon(Icons.auto_awesome_motion),
            onPressed: () async {
              final doIt = await showDialog<String?>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Seed jobs từ JobSeeder'),
                  content: const Text(
                    'Bạn có muốn thêm sample jobs từ `JobSeeder`?\nChọn "Append" để thêm vào, hoặc "Clear & Seed" để xóa tất cả rồi thêm lại.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('append'),
                      child: const Text('Append'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('clear'),
                      child: const Text('Clear & Seed'),
                    ),
                  ],
                ),
              );
              if (doIt == null) return;

              // show progress
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                if (doIt == 'clear') {
                  // delete existing docs in chunks
                  final col = FirebaseFirestore.instance.collection(
                    'JobCareers',
                  );
                  final snapshot = await col.get();
                  final docs = snapshot.docs;
                  const chunk = 400;
                  for (var i = 0; i < docs.length; i += chunk) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (var j = i; j < (i + chunk) && j < docs.length; j++) {
                      batch.delete(docs[j].reference);
                    }
                    await batch.commit();
                  }
                }

                // seed sample jobs and set ownerId to current admin uid (if available)
                final ownerUid = FirebaseAuth.instance.currentUser?.uid;
                await JobSeeder.seedSampleJobs(ownerId: ownerUid);

                if (Navigator.of(context, rootNavigator: true).canPop())
                  Navigator.of(context, rootNavigator: true).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seeding hoàn tất')),
                );
                setState(() {});
              } catch (e) {
                if (Navigator.of(context, rootNavigator: true).canPop())
                  Navigator.of(context, rootNavigator: true).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Lỗi khi seed: $e')));
              }
            },
          ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: jobsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            // show error details and fallback to one-time fetch so user can see existing docs
            final err = snap.error;
            // attempt a one-time fetch
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lỗi realtime stream: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  const Text('Thử tải tạm thời từ Firestore:'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: jobsRef.get(),
                      builder: (context, oneShot) {
                        if (oneShot.hasError)
                          return Center(
                            child: Text('Lỗi tải tạm thời: ${oneShot.error}'),
                          );
                        if (!oneShot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final docs = oneShot.data!.docs;
                        if (docs.isEmpty)
                          return const Center(
                            child: Text('Chưa có việc làm trong Firestore'),
                          );
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final d = docs[index];
                            final data = d.data();
                            final jobTitle =
                                (data['Job'] ?? data['title'] ?? '').toString();
                            final company =
                                (data['Company'] ?? data['company'] ?? '')
                                    .toString();
                            final location =
                                (data['Location'] ?? data['location'] ?? '')
                                    .toString();
                            final salary =
                                (data['Salary'] ?? data['salary'] ?? '')
                                    .toString();
                            final ownerId = (data['ownerId'] ?? '').toString();
                            return ListTile(
                              title: Text(
                                jobTitle.isNotEmpty
                                    ? jobTitle
                                    : (company.isNotEmpty
                                          ? company
                                          : '(Không tiêu đề)'),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    company.isNotEmpty
                                        ? (location.isNotEmpty
                                              ? '$company • $location'
                                              : company)
                                        : (location.isNotEmpty ? location : ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (ownerId.isNotEmpty)
                                    Text(
                                      'owner: $ownerId',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (salary.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Text(
                                        salary,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditDialog(doc: d),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteJob(d.id),
                                  ),
                                ],
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

          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final jobTitle = (data['Job'] ?? data['title'] ?? '').toString();
              final company = (data['Company'] ?? data['company'] ?? '')
                  .toString();
              final location = (data['Location'] ?? data['location'] ?? '')
                  .toString();
              final salary = (data['Salary'] ?? data['salary'] ?? '')
                  .toString();
              final ownerId = (data['ownerId'] ?? '').toString();
              return ListTile(
                title: Text(
                  jobTitle.isNotEmpty
                      ? jobTitle
                      : (company.isNotEmpty ? company : '(Không tiêu đề)'),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.isNotEmpty
                          ? (location.isNotEmpty
                                ? '$company • $location'
                                : company)
                          : (location.isNotEmpty ? location : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ownerId.isNotEmpty)
                      Text(
                        'owner: $ownerId',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (salary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          salary,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(doc: d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteJob(d.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Thêm việc làm',
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _email = TextEditingController();
  bool _loading = false;

  Future<void> _sendReset() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi email đặt lại mật khẩu')),
      );
      _email.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cấp lại mật khẩu cho user',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email user'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _sendReset,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gửi email đặt lại'),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final CollectionReference<Map<String, dynamic>> recRef = FirebaseFirestore
      .instance
      .collection('JobApplications');

  Future<void> _updateStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final data = doc.data();
    try {
      // Update recruitment/application document with the new status
      await recRef.doc(doc.id).set({
        'status': status,
        'handledAt': FieldValue.serverTimestamp(),
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      // Create a notification document so applicant's device can receive it.
      // Try common recipient fields (adjust to your app's application schema).
      final recipientUid =
          data['applicantId'] ??
          data['applicantUid'] ??
          data['senderUid'] ??
          data['userId'] ??
          data['uid'];
      final recipientEmail =
          data['candidateEmail'] ?? data['email'] ?? data['applicantEmail'];
      final appTitle =
          data['jobTitle'] ?? data['Job'] ?? data['title'] ?? 'Đơn ứng tuyển';

      final notificationsRef = FirebaseFirestore.instance.collection(
        'notifications',
      );
      await notificationsRef.add({
        'toUid': recipientUid,
        'toEmail': recipientEmail,
        'title': status == 'accepted'
            ? 'Ứng tuyển được chấp nhận'
            : 'Ứng tuyển bị từ chối',
        'body':
            '$appTitle đã được ${status == 'accepted' ? 'chấp nhận' : 'từ chối'}.',
        'applicationId': doc.id,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã ${status == 'accepted' ? 'chấp nhận' : 'từ chối'}: ${data['title'] ?? ''}',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      // Provide helpful guidance when permission is denied
      if (e.code == 'permission-denied') {
        if (kDebugMode) {
          final make = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Quyền bị từ chối (debug)'),
              content: const Text(
                'Quyền cập nhật ứng tuyển bị từ chối. Trong chế độ debug, bạn có thể tạo document `admin/{uid}` cho tài khoản hiện tại để cấp quyền tạm thời. Tạo không?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Không'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tạo'),
                ),
              ],
            ),
          );
          if (make == true) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                await FirebaseFirestore.instance
                    .collection('admin')
                    .doc(user.uid)
                    .set({
                      'email': user.email ?? '',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã tạo admin document (debug). Vui lòng thử lại.',
                    ),
                  ),
                );
                return;
              } catch (e2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi tạo admin doc: $e2')),
                );
                return;
              }
            }
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quyền bị từ chối khi cập nhật ứng tuyển.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show all recruitment applications; admin can filter by status on client later if desired
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text('Không có đơn ứng tuyển'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final appTitle =
                data['jobTitle'] ??
                data['Job'] ??
                data['title'] ??
                'Đơn ứng tuyển';
            final candidateName =
                data['candidateName'] ?? data['applicantName'] ?? data['name'];
            final candidateEmail =
                data['candidateEmail'] ??
                data['applicantEmail'] ??
                data['email'];
            final cvUrl = data['cvUrl'] ?? data['resumeUrl'];

            return Card(
              child: ListTile(
                title: Text(appTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (candidateName != null)
                      Text('Người ứng tuyển: $candidateName'),
                    if (candidateEmail != null) Text('Email: $candidateEmail'),
                    if (data['message'] != null)
                      Text('Lời nhắn: ${data['message']}'),
                    Text('Trạng thái: $status'),
                    if (cvUrl != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            final urlStr = cvUrl.toString();
                            debugPrint('Admin: opening CV url => $urlStr');
                            final uri = Uri.parse(urlStr);

                            // Prefer launching externally (browser) to ensure supported on emulator/device
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Không thể mở CV: $urlStr'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            debugPrint('Error launching CV url: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Không thể mở CV: $e')),
                            );
                          }
                        },
                        child: const Text('Xem CV'),
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: status == 'pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _updateStatus(d, 'accepted');
                              setState(() {});
                            },
                            child: const Text('Chấp nhận'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _updateStatus(d, 'rejected');
                              setState(() {});
                            },
                            child: const Text('Từ chối'),
                          ),
                        ],
                      )
                    : Text(status, style: const TextStyle(color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }
}
