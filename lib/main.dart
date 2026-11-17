import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/board_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/board_service.dart';
import 'services/user_record_service.dart';

const useEmulators = bool.fromEnvironment('USE_EMULATORS');
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Common Room',
      debugShowCheckedModeBanner: false,
      theme: boardTheme(),
      home: SplashScreen(initialize: _initialize),
    ),
  );
}

ThemeData boardTheme() {
  const ink = Color(0xFF172C27);
  const paper = Color(0xFFF6F7EF);
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF286955),
    primary: const Color(0xFF215E4C),
    onPrimary: Colors.white,
    surface: paper,
    onSurface: ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: paper,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
        color: ink,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
        color: ink,
      ),
      titleSmall: const TextStyle(fontWeight: FontWeight.w700, color: ink),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      toolbarHeight: 74,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );
}

Future<Widget> _initialize() async {
  final firstFrame = Future<void>.delayed(const Duration(milliseconds: 450));
  final app = useEmulators
      ? await Firebase.initializeApp(demoProjectId: 'demo-message-board')
      : await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
  final firebaseAuth = FirebaseAuth.instanceFor(app: app);
  final db = FirebaseFirestore.instanceFor(app: app);
  if (useEmulators) {
    await firebaseAuth.useAuthEmulator(
      emulatorHost,
      9099,
      automaticHostMapping: false,
    );
    db.useFirestoreEmulator(emulatorHost, 8180, automaticHostMapping: false);
  }
  await firstFrame;
  final auth = AuthService(firebaseAuth);
  return AuthGate(
    auth: auth,
    records: UserRecordService(db),
    board: (profile, user) => BoardScreen(
      key: ValueKey(user.uid),
      service: BoardService(db, auth, profile),
      signOut: auth.signOut,
      isDemo: useEmulators,
    ),
  );
}
