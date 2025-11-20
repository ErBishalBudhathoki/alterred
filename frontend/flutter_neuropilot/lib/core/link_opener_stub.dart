import 'link_opener.dart';

class _StubLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async => false;
}

LinkOpener createLinkOpenerImpl() => _StubLinkOpener();