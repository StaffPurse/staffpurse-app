import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

import 'env.dart';
import 'services/crash_log.dart';
import 'screens/landing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Record the device CPU architecture at startup — the BMONI signer lib is
  // arm64-only, so this single line in the Diagnostics screen answers the
  // most likely crash cause without adb.
  CrashLog.write('app started | device arch: ${deviceArch()}');

  // Capture any Dart-level error (widget builds, platform channel callbacks)
  // into the on-device crash log so failures survive a force-close.
  FlutterError.onError = (FlutterErrorDetails details) {
    // dumpErrorToConsole preserves the framework's own console output without
    // re-entering this handler.
    FlutterError.dumpErrorToConsole(details);
    CrashLog.write('DART ERROR: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashLog.write('PLATFORM ERROR: $error\n$stack');
    // Keep the demo alive and log the failure instead of force-closing.
    return true;
  };

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);

  runApp(
    const ProviderScope(
      child: StaffPurseApp(),
    ),
  );
}

class StaffPurseApp extends StatelessWidget {
  const StaffPurseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StaffPurse',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const InitialRouter(),
    );
  }
}

class InitialRouter extends StatefulWidget {
  const InitialRouter({super.key});
  @override
  State<InitialRouter> createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  @override
  void initState() {
    super.initState();
    _checkRoute();
  }

  Future<void> _checkRoute() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
      return;
    }

    Map<String, dynamic>? res;
    try {
      res = await Supabase.instance.client
          .from('business')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();
    } catch (e) {
      // If the DB is unreachable we can't know the user's state. Default to
      // onboarding — its screens handle failures gracefully and the demo
      // path is a fresh signup anyway.
      debugPrint('InitialRouter: route check failed: $e');
      CrashLog.write('router: route check failed -> $e');
    }

    if (!mounted) return;

    if (res != null && res['owner_wallet_id'] != 'PENDING_DEVICE_PROVISIONING') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
