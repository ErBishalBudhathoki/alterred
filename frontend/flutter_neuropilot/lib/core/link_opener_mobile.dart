import 'link_opener.dart';

class _MobileLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    return false;
  }
}

LinkOpener createLinkOpenerImpl() => _MobileLinkOpener();