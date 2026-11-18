import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_loading_widget.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_mascot_overlay.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_snow_overlay.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_strings.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_theme.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_todesk_mouse_core.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_widgets.dart';

void main() {
  runApp(const MouseTestApp());
}

class MouseTestApp extends StatefulWidget {
  const MouseTestApp({super.key});

  @override
  State<MouseTestApp> createState() => _MouseTestAppState();
}

class _MouseTestAppState extends State<MouseTestApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
    );
    final baseDark = ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: '雪美远控 · FlurryDesk 安卓全链路预览沙盒',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: FlurryTheme.applyLight(baseLight),
      darkTheme: FlurryTheme.applyDark(baseDark),
      home: FlurryPreviewShell(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class FlurryPreviewShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const FlurryPreviewShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<FlurryPreviewShell> createState() => _FlurryPreviewShellState();
}

class _FlurryPreviewShellState extends State<FlurryPreviewShell> {
  // 0 = Android Mobile Home/Settings Preview, 1 = Remote Desktop Control Session
  int _sceneIndex = 0;
  int _mobileTab = 0;
  final TextEditingController _idCtrl =
      TextEditingController(text: '829 401 552');

  void _simulateConnectFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          child: FlurryLoadingContent(
            text: FlurryStrings.intercept('Connecting...', '正在连接…'),
            cancelLabel: '取消连线',
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
    Future.delayed(const Duration(milliseconds: 1650), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      setState(() => _sceneIndex = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopStageBar(),
        Expanded(
          child: _sceneIndex == 0
              ? _buildMobileHomePreview()
              : MouseSandboxScreen(
                  onExitSession: () => setState(() => _sceneIndex = 0),
                ),
        ),
      ],
    );
  }

  Widget _buildTopStageBar() {
    return Material(
      color: const Color(0xFF121722),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSceneChip(0, Icons.phone_android_rounded, '① 手机主页 & 工坊'),
                const SizedBox(width: 8),
                _buildSceneChip(1, Icons.desktop_windows_rounded, '② 远控电脑桌面'),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _simulateConnectFlow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlurryColors.sakuraNeon,
                    side: BorderSide(
                      color: FlurryColors.sakuraNeon.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('预览欢跳连线动画', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: widget.onToggleTheme,
              style: TextButton.styleFrom(
                foregroundColor:
                    widget.isDark ? FlurryColors.frostCyan : FlurryColors.daisyGold,
              ),
              icon: Icon(
                widget.isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                size: 18,
              ),
              label: Text(
                widget.isDark ? '当前：冬夜星光 (夜间)' : '当前：奶油雪白 (日间)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneChip(int idx, IconData icon, String label) {
    final selected = _sceneIndex == idx;
    return ChoiceChip(
      selected: selected,
      selectedColor: FlurryColors.sakuraPink,
      backgroundColor: const Color(0xFF222A3A),
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      onSelected: (_) => setState(() => _sceneIndex = idx),
    );
  }

  Widget _buildMobileHomePreview() {
    return Container(
      color: widget.isDark ? const Color(0xFF0C1018) : const Color(0xFFF3ECEF),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 412, maxHeight: 820),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: FlurryColors.sakuraPink.withOpacity(0.4),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: FlurryConfig.copywritingNotifier,
              builder: (context, _, __) {
                return Scaffold(
                  appBar: AppBar(
                    title: const FlurryAppBarTitle(),
                  ),
                  body: Stack(
                    children: [
                      _mobileTab == 0
                          ? _buildConnectionTabBody()
                          : _buildFlurryStudioSettings(),
                      const FlurrySnowOverlay(),
                    ],
                  ),
                  bottomNavigationBar: BottomNavigationBar(
                    currentIndex: _mobileTab,
                    onTap: (i) => setState(() => _mobileTab = i),
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.connected_tv_rounded),
                        label: FlurryStrings.intercept('Connection', '连接'),
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: FlurryStrings.intercept('Settings', '设置'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionTabBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          const FlurryWorkbenchBanner(),
          const SizedBox(height: 8),
          Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: FlurryColors.sakuraPink.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idCtrl,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: FlurryColors.iceMint,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText:
                          FlurryStrings.intercept('Remote ID', '远程 ID'),
                    ),
                    onSubmitted: (_) => _simulateConnectFlow(),
                  ),
                ),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Material(
                    color: FlurryColors.sakuraPink,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      onPressed: _simulateConnectFlow,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlurryPolaroidEmptyState(
              message: FlurryStrings.intercept(
                'empty_recent_tip',
                '近期没有连接过的远端电脑',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlurryStudioSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Image.asset(
            widget.isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png',
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                activeColor: FlurryColors.sakuraPink,
                secondary: const Icon(Icons.chat_bubble_outline_rounded,
                    color: FlurryColors.sakuraPink),
                title: const Text('“雪球~” 动森语录模式'),
                subtitle: const Text('将连接状态与空列表提示切换为雪美口头禅'),
                value: FlurryConfig.enableCopywriting,
                onChanged: (v) => setState(() => FlurryConfig.setCopywriting(v)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeColor: FlurryColors.sakuraPink,
                secondary: const Icon(Icons.pets_rounded,
                    color: FlurryColors.sakuraPink),
                title: const Text('远控画面雪美陪伴桌宠'),
                subtitle: const Text('角落可拖拽、可贴边隐藏，且自动拦截点击防穿透'),
                value: FlurryConfig.enableMascotOverlay,
                onChanged: (v) =>
                    setState(() => FlurryConfig.setMascotOverlay(v)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeColor: FlurryColors.iceMint,
                secondary:
                    const Icon(Icons.ac_unit_rounded, color: FlurryColors.iceMint),
                title: const Text('冬日轻柔飘雪特效'),
                subtitle: const Text('主页与远控界面叠加无触控遮挡的雪花氛围层'),
                value: FlurryConfig.enableSnowfall,
                onChanged: (v) => setState(() => FlurryConfig.setSnowfall(v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MouseSandboxScreen extends StatefulWidget {
  final VoidCallback onExitSession;

  const MouseSandboxScreen({
    super.key,
    required this.onExitSession,
  });

  @override
  State<MouseSandboxScreen> createState() => _MouseSandboxScreenState();
}

class _MouseSandboxScreenState extends State<MouseSandboxScreen> {
  Offset _cursorPos = const Offset(240, 260);
  String _lastAction = '已连线电脑！试试点击左上角雪美桌宠或右下角虚拟鼠标，雪球~';
  int _clickCount = 0;
  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  Offset? _selectionStart;
  Rect? _mascotBlockedRect;
  final ScrollController _scrollDemoController = ScrollController();

  void _onTrackpadMove(double dx, double dy) {
    setState(() {
      final size = MediaQuery.of(context).size;
      final newX = (_cursorPos.dx + dx).clamp(0.0, size.width - 12.0);
      final newY = (_cursorPos.dy + dy).clamp(0.0, size.height - 60.0);
      _cursorPos = Offset(newX, newY);
      _lastAction = '触控板滑动: dx=${dx.toStringAsFixed(1)}, dy=${dy.toStringAsFixed(1)}';
    });
  }

  void _onButtonAction(FlurryMouseButton button, bool down) {
    setState(() {
      if (button == FlurryMouseButton.left) {
        _isLeftPressed = down;
        if (down) {
          _clickCount++;
          _lastAction = '鼠标左键按下 [#$_clickCount]';
          _selectionStart ??= _cursorPos;
        } else {
          _lastAction = '鼠标左键释放';
          _selectionStart = null;
        }
      } else if (button == FlurryMouseButton.right) {
        _isRightPressed = down;
        _lastAction = down ? '鼠标右键按下 (菜单)' : '鼠标右键释放';
      } else if (button == FlurryMouseButton.wheel) {
        _lastAction = down ? '鼠标中键按下' : '鼠标中键释放';
      }
    });
  }

  void _onScrollAction(int delta) {
    setState(() {
      _lastAction = '滚轮滚动: delta=$delta';
      if (_scrollDemoController.hasClients) {
        final target = (_scrollDemoController.offset - delta * 42.0)
            .clamp(0.0, _scrollDemoController.position.maxScrollExtent);
        _scrollDemoController.animateTo(
          target,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: FlurryColors.starlightBg,
      body: Stack(
        children: [
          _buildMockDesktopBackground(size),
          if (_isLeftPressed && _selectionStart != null)
            Positioned(
              left: min(_selectionStart!.dx, _cursorPos.dx),
              top: min(_selectionStart!.dy, _cursorPos.dy),
              width: (_cursorPos.dx - _selectionStart!.dx).abs(),
              height: (_cursorPos.dy - _selectionStart!.dy).abs(),
              child: Container(
                decoration: BoxDecoration(
                  color: FlurryColors.sakuraNeon.withOpacity(0.18),
                  border: Border.all(color: FlurryColors.sakuraNeon, width: 1.5),
                ),
              ),
            ),
          Positioned(
            left: _cursorPos.dx,
            top: _cursorPos.dy,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -pi / 6,
                child: Icon(
                  Icons.navigation,
                  color: _isLeftPressed ? FlurryColors.sakuraNeon : Colors.white,
                  size: 26,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: _buildTelemetryHud(),
          ),
          Positioned(
            top: 196,
            right: 20,
            child: _buildScrollTestBox(),
          ),
          FlurryToDeskMouseCore(
            onTrackpadDelta: _onTrackpadMove,
            onButtonAction: _onButtonAction,
            onScrollNotch: _onScrollAction,
          ),
          const FlurrySnowOverlay(),
          FlurryMascotOverlay(
            onBlockedRectChanged: (_, newRect) {
              setState(() => _mascotBlockedRect = newRect);
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FlurryColors.starlightHud,
          border: Border(
            top: BorderSide(
              color: FlurryColors.sakuraNeon.withOpacity(0.4),
              width: 1.2,
            ),
          ),
        ),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '断开返回手机主页',
                  icon: const Icon(Icons.clear_rounded, color: Colors.white),
                  onPressed: widget.onExitSession,
                ),
                const IconButton(
                  icon: Icon(Icons.tv_rounded, color: Colors.white),
                  onPressed: null,
                ),
                const IconButton(
                  icon: Icon(Icons.keyboard_rounded, color: Colors.white),
                  onPressed: null,
                ),
                const IconButton(
                  icon: Icon(Icons.touch_app_rounded, color: FlurryColors.sakuraNeon),
                  onPressed: null,
                ),
              ],
            ),
            Text(
              _mascotBlockedRect != null
                  ? '🐾 桌宠防穿透保护已激活 (${_mascotBlockedRect!.width.toInt()}×${_mascotBlockedRect!.height.toInt()})'
                  : '🐾 桌宠已隐藏',
              style: const TextStyle(color: FlurryColors.frostCyan, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockDesktopBackground(Size size) {
    return GestureDetector(
      onTapDown: (d) {
        setState(() {
          _cursorPos = d.localPosition;
          _clickCount++;
          _lastAction =
              '直接触屏点击远端桌面 (#$_clickCount): (${d.localPosition.dx.toInt()}, ${d.localPosition.dy.toInt()})';
        });
      },
      child: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.1, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF232C43),
              Color(0xFF141A29),
              Color(0xFF0B0E17),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 36,
              top: 200,
              child: _buildDesktopIcon(Icons.folder_rounded, '动森相册', FlurryColors.daisyGold),
            ),
            Positioned(
              left: 36,
              top: 290,
              child: _buildDesktopIcon(Icons.terminal_rounded, 'PowerShell', FlurryColors.frostCyan),
            ),
            Positioned(
              left: 36,
              top: 380,
              child: _buildDesktopIcon(Icons.pets_rounded, '雪美日记.md', FlurryColors.sakuraNeon),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopIcon(IconData icon, String label, Color color) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryHud() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlurryColors.starlightHud,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlurryColors.sakuraNeon.withOpacity(0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.pets_rounded, color: FlurryColors.sakuraNeon, size: 18),
              SizedBox(width: 8),
              Text(
                '雪美远控遥测面板',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 14),
          Text(
            '光标坐标: X=${_cursorPos.dx.toStringAsFixed(0)}, Y=${_cursorPos.dy.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _lastAction,
            style: const TextStyle(color: FlurryColors.frostCyan, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildPill('左键', _isLeftPressed, FlurryColors.sakuraNeon),
              _buildPill('右键', _isRightPressed, FlurryColors.daisyGold),
              _buildPill('远端点击: $_clickCount', true, FlurryColors.iceMint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? color : Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildScrollTestBox() {
    return Container(
      width: 220,
      height: 165,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlurryColors.starlightHud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '滚轮测试区 (Wheel Test)',
            style: TextStyle(
              color: FlurryColors.sakuraSoft,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              controller: _scrollDemoController,
              itemCount: 30,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '❄️ 第 ${index + 1} 行 · 滑动滚轮胶囊测试',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
