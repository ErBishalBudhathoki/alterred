import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neuropilot/core/link_opener_stub.dart' as stub;

void main() {
  test('Link opener stub returns false', () async {
    final opener = stub.createLinkOpenerImpl();
    final ok = await opener.open('https://example.com');
    expect(ok, isFalse);
  });
}

/// Unit test for link opener stub to ensure it returns `false`
/// during tests (no platform opening).
