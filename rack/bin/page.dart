import 'dart:io';

/// Writes the page: the template with the compiled engine and the daily data inlined.
/// dart run bin/page.dart <engine.js> <rack_daily.json> <out.html>
void main(List<String> args) {
  var html = File('page/template.html').readAsStringSync();
  for (final marker in ['/*ENGINE*/', '/*DATA*/null']) {
    if (!html.contains(marker)) throw StateError('no $marker marker in page/template.html');
  }
  // The engine goes in through a function so `$` sequences in it aren't treated as patterns.
  html = html.replaceFirstMapped('/*ENGINE*/', (_) => File(args[0]).readAsStringSync().replaceAll('</script', '<\\/script'));
  html = html.replaceFirstMapped('/*DATA*/null', (_) => File(args[1]).readAsStringSync());
  File(args[2])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(html);
}
