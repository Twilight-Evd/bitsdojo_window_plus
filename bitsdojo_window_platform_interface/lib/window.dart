import 'package:flutter/painting.dart';

enum WindowEffect {
  disabled,
  transparent,
  acrylic,
  mica,
  tabbed,
}

abstract class DesktopWindow {
  DesktopWindow();
  int? get handle;
  double get scaleFactor;

  Rect get rect;
  set rect(Rect newRect);

  Offset get position;
  set position(Offset newPosition);

  Size get size;
  set size(Size newSize);

  set minSize(Size? newSize);
  set maxSize(Size? newSize);

  Size get screenSize;
  Size get workingScreenSize;

  Alignment? get alignment;
  set alignment(Alignment? newAlignment);

  set title(String newTitle);

  @Deprecated("use isVisible instead")
  bool get visible;
  bool get isVisible;
  @Deprecated("use show()/hide() instead")
  set visible(bool isVisible);
  void show();
  void hide();
  void close();
  void minimize();
  void maximize();
  void maximizeOrRestore();
  void toggleFullScreen();
  void restore();

  void startDragging();

  bool get alwaysOnTop;
  set alwaysOnTop(bool onTop);

  Size get titleBarButtonSize;

  double get titleBarHeight;
  set titleBarHeight(double height);

  double get borderSize;
  bool get isMaximized;
  VoidCallback? get onClose;
  set onClose(VoidCallback? callback);
  VoidCallback? get onArgumentsChanged;
  set onArgumentsChanged(VoidCallback? callback);
  set backgroundEffect(WindowEffect effect);
  bool get isMainWindow;
  int get depth;
  String? get name;
  Map<String, dynamic>? get arguments;
  Future<void> openNewWindow({
    String? name,
    Size? size,
    Offset? position,
    Map<String, dynamic>? arguments,
  });

  void setWindowTitleBarButtonVisibility(
      DesktopWindowButton button, bool visible) {}
  void setWindowTitleBarButtonOffset(
      DesktopWindowButton button, Offset offset) {}
}

enum DesktopWindowButton {
  close,
  minimize,
  zoom,
}
