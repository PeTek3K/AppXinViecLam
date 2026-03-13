import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../screens/notifications_screen.dart';

class NotificationService {
  NotificationService._private();
  static final NotificationService instance = NotificationService._private();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  void start() {
    // Listen to auth changes and (re)subscribe to notifications for the user
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      _notifSub?.cancel();
      _notifSub = null;
      if (user == null) return;

      final col = FirebaseFirestore.instance.collection('notifications');

      // Listen to all notifications for the user (do not pre-filter by `read`)
      // to avoid races where another writer marks `read` and the listener
      // would immediately lose the document. We'll filter per-change below.
      _notifSub = col
          .where('toUid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) async {
            for (final change in snap.docChanges) {
              if (change.type != DocumentChangeType.added) continue;
              final doc = change.doc;
              final data = doc.data();
              if (data == null) continue;

              final isRead = data['read'] as bool? ?? false;
              final delivered = data['deliveredAt'] != null;
              if (isRead || delivered) continue;

              await _showInAppNotification(data, doc.id);
            }
          });
    });
  }

  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    _removeOverlay();
  }

  Future<void> _showInAppNotification(
    Map<String, dynamic> data,
    String id,
  ) async {
    try {
      final ctx = navigatorKey.currentContext;
      final title = data['title']?.toString() ?? 'Thông báo';
      final body = data['body']?.toString() ?? '';

      if (ctx != null) {
        // Show overlay banner
        _showOverlay(title: title, body: body);
      }

      // Mark notification as delivered (do NOT mark as read automatically).
      await FirebaseFirestore.instance.collection('notifications').doc(id).set({
        'deliveredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore errors — avoid crashing the app due to notification UI
    }
  }

  void _showOverlay({required String title, required String body}) {
    _removeOverlay();

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 8,
          left: 12,
          right: 12,
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _removeOverlay();
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _removeOverlay,
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    nav.overlay?.insert(_overlayEntry!);

    // Auto remove after 6 seconds
    _overlayTimer = Timer(const Duration(seconds: 6), () {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    try {
      _overlayTimer?.cancel();
      _overlayTimer = null;
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (_) {}
  }

  /// Send a notification document to a specific user (stored in Firestore).
  /// This will be picked up by the listener in `start()` and shown in-app.
  Future<void> sendNotificationToUser({
    required String toUid,
    required String title,
    required String body,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUid': toUid,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      // ignore errors to avoid failing caller flows
    }
  }
}

// Convenience accessor
NotificationService get notificationService => NotificationService.instance;
