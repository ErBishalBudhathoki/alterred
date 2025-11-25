import 'package:flutter_test/flutter_test.dart';
import 'package:altered/core/routes.dart';

void main() {
  test('Routes map contains expected keys', () async {
    expect(Routes.map.containsKey(Routes.chat), isTrue);
    expect(Routes.map.containsKey(Routes.settings), isTrue);
    expect(Routes.map.containsKey(Routes.external), isTrue);
  });
}

/// Pure unit test validating that `Routes.map` contains
/// expected named routes used in the app.
