import 'flurry_theme.dart';

/// Pure Dart copywriting interceptor that gives RustDesk mobile Flurry's signature
/// Animal Crossing catchphrase ("雪球~" in Chinese / "powderpuff~" in English).
class FlurryStrings {
  FlurryStrings._();

  static const Map<String, String> _zhPhrases = {
    'Connection': '连线小岛',
    'Settings': '雪美工坊',
    'Share screen': '画面分享',
    'Remote ID': '远端电脑门牌号 (ID)',
    'Search ID': '搜索门牌号…',
    'Connecting...': '雪美正在努力连线电脑中，雪球~',
    'Connected': '已经顺利连上电脑啦，雪球~',
    'Disconnected': '呜…和电脑断开连线了，雪球~',
    'Connection lost': '信号被风雪吹散啦，请重连试试，雪球~',
    'Password': '通行暗号 (密码)',
    'Enter Password': '请输入电脑通行暗号，雪球~',
    'Wrong Password': '暗号不对哦，再确认一下吧，雪球~',
    'empty_recent_tip': '还没有拜访过任何电脑小岛哦，快输入上方门牌号出发吧，雪球~',
    'empty_favorite_tip': '收藏夹空空的呢，把常去的电脑标上小星星吧，雪球~',
    'empty_lan_tip': '附近局域网里还没有发现小伙伴的电脑呢，雪球~',
    'empty_address_book_tip': '手账本里还没有记录设备哦，雪球~',
    'Empty': '这里空空如也呢，雪球~',
    'Touch mode': '触控板模式',
    'Mouse mode': '小鼠标模式',
    'Show virtual mouse': '召唤雪美悬浮鼠标',
    'Show virtual joystick': '召唤雪美小摇杆',
  };

  static const Map<String, String> _enPhrases = {
    'Connecting...': 'Flurry is connecting to your PC, powderpuff~',
    'empty_recent_tip': 'No visited PC islands yet, powderpuff~',
    'empty_favorite_tip': 'No favorite PCs saved yet, powderpuff~',
    'empty_lan_tip': 'No nearby LAN computers found, powderpuff~',
    'Disconnected': 'Oops, disconnected from PC, powderpuff~',
  };

  /// Intercepts translation keys when Flurry copywriting mode is enabled.
  static String intercept(
    String key,
    String fallbackTranslated, {
    String? locale,
  }) {
    if (!FlurryConfig.enableCopywriting) {
      return fallbackTranslated;
    }
    final loc = (locale ?? 'zh').toLowerCase();
    final isZh = loc.startsWith('zh') || _containsCjk(fallbackTranslated);
    if (isZh) {
      return _zhPhrases[key] ?? fallbackTranslated;
    }
    return _enPhrases[key] ?? fallbackTranslated;
  }

  static bool _containsCjk(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) return true;
    }
    return false;
  }
}
