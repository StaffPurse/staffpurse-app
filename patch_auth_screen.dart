import 'dart:io';

void main() {
  var file = File('lib/screens/auth_screen.dart');
  var content = file.readAsStringSync();
  
  var newClassDecl = '''
class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;
  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  late bool _isLogin;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }
''';

  var oldClassDeclRegex = RegExp(r'''class AuthScreen extends StatefulWidget \{
  const AuthScreen\(\{super.key\}\);

  @override
  State<AuthScreen> createState\(\) => _AuthScreenState\(\);
\}

class _AuthScreenState extends State<AuthScreen> \{
  final _emailCtrl = TextEditingController\(\);
  final _passwordCtrl = TextEditingController\(\);
  bool _isLoading = false;
  bool _isLogin = true;''');

  content = content.replaceFirst(oldClassDeclRegex, newClassDecl.trim());
  file.writeAsStringSync(content);
}
