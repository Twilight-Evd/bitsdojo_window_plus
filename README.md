# bitsdojo_window

This project is based on the following MIT-licensed project:

- bitsdojo_window
  Copyright (c) 2020-2021 Bogdan Hobeanu
  License: MIT

A [Flutter package](https://pub.dev/packages/bitsdojo_window) that makes it easy to customize and work with your Flutter desktop app window on **Windows**, **macOS** and **Linux**.


# bitsdojo_window_plus

**bitsdojo_window_plus** is an enhanced version of the original package, designed for better multi-window management, more robust platform integration, and improved stability for complex desktop applications.


- Multi-window support
- backgroundEffect
- alwaysOnTop
- onClose handler
- setWindowTitleBarButtonVisibility
- titlebar height
- and so on...


<img src="resources/multi-window.png">

Watch the tutorial to get started. Click the image below to watch the video:

[![IMAGE ALT TEXT](https://img.youtube.com/vi/bee2AHQpGK4/0.jpg)](https://www.youtube.com/watch?v=bee2AHQpGK4 "Click to open")

<img src="https://raw.githubusercontent.com/bitsdojo/bitsdojo_window/master/resources/screenshot.png">

**Features**:

- Custom window frame - remove standard Windows/macOS/Linux titlebar and buttons
- Hide window on startup
- Show/hide window
- Move window using Flutter widget
- Minimize/Maximize/Restore/Close window
- Set window size, minimum size and maximum size
- Set window position
- Set window alignment on screen (center/topLeft/topRight/bottomLeft/bottomRight)
- Set window title

# Getting Started

Add the package to your project's `pubspec.yaml` file. Since this is a federated plugin, you should add both the core package and the platform-specific package for macOS:

```yaml
# pubspec.yaml

dependencies:
  flutter:
    sdk: flutter
  bitsdojo_window:
    git:
      url: https://github.com/Twilight-Evd/bitsdojo_window_plus.git
      path: bitsdojo_window
      ref: v0.0.1
```

# For Windows apps

Inside your application folder, go to `windows\runner\main.cpp` and change the code look like this:

```diff
// windows/runner/main.cpp

  ...

  #include "flutter_window.h"
  #include "utils.h"

+ #include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
+ auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
+ // Include MultiWindowManager from plugin
+ #include <bitsdojo_window_windows/multi_window_manager.h>

  int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
+                       _In_ wchar_t *command_line, _In_ int show_command) {
...
+   // Set up MultiWindowManager factory for creating secondary windows
+   MultiWindowManager::GetInstance().SetWindowFactory(
+       [](const wchar_t *title, int x, int y, int width, int height,
+          const char *name, const char *arguments) -> HWND {
+         flutter::DartProject project(L"data");
+         auto window = new FlutterWindow(project);
+         Win32Window::Point origin(x, y);
+         Win32Window::Size size(width, height);
+
+         if (window->Create(title, origin, size)) {
+           return window->GetHandle();
+         }
+
+         delete window;
+         return nullptr;
+       });
+
+   FlutterWindow window(project);
...
```

And in `windows\runner\flutter_window.cpp`:

```diff
// windows/runner/flutter_window.cpp

+ #include <bitsdojo_window_windows/multi_window_manager.h>

  void FlutterWindow::OnDestroy() {
+   MultiWindowManager::GetInstance().OnWindowDestroyed(GetHandle());
    if (flutter_controller_) {
      flutter_controller_ = nullptr;
    }

    Win32Window::OnDestroy();
  }
```

# For macOS apps

Inside your application folder, go to `macos\runner\AppDelegate.swift` and change it to look like this:

```diff
// macos/runner/AppDelegate.swift

  import Cocoa
  import FlutterMacOS
+ import bitsdojo_window_macos

  @main
  class AppDelegate: FlutterAppDelegate {
+   private var isExiting = false
+
+   override func applicationDidFinishLaunching(_ notification: Notification) {
+     // Listen for primary window close notification from plugin
+     NotificationCenter.default.addObserver(
+       forName: NSNotification.Name("BitsdojoWindowPrimaryWillClose"),
+       object: nil,
+       queue: .main
+     ) { [weak self] _ in
+       self?.isExiting = true
+       NSApp.terminate(self)
+     }
+
+     super.applicationDidFinishLaunching(notification)
+   }
+
+   override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
+     if isExiting {
+       return .terminateNow
+     }
+     if let window = mainFlutterWindow {
+       BitsdojoWindowPlugin.closeRequested(window)
+       return .terminateCancel
+     }
+     return .terminateNow
+   }
+
+   override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
+     return false
+   }
  }
```

And in `macos\runner\MainFlutterWindow.swift`:

```diff
// macos/runner/MainFlutterWindow.swift

  import Cocoa
  import FlutterMacOS
+ import bitsdojo_window_macos

- class MainFlutterWindow: NSWindow {
+ class MainFlutterWindow: BitsdojoWindow {
+   override func bitsdojo_window_configure() -> UInt {
+     return BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP
+   }
+
+   override func setupFlutter() {
+     super.setupFlutter()
+     if let flutterViewController = self.contentViewController as? FlutterViewController {
+       RegisterGeneratedPlugins(registry: flutterViewController)
+     }
+   }
  }
```

#

If you don't want to use a custom frame and prefer the standard window titlebar and buttons, you can remove the `BDW_CUSTOM_FRAME` flag from the code above.

If you don't want to hide the window on startup, you can remove the `BDW_HIDE_ON_STARTUP` flag from the code above.

# For Linux apps

Inside your application folder, go to `linux\my_application.cc` and change the code look like this:

```diff
// linux/my_application.cc

  ...
  #include "flutter/generated_plugin_registrant.h"
+ #include <bitsdojo_window_linux/bitsdojo_window_plugin.h>

  struct _MyApplication {

  ...

  }

+  auto bdw = bitsdojo_window_from(window);
+  bdw->setCustomFrame(true);
-  gtk_window_set_default_size(window, 1280, 720);
   gtk_widget_show(GTK_WIDGET(window));

   g_autoptr(FlDartProject) project = fl_dart_project_new();

  ...

  }

```

# Flutter app integration

Now go to `lib\main.dart` and change the code look like this:

```diff
```
// lib/main.dart

  import 'package:flutter/material.dart';
  import 'package:bitsdojo_window/bitsdojo_window.dart';

  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(MyApp());

    // Register child window builders
    WindowRouter.register(
      name: 'child_window',
      builder: (context, arguments) => MyChildWidget(arguments: arguments),
    );

    doWhenWindowReady(() {
      const initialSize = Size(600, 450);
      appWindow.minSize = initialSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }

  class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        home: WindowRouter.build(
          context,
          appWindow,
          defaultWidget: MyHomePage(),
        ),
      );
    }
  }
```

This will set an initial size and a minimum size for your application window, center it on the screen and show it on the screen.

You can find examples in the [example](./bitsdojo_window/example) folder.

Here is an example that displays this window:

<details>
<summary>Click to expand</summary>

```dart
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() {
  runApp(const MyApp());
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(600, 450);
    win.minSize = initialSize;
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "Custom window with Flutter";
    win.show();
  });
}

const borderColor = Color(0xFF805306);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: WindowBorder(
          color: borderColor,
          width: 1,
          child: Row(
            children: const [LeftSide(), RightSide()],
          ),
        ),
      ),
    );
  }
}

const sidebarColor = Color(0xFFF6A00C);

class LeftSide extends StatelessWidget {
  const LeftSide({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 200,
        child: Container(
            color: sidebarColor,
            child: Column(
              children: [
                WindowTitleBarBox(child: MoveWindow()),
                Expanded(child: Container())
              ],
            )));
  }
}

const backgroundStartColor = Color(0xFFFFD500);
const backgroundEndColor = Color(0xFFF6A00C);

class RightSide extends StatelessWidget {
  const RightSide({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [backgroundStartColor, backgroundEndColor],
              stops: [0.0, 1.0]),
        ),
        child: Column(children: [
          WindowTitleBarBox(
            child: Row(
              children: [Expanded(child: MoveWindow()), const WindowButtons()],
            ),
          )
        ]),
      ),
    );
  }
}

final buttonColors = WindowButtonColors(
    iconNormal: const Color(0xFF805306),
    mouseOver: const Color(0xFFF6A00C),
    mouseDown: const Color(0xFF805306),
    iconMouseOver: const Color(0xFF805306),
    iconMouseDown: const Color(0xFFFFD500));

final closeButtonColors = WindowButtonColors(
    mouseOver: const Color(0xFFD32F2F),
    mouseDown: const Color(0xFFB71C1C),
    iconNormal: const Color(0xFF805306),
    iconMouseOver: Colors.white);

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}
```

</details>

#

# **Want to help? Become a sponsor**

I am developing this package in my spare time and any help is appreciated.

If you want to help you can [become a sponsor](https://github.com/sponsors/bitsdojo).

🙏 Thank you!

## ☕️ Current sponsors:

No sponsors
