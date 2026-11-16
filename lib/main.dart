import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';

const MethodChannel _notificationChannel =
    MethodChannel('com.dbgibletw.watchcat/notifications');

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const WatchCatApp());
}

class WatchCatApp extends StatelessWidget {
  const WatchCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryAccent = Color(0xFFFF6B4A);
    const backgroundDark = Color(0xFF0A0A0E);
    const surfaceDark = Color(0xFF161620);

    return MaterialApp(
      title: 'WatchCat',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryAccent,
          brightness: Brightness.dark,
          primary: primaryAccent,
          surface: surfaceDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E2A),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2E2E3E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryAccent, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF4D6D)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF4D6D), width: 1.6),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF232332),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const _NotificationBootstrapper(
        child: AuthGate(),
      ),
    );
  }
}

class _NotificationBootstrapper extends StatefulWidget {
  const _NotificationBootstrapper({required this.child});

  final Widget child;

  @override
  State<_NotificationBootstrapper> createState() =>
      _NotificationBootstrapperState();
}

class _NotificationBootstrapperState extends State<_NotificationBootstrapper>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _hasHandledInitialCheck = false;
  bool? _lastKnownGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPermission(isInitialLaunch: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasHandledInitialCheck) {
      _handleNotificationPermission(isInitialLaunch: false);
    }
  }

  Future<void> _activateFcmSubscription() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('all_users');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
    } catch (_) {
      // Ağ veya Play Services kaynaklı geçici hatalarda uygulamanın çökmesini önler.
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    try {
      await _notificationChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> _showNotificationExplanationDialog({
    required bool isAndroid13OrAbove,
  }) async {
    if (!mounted) return;

    final title = isAndroid13OrAbove
        ? 'Bildirim İzni Kapalı'
        : 'Bildirimler Sistem Ayarlarından Kapalı';
    final description = isAndroid13OrAbove
        ? 'Yeni kedi videolarından ve WatchCat duyurularından haberdar olabilmen için bildirim iznine ihtiyacımız var. İstersen uygulama ayarlarından bildirimleri açabilirsin.'
        : 'WatchCat bildirimleri cihazının sistem ayarlarından kapatılmış görünüyor. Bildirimleri tekrar almak için ayarlara gidip açabilirsin.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          description,
          style: const TextStyle(
            color: Color(0xFFD0D0DE),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Daha Sonra'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openSystemNotificationSettings();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B4A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }

  void _showSettingsHintSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: const Text(
            'Bildirimler kapalı. Açmak için uygulama ayarlarına gidebilirsin.',
          ),
          action: SnackBarAction(
            label: 'Ayarları Aç',
            textColor: const Color(0xFFFF6B4A),
            onPressed: _openSystemNotificationSettings,
          ),
        ),
      );
  }

  Future<void> _handleNotificationPermission({
    required bool isInitialLaunch,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        await _handleNonAndroidPermission(isInitialLaunch: isInitialLaunch);
        return;
      }

      final state = await _notificationChannel
          .invokeMapMethod<String, dynamic>('getNotificationState');
      if (state == null) return;

      final isAndroid13OrAbove = state['isAndroid13OrAbove'] == true;
      final granted = state['granted'] == true;
      final shouldRequestRuntime = state['shouldRequestRuntime'] == true;

      if (shouldRequestRuntime) {
        final grantedNow = await _notificationChannel
                .invokeMethod<bool>('requestNotificationPermission') ??
            false;
        _lastKnownGranted = grantedNow;

        if (grantedNow) {
          await _activateFcmSubscription();
        } else {
          await _showNotificationExplanationDialog(
            isAndroid13OrAbove: true,
          );
        }
        return;
      }

      if (granted) {
        final becameEnabled = _lastKnownGranted == false;
        _lastKnownGranted = true;
        await _activateFcmSubscription();
        if (becameEnabled && mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('WatchCat bildirimleri etkinleştirildi.'),
            ),
          );
        }
        return;
      }

      _lastKnownGranted = false;

      if (isInitialLaunch) {
        if (!isAndroid13OrAbove) {
          // Android 10, 11 ve 12: sistem ayarlarından kapalıysa ayarlardan açma seçeneği sun
          await _showNotificationExplanationDialog(
            isAndroid13OrAbove: false,
          );
        } else {
          // Android 13+: daha önce reddedildiyse tekrar sistem penceresi zorlama, bilgilendirme göster
          _showSettingsHintSnackBar();
        }
      }
    } catch (_) {
      // İzin kontrolü başarısız olsa bile uygulama çalışmaya devam eder.
    } finally {
      _hasHandledInitialCheck = true;
      _isChecking = false;
    }
  }

  Future<void> _handleNonAndroidPermission({
    required bool isInitialLaunch,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final current = await messaging.getNotificationSettings();

      if (current.authorizationStatus == AuthorizationStatus.authorized ||
          current.authorizationStatus == AuthorizationStatus.provisional) {
        _lastKnownGranted = true;
        await _activateFcmSubscription();
        return;
      }

      if (isInitialLaunch &&
          current.authorizationStatus == AuthorizationStatus.notDetermined) {
        final requested = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final grantedNow =
            requested.authorizationStatus == AuthorizationStatus.authorized ||
                requested.authorizationStatus == AuthorizationStatus.provisional;
        _lastKnownGranted = grantedNow;
        if (grantedNow) {
          await _activateFcmSubscription();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }

        return FcmSessionWrapper(
          key: ValueKey(user.uid),
          uid: user.uid,
          child: const MainShell(),
        );
      },
    );
  }
}

class FcmSessionWrapper extends StatefulWidget {
  const FcmSessionWrapper({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<FcmSessionWrapper> createState() => _FcmSessionWrapperState();
}

class _FcmSessionWrapperState extends State<FcmSessionWrapper> {
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  Future<bool> _isNotificationPermissionGranted() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final state = await _notificationChannel
            .invokeMapMethod<String, dynamic>('getNotificationState');
        return state?['granted'] == true;
      }
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final isGranted = await _isNotificationPermissionGranted();

      if (isGranted) {
        await messaging.subscribeToTopic('all_users');

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          final apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) {
            final token = await messaging.getToken();
            if (token != null && token.isNotEmpty) {
              await _saveFcmToken(token);
            }
          }
        } else {
          final token = await messaging.getToken();
          if (token != null && token.isNotEmpty) {
            await _saveFcmToken(token);
          }
        }
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          _saveFcmToken(newToken);
        }
      });

      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title != null || body != null) {
          final text = [title, body].whereType<String>().join(': ');
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(text),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });

      _openedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (!mounted) return;
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title != null || body != null) {
          final text = [title, body].whereType<String>().join(': ');
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(text)),
          );
        }
      });
    } catch (_) {
      // Cihazda Google Play Services veya APNs yoksa akışın çökmesini engeller.
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ağ hatası durumunda sessizce geçer.
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
