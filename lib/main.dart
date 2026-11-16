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

class _FcmDiagnostics {
  static int? sdkInt;
  static String androidRelease = '';
  static bool playServicesAvailable = true;
  static String playServicesStatus = 'unknown';
  static String channelStatus = 'unknown';
  static bool tokenCreated = false;
  static String tokenPreview = '';
  static bool topicSubscribed = false;
  static String lastMessageReceivedAt = '';
  static String lastNotificationDisplayedAt = '';
  static String lastError = '';

  static void log(String message) {
    debugPrint('[WatchCat-FCM] $message');
  }

  static Future<void> persistToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmDiagnostics': {
            'sdkInt': sdkInt,
            'androidRelease': androidRelease,
            'playServicesAvailable': playServicesAvailable,
            'playServicesStatus': playServicesStatus,
            'channelStatus': channelStatus,
            'tokenCreated': tokenCreated,
            'tokenPreview': tokenPreview,
            'topicSubscribed': topicSubscribed,
            'lastMessageReceivedAt': lastMessageReceivedAt,
            'lastNotificationDisplayedAt': lastNotificationDisplayedAt,
            'lastError': lastError,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      log('Tanilama Firestore kaydi basarisiz: $e');
    }
  }
}

bool _isSyncingFcm = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '[WatchCat-FCM] Arka plan mesaji alindi: id=${message.messageId}, '
    'title=${message.notification?.title}, data=${message.data}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
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

Future<String?> _fetchValidFcmToken() async {
  final messaging = FirebaseMessaging.instance;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final apnsToken = await messaging.getAPNSToken();
    if (apnsToken == null) {
      _FcmDiagnostics.log('iOS APNs token henuz hazir degil.');
      return null;
    }
  }

  String? token = await messaging.getToken();
  if (token == null || token.trim().isEmpty) {
    _FcmDiagnostics.log('Ilk denemede token bos dondu, tekrar deneniyor...');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    token = await messaging.getToken();
  }

  if (token == null || token.trim().isEmpty) {
    return null;
  }

  return token.trim();
}

Future<String?> _syncTokenAndTopicSubscription({
  required bool alreadySubscribed,
  required bool playServicesAvailable,
  required String playServicesStatus,
}) async {
  if (_isSyncingFcm) return null;
  _isSyncingFcm = true;

  try {
    if (!playServicesAvailable) {
      final err =
          'Google Play Hizmetleri hazir degil ($playServicesStatus). Bildirim tokeni alinamiyor.';
      _FcmDiagnostics.tokenCreated = false;
      _FcmDiagnostics.topicSubscribed = false;
      _FcmDiagnostics.lastError = err;
      _FcmDiagnostics.log(err);
      await _FcmDiagnostics.persistToFirestore();
      return err;
    }

    // 1. Önce FCM registration token oluşturulduğunu doğrula
    final token = await _fetchValidFcmToken().timeout(
      const Duration(seconds: 15),
    );

    if (token == null || token.isEmpty) {
      const err = 'FCM registration token olusturulamadi (bos/null).';
      _FcmDiagnostics.tokenCreated = false;
      _FcmDiagnostics.lastError = err;
      _FcmDiagnostics.log(err);
      await _FcmDiagnostics.persistToFirestore();
      return err;
    }

    _FcmDiagnostics.tokenCreated = true;
    _FcmDiagnostics.tokenPreview =
        token.length > 12 ? '${token.substring(0, 12)}...' : token;
    _FcmDiagnostics.log('FCM token olusturuldu: ${_FcmDiagnostics.tokenPreview}');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }

    // 2. Token doğrulandıktan sonra "all_users" topic aboneliğini tamamla
    if (alreadySubscribed) {
      _FcmDiagnostics.topicSubscribed = true;
      _FcmDiagnostics.lastError = '';
      _FcmDiagnostics.log('all_users topic aboneligi zaten kayitli.');
      await _FcmDiagnostics.persistToFirestore();
      return null;
    }

    await FirebaseMessaging.instance
        .subscribeToTopic('all_users')
        .timeout(const Duration(seconds: 15));

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _notificationChannel.invokeMethod<bool>('markAllUsersSubscribed');
    }

    _FcmDiagnostics.topicSubscribed = true;
    _FcmDiagnostics.lastError = '';
    _FcmDiagnostics.log('all_users topic aboneligi basariyla tamamlandi.');
    await _FcmDiagnostics.persistToFirestore();
    return null;
  } catch (e) {
    final err = 'FCM token/abonelik hatasi: $e';
    _FcmDiagnostics.lastError = err;
    _FcmDiagnostics.log(err);
    await _FcmDiagnostics.persistToFirestore();
    return err;
  } finally {
    _isSyncingFcm = false;
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

  Future<void> _openSystemNotificationSettings() async {
    try {
      await _notificationChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> _showEnableNotificationsDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          '🔔 WatchCat Bildirimlerini Aç!',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Yeni kedi videolarını ve uygulama güncellemelerini kaçırmamak için bildirimlerini etkinleştir.',
          style: TextStyle(
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
            child: const Text('Bildirim Ayarlarını Aç'),
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
            'Bildirimler kapalı. Bildirim Ayarlarını Aç üzerinden etkinleştirebilirsin.',
          ),
          action: SnackBarAction(
            label: 'Bildirim Ayarlarını Aç',
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

      // Android 8+ bildirim kanalını ön planda oluştur (Android 7.1.2'de güvenle atlar)
      final state = await _notificationChannel
          .invokeMapMethod<String, dynamic>('getNotificationState');
      if (state == null) return;

      final sdkInt = state['sdkInt'] as int?;
      final androidRelease = (state['androidRelease'] ?? '').toString();
      final isAndroid13OrAbove = state['isAndroid13OrAbove'] == true;
      final granted = state['granted'] == true;
      final shouldRequestRuntime = state['shouldRequestRuntime'] == true;
      final alreadySubscribed = state['allUsersSubscribed'] == true;
      final playServicesAvailable = state['playServicesAvailable'] != false;
      final playServicesStatus =
          (state['playServicesStatus'] ?? 'SUCCESS').toString();
      final channelStatus = (state['channelStatus'] ?? 'unknown').toString();

      _FcmDiagnostics.sdkInt = sdkInt;
      _FcmDiagnostics.androidRelease = androidRelease;
      _FcmDiagnostics.playServicesAvailable = playServicesAvailable;
      _FcmDiagnostics.playServicesStatus = playServicesStatus;
      _FcmDiagnostics.channelStatus = channelStatus;
      _FcmDiagnostics.topicSubscribed = alreadySubscribed;
      _FcmDiagnostics.log(
        'Durum: Android $androidRelease (SDK $sdkInt), '
        'granted=$granted, channel=$channelStatus, playServices=$playServicesStatus',
      );

      if (shouldRequestRuntime) {
        final grantedNow = await _notificationChannel
                .invokeMethod<bool>('requestNotificationPermission') ??
            false;
        _lastKnownGranted = grantedNow;

        if (grantedNow) {
          final error = await _syncTokenAndTopicSubscription(
            alreadySubscribed: alreadySubscribed,
            playServicesAvailable: playServicesAvailable,
            playServicesStatus: playServicesStatus,
          );
          if (error != null && mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        } else {
          await _showEnableNotificationsDialog();
        }
        return;
      }

      if (granted) {
        final becameEnabled = _lastKnownGranted == false;
        _lastKnownGranted = true;

        final error = await _syncTokenAndTopicSubscription(
          alreadySubscribed: alreadySubscribed,
          playServicesAvailable: playServicesAvailable,
          playServicesStatus: playServicesStatus,
        );

        if (error != null && mounted && isInitialLaunch) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(error)),
          );
        } else if (becameEnabled && mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('WatchCat bildirimleri etkinleştirildi.'),
            ),
          );
        }
        return;
      }

      _lastKnownGranted = false;
      await _FcmDiagnostics.persistToFirestore();

      if (isInitialLaunch) {
        if (!isAndroid13OrAbove) {
          await _showEnableNotificationsDialog();
        } else {
          _showSettingsHintSnackBar();
        }
      }
    } catch (e) {
      _FcmDiagnostics.lastError = 'Izin kontrol hatasi: $e';
      _FcmDiagnostics.log(_FcmDiagnostics.lastError);
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
        await _syncTokenAndTopicSubscription(
          alreadySubscribed: false,
          playServicesAvailable: true,
          playServicesStatus: 'N/A',
        );
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
          await _syncTokenAndTopicSubscription(
            alreadySubscribed: false,
            playServicesAvailable: true,
            playServicesStatus: 'N/A',
          );
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

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      bool isGranted = false;
      bool alreadySubscribed = false;
      bool playServicesAvailable = true;
      String playServicesStatus = 'SUCCESS';

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final state = await _notificationChannel
            .invokeMapMethod<String, dynamic>('getNotificationState');
        isGranted = state?['granted'] == true;
        alreadySubscribed = state?['allUsersSubscribed'] == true;
        playServicesAvailable = state?['playServicesAvailable'] != false;
        playServicesStatus =
            (state?['playServicesStatus'] ?? 'SUCCESS').toString();

        _FcmDiagnostics.sdkInt = state?['sdkInt'] as int?;
        _FcmDiagnostics.androidRelease =
            (state?['androidRelease'] ?? '').toString();
        _FcmDiagnostics.playServicesAvailable = playServicesAvailable;
        _FcmDiagnostics.playServicesStatus = playServicesStatus;
        _FcmDiagnostics.channelStatus =
            (state?['channelStatus'] ?? 'unknown').toString();
      } else {
        final settings = await messaging.getNotificationSettings();
        isGranted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
      }

      if (isGranted) {
        await _syncTokenAndTopicSubscription(
          alreadySubscribed: alreadySubscribed,
          playServicesAvailable: playServicesAvailable,
          playServicesStatus: playServicesStatus,
        );
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        _FcmDiagnostics.tokenCreated = true;
        _FcmDiagnostics.tokenPreview = newToken.length > 12
            ? '${newToken.substring(0, 12)}...'
            : newToken;
        _FcmDiagnostics.log('FCM token yenilendi.');
        await _saveFcmToken(newToken);
        await _FcmDiagnostics.persistToFirestore();
      });

      _foregroundMessageSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        _FcmDiagnostics.lastMessageReceivedAt =
            DateTime.now().toIso8601String();
        final title =
            message.notification?.title ?? message.data['title']?.toString();
        final body =
            message.notification?.body ?? message.data['body']?.toString();
        _FcmDiagnostics.log(
          'On plan mesaji alindi: id=${message.messageId}, title=$title',
        );

        final displayTitle = (title == null || title.isEmpty) ? 'WatchCat' : title;
        final displayBody = body ?? '';

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          try {
            final res = await _notificationChannel
                .invokeMapMethod<String, dynamic>('showLocalNotification', {
              'title': displayTitle,
              'body': displayBody,
            });
            if (res?['shown'] == true) {
              _FcmDiagnostics.lastNotificationDisplayedAt =
                  DateTime.now().toIso8601String();
              _FcmDiagnostics.log('On plan sistem bildirimi gosterildi.');
            } else {
              _FcmDiagnostics.lastError =
                  'On plan bildirimi gosterilemedi: ${res?['error']}';
              _FcmDiagnostics.log(_FcmDiagnostics.lastError);
            }
          } catch (e) {
            _FcmDiagnostics.lastError = 'On plan bildirim hatasi: $e';
            _FcmDiagnostics.log(_FcmDiagnostics.lastError);
          }
        }

        await _FcmDiagnostics.persistToFirestore();

        if (!mounted) return;
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
        _FcmDiagnostics.lastMessageReceivedAt =
            DateTime.now().toIso8601String();
        _FcmDiagnostics.lastNotificationDisplayedAt =
            DateTime.now().toIso8601String();
        _FcmDiagnostics.log(
          'Arka plan bildirimine tiklandi: id=${message.messageId}',
        );
        _FcmDiagnostics.persistToFirestore();

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
    } catch (e) {
      _FcmDiagnostics.lastError = 'FCM oturum kurulum hatasi: $e';
      _FcmDiagnostics.log(_FcmDiagnostics.lastError);
      await _FcmDiagnostics.persistToFirestore();
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      _FcmDiagnostics.lastError = 'Token Firestore kayit hatasi: $e';
      _FcmDiagnostics.log(_FcmDiagnostics.lastError);
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
