import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> register({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _persist(email: email);
    return cred.user;
  }

  Future<User?> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _persist(email: email);
    return cred.user;
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _clearPersisted();
  }

  // Lưu "tên tài khoản" (email) an toàn. KHÔNG lưu mật khẩu thô.
  Future<void> _persist({required String email}) async {
    await _storage.write(key: 'email', value: email);
    // Nếu cần giữ "remember me", có thể lưu refresh token/tín hiệu khác.
  }

  Future<void> _clearPersisted() async {
    await _storage.delete(key: 'email');
  }

  Future<void> resetPassword(String email) async {
    // sử dụng FirebaseAuth
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  // Future<void> signOut() async {
  //   await _auth.signOut();
  // }

  Future<String?> getSavedEmail() => _storage.read(key: 'email');
}
