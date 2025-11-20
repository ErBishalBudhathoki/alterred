import 'link_opener_stub.dart'
    if (dart.library.html) 'link_opener_web.dart'
    if (dart.library.io) 'link_opener_mobile.dart';

abstract class LinkOpener {
  Future<bool> open(String url);
}

LinkOpener createLinkOpener() => createLinkOpenerImpl();