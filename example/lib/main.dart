import 'dart:io';
import 'package:example/window.dart';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:vidra_player/adapters/video_player/video_player.dart';
import 'package:vidra_player/vidra_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Register different routes for different window types
  WindowRouter.register(
    name: 'child',
    builder: (context, arguments) => const MyHomePage(),
  );

  WindowRouter.register(
    name: 'singleton_window',
    builder: (context, arguments) => MoveWindow(child: VideoPlayerExample()),
  );

  doWhenWindowReady(() {
    if (appWindow.isMainWindow) {
      appWindow.size = const Size(900, 700);
      appWindow.alignment = Alignment.center;
    } else {
      // Check if we should apply specific settings to child windows
      final args = appWindow.arguments;
      if (args != null && args['onlyClose'] == true) {
        appWindow.setWindowTitleBarButtonVisibility(
          DesktopWindowButton.minimize,
          false,
        );
        appWindow.setWindowTitleBarButtonVisibility(
          DesktopWindowButton.zoom,
          false,
        );
      }
    }
    appWindow.titleBarHeight = 50;
    appWindow.title = appWindow.isMainWindow
        ? "Bitsdojo Multi-Window Showcase"
        : "Child Window - ${appWindow.name ?? 'Untitled'}";
    appWindow.backgroundEffect = WindowEffect.acrylic;
    appWindow.alwaysOnTop = false;
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bitsdojo Window Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: WindowRouter.build(
        context,
        appWindow,
        defaultWidget: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WindowEffect _currentEffect = WindowEffect.disabled;
  double _closeOffsetX = 0;
  double _closeOffsetY = 0;
  bool _isExitDialogShown = false;

  @override
  void initState() {
    super.initState();
    appWindow.onClose = _handleClose;
    appWindow.onArgumentsChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  void _handleClose() {
    if (appWindow.isMainWindow) {
      if (_isExitDialogShown) return;
      _showExitDialog();
    } else {
      appWindow.close();
    }
  }

  void _showExitDialog() {
    setState(() => _isExitDialogShown = true);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Confirmation'),
          content: const Text(
            'Closing the MAIN window will terminate the entire application.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isExitDialogShown = false);
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isExitDialogShown = false);
                appWindow.close();
              },
              child: const Text(
                'Exit App',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isExitDialogShown = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WindowBorder(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        width: 1,
        child: Column(
          children: [
            WindowTitleBarBox(
              child: Row(
                children: [
                  Expanded(child: MoveWindow()),
                  const WindowButtons(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildFeatureGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                appWindow.isMainWindow ? 'PRIMARY' : 'SECONDARY',
                appWindow.isMainWindow ? Colors.orange : Colors.teal,
              ),
              const SizedBox(width: 12),
              _buildBadge('DEPTH: ${appWindow.depth}', Colors.grey[800]!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          appWindow.isMainWindow
              ? "Multi-Window Dashboard"
              : "Child Window: ${appWindow.name ?? 'Untitled'}",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          "Native Handle: ${appWindow.handle}",
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        _buildSection("Window Management", [
          _buildButton(
            icon: Icons.add_to_photos,
            label: "Open Regular Window",
            onPressed: () =>
                appWindow.openNewWindow(arguments: {'onlyClose': false}),
          ),
          _buildButton(
            icon: Icons.filter_1,
            label: "Open Singleton Window",
            color: Colors.teal,
            onPressed: _openSingletonWindow,
          ),
          _buildButton(
            icon: Icons.crop_free,
            label: "Spawn Custom (800x300)",
            onPressed: () => appWindow.openNewWindow(
              size: const Size(800, 300),
              position: const Offset(150, 150),
              arguments: {'isCustom': true},
            ),
            enabled: appWindow.isMainWindow,
          ),
        ]),
        _buildSection("macOS Customization", [
          const Text(
            "Traffic Light Controls",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildVisibilityControls(),
          const Divider(),
          const Text(
            "Close Button Offset",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          _buildOffsetControls(),
          const Divider(),
          _buildValueSlider(
            "Title Bar Height",
            appWindow.titleBarHeight.toDouble(),
            20,
            120,
            (v) => setState(() => appWindow.titleBarHeight = v),
          ),
          const Divider(),
          _buildToggle(
            "Always on Top",
            appWindow.alwaysOnTop,
            (v) => setState(() => appWindow.alwaysOnTop = v),
          ),
        ]),
        _buildSection("Visual Enhancement", [
          _buildEffectSelector(),
          const SizedBox(height: 16),
          if (appWindow.arguments?['number'] != null)
            _buildDataCard(
              "Singleton Argument",
              "Number: ${appWindow.arguments!['number']}",
              Colors.orange,
            ),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: color != null ? Colors.white : null,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniToggle("Close", DesktopWindowButton.close),
          const SizedBox(width: 8),
          _buildMiniToggle("Min", DesktopWindowButton.minimize),
          const SizedBox(width: 8),
          _buildMiniToggle("Zoom", DesktopWindowButton.zoom),
        ],
      ),
    );
  }

  bool _isButtonVisible(DesktopWindowButton button) {
    if (Platform.isLinux) {
      return (appWindow as dynamic).isButtonVisible(button);
    }
    return true; // Default to visible on other platforms
  }

  Widget _buildMiniToggle(String label, DesktopWindowButton button) {
    final isVisible = _isButtonVisible(button);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        IconButton(
          onPressed: () {
            setState(() {
              appWindow.setWindowTitleBarButtonVisibility(button, !isVisible);
            });
          },
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetControls() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _buildValueSlider("X", _closeOffsetX, -50, 50, (v) {
              setState(() => _closeOffsetX = v);
              appWindow.setWindowTitleBarButtonOffset(
                DesktopWindowButton.close,
                Offset(_closeOffsetX, _closeOffsetY),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildValueSlider("Y", _closeOffsetY, -50, 50, (v) {
              setState(() => _closeOffsetY = v);
              appWindow.setWindowTitleBarButtonOffset(
                DesktopWindowButton.close,
                Offset(_closeOffsetX, _closeOffsetY),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildValueSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${value.toInt()}", style: const TextStyle(fontSize: 11)),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildEffectSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Background Effect",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [WindowEffect.disabled, WindowEffect.transparent].map((
            effect,
          ) {
            final isSelected = _currentEffect == effect;
            return ChoiceChip(
              label: Text(effect.name, style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  _currentEffect = effect;
                  appWindow.backgroundEffect = _currentEffect;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDataCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  int _singletonCounter = 0;
  Future<void> _openSingletonWindow() async {
    _singletonCounter++;
    await appWindow.openNewWindow(
      name: 'singleton_window',
      arguments: {'number': _singletonCounter},
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.primary,
      mouseOver: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      mouseDown: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      iconMouseOver: Theme.of(context).colorScheme.primary,
      iconMouseDown: Theme.of(context).colorScheme.primary,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: Theme.of(context).colorScheme.primary,
      iconMouseOver: Colors.white,
    );

    bool isButtonVisible(DesktopWindowButton button) {
      if (Platform.isLinux) {
        return (appWindow as dynamic).isButtonVisible(button);
      }
      return true;
    }

    return Row(
      children: [
        if (isButtonVisible(DesktopWindowButton.minimize))
          MinimizeWindowButton(colors: buttonColors),
        if (isButtonVisible(DesktopWindowButton.zoom))
          MaximizeWindowButton(colors: buttonColors),
        if (isButtonVisible(DesktopWindowButton.close))
          CloseWindowButton(
            colors: closeButtonColors,
            onPressed: () {
              appWindow.onClose?.call();
            },
          ),
      ],
    );
  }
}

class VideoPlayerExample extends StatelessWidget {
  const VideoPlayerExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Create video metadata
    final video = VideoMetadata(
      id: '12345',
      title: 'Example Video',
      description: 'This is an example video',
      coverUrl:
          'https://olevod.com/upload/vod/20251222-1/31bb85702f7131dbe6a503b7656a871d.jpg',
    );

    // Create episode list
    final episodes = [
      VideoEpisode(
        index: 0,
        title: 'Episode 1',
        qualities: [
          VideoQuality(
            label: '1080p',
            source: VideoSource.network(
              'https://europe.olemovienews.com/ts4/20251222/dMqVcRUk/mp4/dMqVcRUk.mp4/master.m3u8',
            ),
          ),
          VideoQuality(
            label: '480p',
            source: VideoSource.network(
              'https://europe.olemovienews.com/ts4/20251222/YIVw4dlP/mp4/YIVw4dlP.mp4/master.m3u8',
            ),
          ),
        ],
      ),
      VideoEpisode(
        index: 1,
        title: 'Episode 2',
        qualities: [
          VideoQuality(
            label: '1080p',
            source: VideoSource.network(
              'https://europe.olemovienews.com/ts4/20251222/FeSXYrz0/mp4/FeSXYrz0.mp4/master.m3u8',
            ),
          ),
          VideoQuality(
            label: '720p',
            source: VideoSource.network(
              'https://europe.olemovienews.com/ts4/20251222/QcUU3Azl/mp4/QcUU3Azl.mp4/master.m3u8',
            ),
          ),
        ],
      ),
    ];

    // Create player configuration
    final config = PlayerConfig(
      theme: const PlayerUITheme.netflix(),
      features: const PlayerFeatures.all(),
      behavior: PlayerBehavior(
        autoHideDelay: const Duration(seconds: 3),
        mouseHideDelay: const Duration(seconds: 2),
        hoverShowDelay: const Duration(milliseconds: 300),
        autoPlay: true,
        hideMouseWhenIdle: true,
      ),
    );

    final controller = PlayerController(
      config: config,
      video: video,
      episodes: episodes,
      player: VideoPlayerAdapter(),
      windowDelegate: BitsdojoWindowDelegate(),
    );
    // Use video player widget
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerWidget(controller: controller),
    );
  }
}
