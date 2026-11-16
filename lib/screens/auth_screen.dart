import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (_isLoading) return;
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta adresi veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten başka bir hesapta kullanılıyor.';
      case 'invalid-email':
        return 'Lütfen geçerli bir e-posta adresi girin.';
      case 'weak-password':
        return 'Şifreniz çok zayıf. En az 6 karakter kullanın.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyip tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
      default:
        return 'Kimlik doğrulama hatası: ${e.message ?? e.code}';
    }
  }

  Future<String> _getSafeFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) return '';
      }
      return await messaging.getToken() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final normalizedUsername =
            _usernameController.text.trim().toLowerCase();

        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;
        if (user != null) {
          await user.updateDisplayName(normalizedUsername);
          final fcmToken = await _getSafeFcmToken();

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'username': normalizedUsername,
              'email': email,
              'fcmToken': fcmToken,
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_mapFirebaseAuthError(e));
    } catch (e) {
      _showErrorSnackBar('Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateUsername(String? value) {
    if (_isLogin) return null;
    final trimmed = (value ?? '').trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'Lütfen bir kullanıcı adı girin.';
    }
    if (trimmed.length < 3 || trimmed.length > 20) {
      return 'Kullanıcı adı 3 ile 20 karakter arasında olmalıdır.';
    }
    final validRegex = RegExp(r'^[a-z0-9_.]+$');
    if (!validRegex.hasMatch(trimmed)) {
      return 'Sadece küçük harf, rakam, "_" ve "." kullanabilirsiniz.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Lütfen e-posta adresinizi girin.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final pwd = value ?? '';
    if (pwd.isEmpty) {
      return 'Lütfen şifrenizi girin.';
    }
    if (pwd.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF171320),
                Color(0xFF0A0A0E),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0x26FF6B4A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0x66FF6B4A),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.pets_rounded,
                          size: 40,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'KediReels',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? 'En tatlı 40 saniyelik kedi videolarını keşfet'
                            : 'Hemen katıl, kedinin en komik anlarını paylaş',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFA0A0B2),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141C),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF262634),
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isLogin ? 'Giriş Yap' : 'Hesap Oluştur',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (!_isLogin) ...[
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !_isLoading,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Kullanıcı Adı',
                                    hintText: 'ornek_kedi',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                  validator: _validateUsername,
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'E-posta',
                                  hintText: 'ornek@mail.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) _submit();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? 'Henüz hesabın yok mu?'
                                : 'Zaten bir hesabın var mı?',
                            style: const TextStyle(
                              color: Color(0xFFA0A0B2),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _toggleMode,
                            child: Text(
                              _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
