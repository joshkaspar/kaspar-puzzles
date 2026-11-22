// The engine, compiled to JavaScript for the page (dart compile js).
// It exposes one function on the page's global object:
//   rackView(dayJson, movesJson) -> viewJson
// The page keeps the list of moves and asks for a fresh view after each one.
import 'dart:js_interop';

import 'package:rack_engine/rack_engine.dart';

@JS('rackView')
external set _rackView(JSFunction f);

void main() {
  _rackView = ((JSString day, JSString moves) => viewJson(day.toDart, moves.toDart).toJS).toJS;
}
