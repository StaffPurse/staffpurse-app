import 'dart:io';

void main() {
  var file = File('lib/screens/card_management_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Add staffId to the class
  content = content.replaceFirst(
    'final String bmoniCardId;',
    'final String bmoniCardId;\n  final String staffId;'
  );
  
  content = content.replaceFirst(
    'required this.bmoniCardId,',
    'required this.bmoniCardId,\n    required this.staffId,'
  );

  // 2. Add _removeStaff logic
  var removeLogic = '''
  Future<void> _removeStaff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: const Text('Are you sure you want to remove this staff member? This will permanently block their card and hide them from your dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _cardService.removeStaff(
        ownerUserId: widget.ownerUserId,
        staffId: widget.staffId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
      );
      if (mounted) {
        Navigator.pop(context); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
''';

  content = content.replaceFirst(
    'Future<void> _updateLimits() async {',
    removeLogic + '\n  Future<void> _updateLimits() async {'
  );

  // 3. Add the button at the bottom of the column
  var buttonLogic = '''
            BMoniButton(
              onPressed: _isLoading ? null : _updateLimits,
              text: 'Save Limits',
              isLoading: _isLoading,
            ),
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: _isLoading ? null : _removeStaff,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Remove Staff',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
''';

  content = content.replaceFirst(
    '''
            BMoniButton(
              onPressed: _isLoading ? null : _updateLimits,
              text: 'Save Limits',
              isLoading: _isLoading,
            ),
          ],
        ),''',
    buttonLogic
  );

  file.writeAsStringSync(content);
}
