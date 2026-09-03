import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  var oldQuery = '''
        final staffRes = await _supabase.from('staff_member')
            .select('*, card_assignment(*)')
            .eq('business_id', businessRes['id']);
''';

  var newQuery = '''
        final staffRes = await _supabase.from('staff_member')
            .select('*, card_assignment(*)')
            .eq('business_id', businessRes['id'])
            .eq('status', 'active');
''';

  content = content.replaceFirst(oldQuery, newQuery);
  file.writeAsStringSync(content);
}
