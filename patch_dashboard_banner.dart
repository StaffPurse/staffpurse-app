import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();

  // 1. Add state variable
  content = content.replaceFirst(
    'bool _isLoading = true;',
    'bool _isLoading = true;\n  bool _isProvisioning = false;'
  );

  // 2. In _fetchData, check onboarding status
  var statusCheck = '''
        // 3. Check if wallet is still provisioning
        try {
          final status = await BmoniApi.getOnboardingStatus(userId: ownerUserId);
          if (status['status']?['hasLocalWallet'] != true) {
            _isProvisioning = true;
            _pollProvisioning(ownerUserId);
          } else {
            _isProvisioning = false;
          }
        } catch (e) {
          // ignore
        }
        
        // 3a. ORPHAN RECONCILIATION
''';

  content = content.replaceFirst(
    '// 3a. ORPHAN RECONCILIATION',
    statusCheck
  );

  // 3. Add _pollProvisioning method
  var pollMethod = '''
  Future<void> _pollProvisioning(String userId) async {
    while (_isProvisioning && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final status = await BmoniApi.getOnboardingStatus(userId: userId);
        if (status['status']?['hasLocalWallet'] == true) {
          setState(() {
            _isProvisioning = false;
          });
          break;
        }
      } catch (e) {
        // keep polling
      }
    }
  }

  Future<void> _fetchData() async {
''';

  content = content.replaceFirst(
    'Future<void> _fetchData() async {',
    pollMethod
  );

  // 4. Add the banner in build()
  var bannerUI = '''
      body: _business == null
          ? const Center(child: Text('Failed to load dashboard'))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isProvisioning)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('🏦 Provisioning your Nigerian Bank Account...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
''';

  content = content.replaceFirst(
    '''
      body: _business == null
          ? const Center(child: Text('Failed to load dashboard'))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
''',
    bannerUI
  );

  // 5. Disable "Issue Card" if provisioning
  content = content.replaceAll(
    'const Icon(Icons.add_card),',
    '(_isProvisioning && !hasCard) ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_card),'
  );

  content = content.replaceAll(
    'if (hasCard) {',
    'if (_isProvisioning && !hasCard) return;\n                      if (hasCard) {'
  );

  file.writeAsStringSync(content);
}
