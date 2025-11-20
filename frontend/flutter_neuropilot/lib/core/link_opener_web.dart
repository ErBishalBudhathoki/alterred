import 'dart:html' as html;
import 'link_opener.dart';

class _WebLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    final base = html.window.location;
    final isRelative = url.startsWith('/#/');
    final target = isRelative
        ? '${base.origin}$url'
        : url;
    html.window.open(target, '_blank');
    return true;
  }
}

LinkOpener createLinkOpenerImpl() => _WebLinkOpener();