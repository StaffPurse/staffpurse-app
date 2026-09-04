import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_facing_error.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late bool _isLogin;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      } else {
        await Supabase.instance.client.auth.signUp(email: email, password: password);
      }
      _checkRoute();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(e)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkRoute() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic>? res;
    try {
      res = await Supabase.instance.client
          .from('business')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();
    } catch (e) {
      // DB unreachable — can't determine the user's state. Default to
      // onboarding; its screens handle failures gracefully.
      debugPrint('AuthScreen: route check failed: $e');
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
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login to StaffPurse' : 'Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BMoniTextFormField(
                controller: _emailCtrl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _passwordCtrl,
                label: 'Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 32),
            BMoniButton(
              onPressed: _submit,
              text: _isLogin ? 'Login' : 'Sign Up',
              isLoading: _isLoading,
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Need an account? Sign up' : 'Already have an account? Login'),
            )
            ],
          ),
        ),
      ),
    );
  }
}
