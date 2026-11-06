import 'dart:io';

/// Writes the playtest page: the template with the exported puzzle data inlined.
/// dart run bin/playtest.dart <playtest_data.json> <out.html>
void main(List<String> args) {
  final template = File('playtest/template.html').readAsStringSync();
  if (!template.contains('/*DATA*/null')) throw StateError('no /*DATA*/ marker');
  final data = File(args[0]).readAsStringSync();
  File(args[1])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(template.replaceFirst('/*DATA*/null', data));
}
