import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';
import '../widgets/quickaction.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? user;
  bool _uploading = false;
  int? _avatarCacheBuster;
  bool _isAdmin = false;
  bool _checkingAdmin = false;
  late final StreamSubscription<User?> _userSub;

  // pagination
  final int _pageSize = 7; // mỗi trang 7 job
  int _currentPage = 0;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  final List<List<Job>> _cachedPages = [];
  final List<DocumentSnapshot<Object?>?> _pageLastDocs = [];

  // search & filter
  String _searchQuery = '';
  String? _filterCompany;
  String? _filterLocation;
  int? _salaryMin; // assumed in same unit as displayed (e.g., millions)
  int? _salaryMax;
  Timer? _searchDebounce;
  bool _showFavoritesOnly = false;
  bool _showAppliedOnly = false;

  // scroll control: để điều hướng khi đổi trang (không bị cuộn sâu)
  final ScrollController _mainScrollCtrl = ScrollController();
  final GlobalKey _jobsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _userSub = FirebaseAuth.instance.userChanges().listen(
      (u) async {
        if (!mounted) return;
        setState(() => user = u);
        if (u != null) {
          await _checkAdmin(u.uid);
        } else {
          if (mounted) setState(() => _isAdmin = false);
        }
      },
      onError: (e, st) {
        debugPrint('userChanges error: $e\n$st');
      },
    );
    if (user != null) _checkAdmin(user!.uid);
    // load first page
    _loadPage(0);
  }

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: user?.displayName ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Tên của bạn'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      try {
        await user?.updateDisplayName(res);
        await user?.reload();
        setState(() => user = FirebaseAuth.instance.currentUser);
        // create a notification for the user about name change
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await notificationService.sendNotificationToUser(
              toUid: uid,
              title: 'Đổi tên thành công',
              body: 'Tên hiển thị đã được đổi thành $res',
            );
          }
        } catch (_) {}
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật tên: $e')));
        }
        // also create a failure notification for the user (optional)
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await notificationService.sendNotificationToUser(
              toUid: uid,
              title: 'Đổi tên thất bại',
              body: 'Không thể cập nhật tên: $e',
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _userSub.cancel();
    _searchDebounce?.cancel();
    _mainScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin(String uid) async {
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

  Future<void> _pickAndUploadAvatar(File pickedFile) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập')));
      }
      return;
    }

    try {
      // upload to Cloudinary
      final uniqueId =
          '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final cloudUrl = await _uploadToCloudinary(
        path: pickedFile.path,
        folder: 'avatars',
        publicId: uniqueId,
        filename: 'avatar_${uniqueId}.jpg',
      );

      if (cloudUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải ảnh lên Cloudinary')),
          );
        }
        return;
      }

      final prevUrl = currentUser.photoURL;
      await currentUser.updatePhotoURL(cloudUrl);
      await currentUser.reload();
      // evict cached images (old + new) and update local `user` + cache buster
      try {
        if (prevUrl != null) await NetworkImage(prevUrl).evict();
      } catch (_) {}
      try {
        await NetworkImage(cloudUrl).evict();
      } catch (_) {}

      // additionally clear the in-memory image cache to force reload
      try {
        PaintingBinding.instance.imageCache.clear();
      } catch (_) {}

      if (mounted) {
        setState(() {
          user = FirebaseAuth.instance.currentUser;
          _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch;
        });
      }

      // debug: print and show the updated photoURL so we can verify it's changed
      final newUrl = FirebaseAuth.instance.currentUser?.photoURL ?? cloudUrl;
      debugPrint('Avatar updated - new photoURL: $newUrl');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã cập nhật ảnh đại diện')));
      }
      // send a notification to the user about avatar update (optional)
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await notificationService.sendNotificationToUser(
            toUid: uid,
            title: 'Đã cập nhật ảnh đại diện',
            body: 'Ảnh đại diện của bạn đã được cập nhật.',
          );
        }
      } catch (_) {}
    } on FirebaseException catch (e, st) {
      debugPrint('DEBUG UPLOAD FirebaseException: ${e.code} ${e.message}\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: ${e.message ?? e.code}')),
        );
      }
    } catch (e, st) {
      debugPrint('DEBUG UPLOAD unexpected: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải lên ảnh')));
      }
    }
  }

  // Upload helper for Cloudinary (unsigned preset)
  Future<String?> _uploadToCloudinary({
    Uint8List? bytes,
    String? path,
    required String folder,
    String? publicId,
    required String filename,
  }) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
      if (cloudName == null || preset == null) {
        debugPrint('Cloudinary config missing in .env');
        return null;
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
      );
      final req = http.MultipartRequest('POST', uri);
      req.fields['upload_preset'] = preset;
      req.fields['folder'] = folder;
      if (publicId != null) req.fields['public_id'] = publicId;

      if (bytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      } else if (path != null) {
        req.files.add(
          await http.MultipartFile.fromPath('file', path, filename: filename),
        );
      } else {
        debugPrint('Cloudinary upload: neither bytes nor path provided');
        return null;
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        debugPrint('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Cloudinary upload failed ${resp.statusCode}: ${resp.body}');
        return null;
      }
    } catch (e, st) {
      debugPrint('Cloudinary upload unexpected: $e\n$st');
      return null;
    }
  }

  Future<void> _showAddJobDialog() async {
    final companyCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm việc làm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: 'Công ty'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: jobCtrl,
                decoration: const InputDecoration(labelText: 'Vị trí / Job'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: salaryCtrl,
                decoration: const InputDecoration(labelText: 'Lương'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('JobCareers').add({
        'Company': companyCtrl.text.trim(),
        'Job': jobCtrl.text.trim(),
        'Location': locationCtrl.text.trim(),
        'Salary': salaryCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'ownerId': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm việc làm')));
      }

      // clear cache and reload first page to show new item
      _clearCacheAndReload();
    } on FirebaseException catch (e, st) {
      debugPrint('AddJob FirebaseException: ${e.code} ${e.message}\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu việc làm: ${e.code} ${e.message ?? ''}'),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('AddJob unexpected error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu việc làm: $e')));
      }
    }
  }

  // parse salary string to an integer for filtering.
  // Strategy: extract all numbers from the string, convert to ints, and
  // return their average (rounded). If none found, return null.
  int? _parseSalaryToInt(String salaryStr) {
    try {
      final matches = RegExp(r"(\d+)").allMatches(salaryStr);
      if (matches.isEmpty) return null;
      final values = matches.map((m) => int.parse(m.group(0)!)).toList();
      final avg = values.reduce((a, b) => a + b) / values.length;
      return avg.round();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showFilterMenu() async {
    final companyCtrl = TextEditingController(text: _filterCompany ?? '');
    final locationCtrl = TextEditingController(text: _filterLocation ?? '');
    final minCtrl = TextEditingController(text: _salaryMin?.toString() ?? '');
    final maxCtrl = TextEditingController(text: _salaryMax?.toString() ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bộ lọc',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // clear all
                      companyCtrl.text = '';
                      locationCtrl.text = '';
                      minCtrl.text = '';
                      maxCtrl.text = '';
                    },
                    child: const Text('Xóa'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Công ty (tên hoặc phần tên)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa điểm (tên hoặc phần tên)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Lương min'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Lương max'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // cancel / close
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // apply filters
                        setState(() {
                          _filterCompany = companyCtrl.text.trim().isEmpty
                              ? null
                              : companyCtrl.text.trim();
                          _filterLocation = locationCtrl.text.trim().isEmpty
                              ? null
                              : locationCtrl.text.trim();
                          _salaryMin = int.tryParse(minCtrl.text.trim());
                          _salaryMax = int.tryParse(maxCtrl.text.trim());
                          _cachedPages.clear();
                          _pageLastDocs.clear();
                          _currentPage = 0;
                          _hasMore = true;
                        });
                        Navigator.of(ctx).pop();
                        _loadPage(0);
                      },
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final chips = <Widget>[];
    if (_filterCompany != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InputChip(
            label: Text('Công ty: ${_filterCompany!}'),
            onDeleted: () {
              setState(() {
                _filterCompany = null;
                _cachedPages.clear();
                _pageLastDocs.clear();
                _currentPage = 0;
                _hasMore = true;
              });
              _loadPage(0);
            },
          ),
        ),
      );
    }
    if (_filterLocation != null) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InputChip(
            label: Text('Địa điểm: ${_filterLocation!}'),
            onDeleted: () {
              setState(() {
                _filterLocation = null;
                _cachedPages.clear();
                _pageLastDocs.clear();
                _currentPage = 0;
                _hasMore = true;
              });
              _loadPage(0);
            },
          ),
        ),
      );
    }
    if (_salaryMin != null || _salaryMax != null) {
      final label = '${_salaryMin ?? '-'} - ${_salaryMax ?? '-'}';
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InputChip(
            label: Text('Lương: $label'),
            onDeleted: () {
              setState(() {
                _salaryMin = null;
                _salaryMax = null;
                _cachedPages.clear();
                _pageLastDocs.clear();
                _currentPage = 0;
                _hasMore = true;
              });
              _loadPage(0);
            },
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Wrap(children: chips),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên việc, công ty, địa điểm...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() {
                              _searchQuery = '';
                              _cachedPages.clear();
                              _pageLastDocs.clear();
                              _currentPage = 0;
                              _hasMore = true;
                            });
                            _loadPage(0);
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 350),
                    () {
                      setState(() {
                        _searchQuery = v.trim();
                        _cachedPages.clear();
                        _pageLastDocs.clear();
                        _currentPage = 0;
                        _hasMore = true;
                      });
                      _loadPage(0);
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Material(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: Theme.of(context).colorScheme.surface,
              child: IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Bộ lọc',
                onPressed: _showFilterMenu,
              ),
            ),
          ],
        ),
        _buildFilterChips(),
      ],
    );
  }

  void _showJobDetail(Job job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(job.title.isNotEmpty ? job.title : '(Không tiêu đề)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Công ty: ${job.company}'),
            const SizedBox(height: 8),
            Text('Địa điểm: ${job.location}'),
            const SizedBox(height: 8),
            Text('Mức lương: ${job.salary}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _applyToJob(job);
            },
            child: const Text('Ứng tuyển'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyToJob(Job job) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để ứng tuyển')),
        );
      }
      return;
    }

    // Check duplicate application
    try {
      final existing = await FirebaseFirestore.instance
          .collection('JobApplications')
          .where('jobId', isEqualTo: job.id)
          .where('applicantId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn đã ứng tuyển công việc này rồi')),
          );
        }
        return;
      }
    } catch (e, st) {
      debugPrint('Check existing application failed: $e\n$st');
      // continue to allow applying (will rely on backend/rules to prevent duplicates if necessary)
    }

    final messageCtrl = TextEditingController();
    String? cvUrl;
    String? cvName;
    bool uploadingCv = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Ứng tuyển'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ứng tuyển: ${job.title} — ${job.company}'),
                const SizedBox(height: 8),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Thêm lời nhắn / CV tóm tắt (không bắt buộc)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Đính kèm CV'),
                      onPressed: uploadingCv
                          ? null
                          : () async {
                              // pick a file (pdf/doc)
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'doc',
                                  'docx',
                                  'png',
                                  'jpg',
                                ],
                                withData:
                                    true, // try to ensure bytes are available on web
                              );
                              if (result == null || result.files.isEmpty) {
                                return;
                              }
                              final file = result.files.first;
                              final rawBytes = file.bytes;
                              Uint8List? bytes = rawBytes == null
                                  ? null
                                  : Uint8List.fromList(rawBytes);
                              String? path = file.path;

                              // If the platform-provided path exists but the file was
                              // removed (some Android devices return a cache path),
                              // try to reconstruct the file from the provided
                              // readStream. This avoids PathNotFoundException when
                              // calling File(path).
                              if (path != null) {
                                try {
                                  final f = File(path);
                                  if (!await f.exists()) {
                                    if (file.readStream != null) {
                                      final tempDir = await Directory.systemTemp
                                          .createTemp('appmobie_cv_');
                                      final tempFile = File(
                                        '${tempDir.path}/${file.name}',
                                      );
                                      final sink = tempFile.openWrite();
                                      await for (final chunk
                                          in file.readStream!) {
                                        sink.add(chunk);
                                      }
                                      await sink.close();
                                      path = tempFile.path;
                                    } else {
                                      // cannot read file from path or stream
                                      path = null;
                                    }
                                  }
                                } catch (e, st) {
                                  debugPrint(
                                    'Error ensuring picked file exists: $e\n$st',
                                  );
                                  path = null;
                                }
                              }

                              if (bytes == null && path == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không thể đọc file đã chọn',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              if (!mounted) return;
                              setState(() => uploadingCv = true);
                              try {
                                final url = await _uploadToCloudinary(
                                  bytes: bytes,
                                  path: path,
                                  folder: 'applications/${job.id}',
                                  filename: file.name,
                                );
                                if (url != null) {
                                  cvUrl = url;
                                  cvName = file.name;
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Đã tải CV lên'),
                                      ),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Không thể tải CV. Kiểm tra cấu hình Cloudinary và upload preset.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e, st) {
                                debugPrint(
                                  'CV upload unexpected error: $e\n$st',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi tải CV: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => uploadingCv = false);
                                }
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cvName ?? 'Chưa đính kèm CV',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (uploadingCv)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: uploadingCv ? null : () => Navigator.pop(ctx, true),
                child: const Text('Gửi'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('JobApplications')
          .add({
            'jobId': job.id,
            'jobTitle': job.title,
            'jobCompany': job.company,
            'applicantId': currentUser.uid,
            'applicantName': currentUser.displayName ?? '',
            'applicantEmail': currentUser.email ?? '',
            'message': messageCtrl.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            if (cvUrl != null) 'cvUrl': cvUrl,
            if (cvName != null) 'cvName': cvName,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi hồ sơ (id: ${docRef.id})')),
        );
      }
      // notify applicant about successful application
      try {
        await notificationService.sendNotificationToUser(
          toUid: currentUser.uid,
          title: 'Ứng tuyển thành công',
          body: 'Bạn đã ứng tuyển ${job.title} — ${job.company}',
        );
      } catch (_) {}
    } on FirebaseException catch (e, st) {
      debugPrint('Apply FirebaseException: ${e.code} ${e.message}\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi hồ sơ: ${e.message ?? e.code}')),
        );
      }
      // notify applicant about failure
      try {
        await notificationService.sendNotificationToUser(
          toUid: currentUser.uid,
          title: 'Ứng tuyển thất bại',
          body: 'Không thể gửi hồ sơ: ${e.message ?? e.code}',
        );
      } catch (_) {}
    } catch (e, st) {
      debugPrint('Apply unexpected: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không thể gửi hồ sơ')));
      }
      try {
        await notificationService.sendNotificationToUser(
          toUid: currentUser.uid,
          title: 'Ứng tuyển thất bại',
          body: 'Không thể gửi hồ sơ',
        );
      } catch (_) {}
    }
  }

  // pagination
  Future<void> _loadPage(int pageIndex) async {
    if (_isLoadingPage) return;
    if (pageIndex < 0) return;
    if (pageIndex < _cachedPages.length) {
      setState(() => _currentPage = pageIndex);
      // cuộn lên đầu danh sách jobs sau khi đã set state
      _scrollToJobsTop();
      return;
    }

    setState(() => _isLoadingPage = true);
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('JobCareers')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      // Note: do NOT apply server-side equality filters for Company/Location
      // because we want partial (contains) matches and combining where()
      // with orderBy('createdAt') may require composite indexes. Instead we
      // fetch the page ordered by createdAt and apply company/location
      // filtering client-side (substring, case-insensitive).

      if (pageIndex > 0) {
        if (_pageLastDocs.length >= pageIndex &&
            _pageLastDocs[pageIndex - 1] != null) {
          q = q.startAfterDocument(_pageLastDocs[pageIndex - 1]!);
        } else {
          setState(() => _isLoadingPage = false);
          return;
        }
      }

      final snap = await q.get();
      final docs = snap.docs;
      var jobs = docs.map((d) {
        final data = d.data();
        return Job.fromMap(d.id, data);
      }).toList();

      // mark favorites based on local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final favs = prefs.getStringList('favorite_jobs') ?? [];
        if (favs.isNotEmpty) {
          for (final j in jobs) {
            if (favs.contains(j.id)) j.isFavorite = true;
          }
        }
      } catch (_) {}

      // client-side filters: company/location substring match (partial)
      if (_filterCompany != null && _filterCompany!.isNotEmpty) {
        final fc = _filterCompany!.toLowerCase();
        jobs = jobs
            .where((job) => job.company.toLowerCase().contains(fc))
            .toList();
      }
      if (_filterLocation != null && _filterLocation!.isNotEmpty) {
        final fl = _filterLocation!.toLowerCase();
        jobs = jobs
            .where((job) => job.location.toLowerCase().contains(fl))
            .toList();
      }

      // client-side search: tokenized search across title/company/location
      if (_searchQuery.isNotEmpty) {
        final tokens = _searchQuery
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
        if (tokens.isNotEmpty) {
          jobs = jobs.where((job) {
            final hay = '${job.title} ${job.company} ${job.location}'
                .toLowerCase();
            // require that every token appears somewhere (AND semantics)
            return tokens.every((tk) => hay.contains(tk));
          }).toList();
        }
      }

      // salary filter (client-side): try to parse numeric values and filter
      if (_salaryMin != null || _salaryMax != null) {
        jobs = jobs.where((job) {
          final s = _parseSalaryToInt(job.salary);
          if (s == null) return false;
          if (_salaryMin != null && s < _salaryMin!) return false;
          if (_salaryMax != null && s > _salaryMax!) return false;
          return true;
        }).toList();
      }

      _cachedPages.add(jobs);
      _pageLastDocs.add(docs.isNotEmpty ? docs.last : null);
      _hasMore = docs.length == _pageSize;
      setState(() => _currentPage = pageIndex);

      // khi trang mới load xong, cuộn lên phần danh sách
      _scrollToJobsTop();
    } catch (e) {
      debugPrint('Load page error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải trang: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPage = false);
    }
  }

  void _goNext() {
    if (_currentPage < _cachedPages.length - 1) {
      setState(() => _currentPage += 1);
      _scrollToJobsTop();
    } else if (_hasMore && !_isLoadingPage) {
      _loadPage(_currentPage + 1);
    }
  }

  void _goPrev() {
    if (_currentPage > 0) {
      setState(() => _currentPage -= 1);
      _scrollToJobsTop();
    }
  }

  void _clearCacheAndReload() {
    _cachedPages.clear();
    _pageLastDocs.clear();
    _hasMore = true;
    _currentPage = 0;
    _loadPage(0);
  }

  // cuộn để phần danh sách job hiển thị đầu (tránh bị cuộn sâu)
  void _scrollToJobsTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final jobsCtx = _jobsSectionKey.currentContext;
      if (jobsCtx == null) {
        // fallback: scroll to top
        if (_mainScrollCtrl.hasClients) {
          _mainScrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        return;
      }
      final box = jobsCtx.findRenderObject() as RenderBox?;
      if (box == null || !_mainScrollCtrl.hasClients) {
        if (_mainScrollCtrl.hasClients) {
          _mainScrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        return;
      }

      // position of jobs section relative to the screen
      final yGlobal = box.localToGlobal(Offset.zero).dy;
      // current scroll offset
      final currentOffset = _mainScrollCtrl.offset;
      // approximate top toolbar/padding height to avoid hiding under status/toolbars
      final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
      // target scroll offset so jobs section appears near top (with small margin)
      final target = (currentOffset + yGlobal - topPadding - 12).clamp(
        0.0,
        _mainScrollCtrl.position.maxScrollExtent,
      );

      _mainScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final email = user?.email ?? '';
    final displayName = user?.displayName;
    final avatarUrl = user?.photoURL;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1200,
                      imageQuality: 80,
                    );
                    if (picked == null) return;
                    setState(() => _uploading = true);
                    await _pickAndUploadAvatar(File(picked.path));
                    setState(() => _uploading = false);
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(
                            avatarUrl +
                                (_avatarCacheBuster != null
                                    ? '?cb=${_avatarCacheBuster}'
                                    : ''),
                          )
                        : null,
                  ),
                ),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.only(right: 4, bottom: 4),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 80,
                          );
                          if (picked == null) return;
                          setState(() => _uploading = true);
                          await _pickAndUploadAvatar(File(picked.path));
                          setState(() => _uploading = false);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.camera_alt, size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào 👋',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName ?? email,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _editDisplayName,
                        tooltip: 'Đổi tên',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tính năng nhanh', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // const QuickAction(
            //   icon: Icons.note_alt_outlined,
            //   label: 'Ghi chú'),
            // const QuickAction(
            //   icon: Icons.photo_library_outlined,
            //   label: 'Thư viện',
            // ),
            // const QuickAction(
            //   icon: Icons.notifications_none,
            //   label: 'Thông báo',
            // ),
            // const QuickAction(
            //   icon: Icons.analytics_outlined,
            //   label: 'Thống kê',
            // ),
            QuickAction(
              icon: Icons.description_outlined,
              label: 'Tạo CV',
              onTap: () => Navigator.pushNamed(context, '/create-cv'),
            ),
            QuickAction(
              icon: _showAppliedOnly ? Icons.work : Icons.work_outline,
              label: 'Việc đã ứng tuyển',
              onTap: () async {
                // ensure mutual exclusivity with favorites-only
                setState(() {
                  _showAppliedOnly = !_showAppliedOnly;
                  if (_showAppliedOnly) _showFavoritesOnly = false;
                });
                if (_showAppliedOnly) {
                  await _loadAppliedJobs();
                } else {
                  _clearCacheAndReload();
                }
              },
            ),
            QuickAction(
              icon: _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              label: 'Việc làm đã quan tâm',
              onTap: () async {
                setState(() => _showFavoritesOnly = !_showFavoritesOnly);
                if (_showFavoritesOnly) {
                  await _loadFavorites();
                } else {
                  _clearCacheAndReload();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJobsList() {
    final currentJobs = _cachedPages.isNotEmpty
        ? _cachedPages[_currentPage]
        : <Job>[];

    return Column(
      key: _jobsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Việc làm', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_isLoadingPage && _cachedPages.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (!_isLoadingPage && _cachedPages.isEmpty)
          const Text('Chưa có việc làm'),
        Column(
          children: currentJobs.map((job) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(job.company.isNotEmpty ? job.company[0] : 'C'),
                ),
                title: Text(
                  job.title.isNotEmpty ? job.title : '(Không tiêu đề)',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.company,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.location.isNotEmpty
                          ? job.location
                          : 'Mô tả ngắn gọn...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.salary,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    job.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: job.isFavorite ? Colors.red : null,
                  ),
                  onPressed: () => _toggleFavorite(job),
                ),
                onTap: () => _showJobDetail(job),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _currentPage > 0 && !_isLoadingPage ? _goPrev : null,
              child: const Text('Trước'),
            ),
            const SizedBox(width: 12),
            Text('Trang ${_currentPage + 1}'),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed:
                  (!_isLoadingPage &&
                      (_currentPage < _cachedPages.length - 1 || _hasMore))
                  ? _goNext
                  : null,
              child: const Text('Tiếp'),
            ),
          ],
        ),
        if (_isLoadingPage)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  // Thêm hàm toggle favorite
  void _toggleFavorite(Job job) {
    setState(() {
      job.isFavorite = !job.isFavorite;
    });

    // persist locally
    _saveFavoriteToLocal(job.id, job.isFavorite);

    // persist to firestore for logged in users
    if (FirebaseAuth.instance.currentUser != null) {
      _saveFavoriteToFirestore(job.id, job.isFavorite);
    }

    // if we're viewing favorites-only and user un-favorites the job,
    // remove it from the current list immediately
    if (_showFavoritesOnly && !job.isFavorite) {
      setState(() {
        if (_cachedPages.isNotEmpty) {
          _cachedPages[_currentPage] = _cachedPages[_currentPage]
              .where((j) => j.id != job.id)
              .toList();
        }
      });
    }
  }

  // Optional: Lưu vào Firestore
  Future<void> _saveFavoriteToFirestore(String jobId, bool isFavorite) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      if (isFavorite) {
        // Thêm vào collection favorites
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(jobId)
            .set({'jobId': jobId, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        // Xóa khỏi favorites
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(jobId)
            .delete();
      }
    } catch (e) {
      print('Error saving favorite: $e');
    }
  }

  // Optional: Lưu vào SharedPreferences
  Future<void> _saveFavoriteToLocal(String jobId, bool isFavorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_jobs') ?? [];

      if (isFavorite) {
        if (!favorites.contains(jobId)) {
          favorites.add(jobId);
        }
      } else {
        favorites.remove(jobId);
      }

      await prefs.setStringList('favorite_jobs', favorites);
    } catch (e) {
      print('Error saving favorite locally: $e');
    }
  }

  // Load favorite jobs (when user taps quick action)
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favIds = prefs.getStringList('favorite_jobs') ?? [];
      if (favIds.isEmpty) {
        setState(() {
          _cachedPages.clear();
          _cachedPages.add(<Job>[]);
          _pageLastDocs.clear();
          _pageLastDocs.add(null);
          _currentPage = 0;
          _hasMore = false;
        });
        return;
      }

      // Firestore limits whereIn to 10 items per query; batch if needed
      final batches = <List<String>>[];
      for (var i = 0; i < favIds.length; i += 10) {
        batches.add(
          favIds.sublist(i, i + 10 > favIds.length ? favIds.length : i + 10),
        );
      }

      final jobs = <Job>[];
      for (final batch in batches) {
        final snap = await FirebaseFirestore.instance
            .collection('JobCareers')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final d in snap.docs) {
          final j = Job.fromMap(d.id, d.data());
          j.isFavorite = true;
          jobs.add(j);
        }
      }

      // keep as single page
      setState(() {
        _cachedPages.clear();
        _cachedPages.add(jobs);
        _pageLastDocs.clear();
        _pageLastDocs.add(null);
        _currentPage = 0;
        _hasMore = false;
      });
    } catch (e, st) {
      debugPrint('Load favorites error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải việc làm yêu thích: $e')),
        );
      }
    }
  }

  // Load applied jobs for current user
  Future<void> _loadAppliedJobs() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập để xem việc đã ứng tuyển'),
            ),
          );
        }
        setState(() {
          _cachedPages.clear();
          _cachedPages.add(<Job>[]);
          _pageLastDocs.clear();
          _pageLastDocs.add(null);
          _currentPage = 0;
          _hasMore = false;
        });
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('JobApplications')
          .where('applicantId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final apps = snap.docs;
      final jobs = <Job>[];
      for (final d in apps) {
        final data = d.data();
        final jobId = (data['jobId'] as String?) ?? '';
        final title = (data['jobTitle'] as String?) ?? '';
        final company = (data['jobCompany'] as String?) ?? '';
        final location = (data['jobLocation'] as String?) ?? '';
        final j = Job(
          id: jobId.isNotEmpty ? jobId : d.id,
          company: company,
          title: title,
          location: location,
          salary: '',
          description: '',
          isFavorite: false,
        );
        jobs.add(j);
      }

      // mark favorites based on local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final favs = prefs.getStringList('favorite_jobs') ?? [];
        for (final j in jobs) {
          if (favs.contains(j.id)) j.isFavorite = true;
        }
      } catch (_) {}

      setState(() {
        _cachedPages.clear();
        _cachedPages.add(jobs);
        _pageLastDocs.clear();
        _pageLastDocs.add(null);
        _currentPage = 0;
        _hasMore = false;
      });
    } catch (e, st) {
      debugPrint('Load applied jobs error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải việc đã ứng tuyển: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: _mainScrollCtrl,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _checkingAdmin
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (_isAdmin
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm việc'),
                          onPressed: _showAddJobDialog,
                        )
                      : const SizedBox.shrink()),
          ),
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildJobsList(),
        ],
      ),
    );
  }
}
