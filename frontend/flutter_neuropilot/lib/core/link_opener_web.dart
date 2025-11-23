import 'package:web/web.dart' as web;
import 'link_opener.dart';

class _WebLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    final base = web.window.location;
    final isRelative = url.startsWith('/#/');
    final target = isRelative
        ? '${base.origin}$url'
        : url;
    web.window.open(target, '_blank');
    return true;
  }
}

LinkOpener createLinkOpenerImpl() => _WebLinkOpener();