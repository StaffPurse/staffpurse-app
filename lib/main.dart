import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

import 'env.dart';
import 'screens/landing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      themeMode: ThemeMode.system,
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

    final res = await Supabase.instance.client
        .from('business')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

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
