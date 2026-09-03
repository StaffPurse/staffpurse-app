import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:bkey_uikit/bkey_uikit.dart';

import 'env.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Initialize BMONI Embedded SDK (using defaults per QUICKSTART)
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
      themeMode: ThemeMode.system,
      home: const OnboardingScreen(),
    );
  }
}

