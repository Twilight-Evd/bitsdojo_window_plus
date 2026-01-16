import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import './native_api.dart';
import './window_util.dart';

bool isValidHandle(int? handle, String operation) {
  if (handle == null) {
    // Silently return false to avoid console clutter during startup race conditions
    return false;
  }
  return true;
}

class MacOSWindow extends DesktopWindow {
  int? handle;
  Size? _minSize;
  Size? _maxSize;
  Alignment? _alignment;
  bool _setTitleOnNextShow = false;
  String? _titleToSet;

  MacOSWindow([this.handle]) {
    _alignment = Alignment.center;
    _setTitleOnNextShow = false;
  }

  Size get size {
    final winRect = this.rect;
    return Size(winRect.right - winRect.left, winRect.bottom - winRect.top);
  }

  Rect get rect {
    if (!isValidHandle(handle, "get rectangle")) return Rect.zero;
    return getRectForWindow(handle!);
  }

  double get scaleFactor {
    //TODO: implement
    return 1;
  }

  set rect(Rect newRect) {
    if (!isValidHandle(handle, "set rectangle")) return;
    var widthToSet = ((_minSize != null) && (newRect.width < _minSize!.width))
        ? _minSize!.width
        : newRect.width;
    var heightToSet =
        ((_minSize != null) && (newRect.height < _minSize!.height))
            ? _minSize!.height
            : newRect.height;
    final rectToSet =
        Rect.fromLTWH(newRect.left, newRect.top, widthToSet, heightToSet);
    setRectForWindow(handle!, rectToSet);
  }

  Offset get position {
    final winRect = this.rect;
    return Offset(winRect.left, winRect.top);
  }

  set position(Offset newPosition) {
    if (!isValidHandle(handle, "set position")) return;
    setPositionForWindow(handle!, newPosition);
  }

  Alignment? get alignment => _alignment;
  set alignment(Alignment? newAlignment) {
    _alignment = newAlignment;
    if (_alignment != null) {
      if (!isValidHandle(handle, "set alignment")) return;
      final screenInfo = getScreenInfoForWindow(handle!);
      if (screenInfo.workingRect == null) {
        print("Can't set alignment - don't have a workingRect");
        return;
      }
      final windowRect =
          getRectOnScreen(this.size, _alignment!, screenInfo.workingRect!);
      final menuBarHeight = screenInfo.workingRect!.top;
      // We need to subtract menuBarHeight because .position uses
      // setFrameTopLeftPoint internally and that needs an offset
      // relative to the start of the working rectangle (after the menu bar)
      final positionToSet = windowRect.topLeft.translate(0, -menuBarHeight);
      this.position = positionToSet;
    }
  }

  set minSize(Size? newSize) {
    if (!isValidHandle(handle, "set minSize")) return;
    _minSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting minSize to null
      return;
    }
    setMinSize(handle!, _minSize!.width.toInt(), _minSize!.height.toInt());
  }

  set maxSize(Size? newSize) {
    if (!isValidHandle(handle, "set maxSize")) return;
    _maxSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting maxSize to null
      return;
    }
    setMaxSize(handle!, _maxSize!.width.toInt(), _maxSize!.height.toInt());
  }

  @override
  Size get screenSize {
    if (!isValidHandle(handle, "get screenSize")) return Size.zero;
    final screenInfo = getScreenInfoForWindow(handle!);
    return screenInfo.fullRect?.size ?? Size.zero;
  }

  @override
  Size get workingScreenSize {
    if (!isValidHandle(handle, "get workingScreenSize")) return Size.zero;
    final screenInfo = getScreenInfoForWindow(handle!);
    return screenInfo.workingRect?.size ?? Size.zero;
  }

  set size(Size newSize) {
    if (!isValidHandle(handle, "set size")) return;
    var width = newSize.width;

    if (_minSize != null) {
      if (newSize.width < _minSize!.width) width = _minSize!.width;
    }

    if (_maxSize != null) {
      if (newSize.width > _maxSize!.width) width = _maxSize!.width;
    }

    var height = newSize.height;

    if (_minSize != null) {
      if (newSize.height < _minSize!.height) height = _minSize!.height;
    }

    if (_maxSize != null) {
      if (newSize.height > _maxSize!.height) height = _maxSize!.height;
    }

    Size sizeToSet = Size(width, height);
    if (_alignment == null) {
      setSize(handle!, sizeToSet.width.toInt(), sizeToSet.height.toInt());
    } else {
      final screenInfo = getScreenInfoForWindow(handle!);
      if (screenInfo.workingRect == null) {
        print("Can't set size - don't have a workingRect");
        return;
      }
      this.rect =
          getRectOnScreen(sizeToSet, _alignment!, screenInfo.workingRect!);
    }
  }

  Size get titleBarButtonSize {
    if (!isValidHandle(handle, "get titleBarButtonSize")) return Size.zero;
    throw UnimplementedError(
        'titleBarButtonSize getter has not been implemented.');
  }

  double get titleBarHeight {
    if (!isValidHandle(handle, "get titleBarHeight")) return 0;
    return getTitleBarHeight(handle!);
  }

  @override
  set titleBarHeight(double height) {
    if (!isValidHandle(handle, "set titleBarHeight")) return;
    setTitleBarHeight(handle!, height.toInt());
  }

  set title(String newTitle) {
    if (!isValidHandle(handle, "set title")) return;
    // Save title internally because window might be hidden
    // so title won't be set. Will set it on next show()
    if (this.isVisible == false) {
      _setTitleOnNextShow = true;
      _titleToSet = newTitle;
    }
    setWindowTitle(handle!, newTitle);
  }

  double get borderSize {
    //borderSize is zero on macOS
    return 0;
  }

  @Deprecated("use isVisible instead")
  bool get visible {
    return isVisible;
  }

  bool get isVisible {
    if (!isValidHandle(handle, "get isVisible")) return false;
    return isWindowVisible(handle!);
  }

  @Deprecated("use show()/hide() instead")
  set visible(bool isVisible) {
    if (isVisible) {
      show();
    } else {
      hide();
    }
  }

  void show() {
    if (!isValidHandle(handle, "show")) return;
    showWindow(handle!);
    if (_setTitleOnNextShow) {
      _setTitleOnNextShow = false;
      if (_titleToSet != null) {
        setWindowTitle(handle!, _titleToSet!);
      }
    }
  }

  void hide() {
    if (!isValidHandle(handle, "hide")) return;
    hideWindow(handle!);
  }

  void close() {
    if (!isValidHandle(handle, "close")) return;
    closeWindow(handle!);
  }

  void minimize() {
    if (!isValidHandle(handle, "minimize")) return;
    minimizeWindow(handle!);
  }

  void maximize() {
    if (!isValidHandle(handle, "maximize")) return;
    maximizeWindow(handle!);
  }

  void restore() {
    if (this.isMaximized) {
      maximizeOrRestore();
    }
  }

  bool get isMaximized {
    if (!isValidHandle(handle, "get isMaximized")) return false;
    return isWindowMaximized(handle!);
  }

  void startDragging() {
    if (!isValidHandle(handle, "start dragging")) return;
    moveWindow(handle!);
  }

  void maximizeOrRestore() {
    if (!isValidHandle(handle, "maximizeOrRestore")) return;
    maximizeOrRestoreWindow(handle!);
  }

  @override
  void toggleFullScreen() {
    if (!isValidHandle(handle, "toggleFullScreen")) return;
    toggleFullScreenWindow(handle!);
  }

  bool get alwaysOnTop {
    if (!isValidHandle(handle, "get alwaysOnTop")) return false;
    return isAlwaysOnTop(handle!);
  }

  set alwaysOnTop(bool onTop) {
    if (!isValidHandle(handle, "set alwaysOnTop")) return;
    todoAlwaysOnTop(handle!, onTop ? 1 : 0);
  }

  VoidCallback? _onClose;
  @override
  set onClose(VoidCallback? callback) {
    _onClose = callback;
  }

  @override
  VoidCallback? get onClose => _onClose;

  VoidCallback? _onArgumentsChanged;
  @override
  set onArgumentsChanged(VoidCallback? callback) {
    _onArgumentsChanged = callback;
  }

  @override
  VoidCallback? get onArgumentsChanged => _onArgumentsChanged;

  @override
  set backgroundEffect(WindowEffect effect) {
    if (!isValidHandle(handle, "set backgroundEffect")) return;
    setBackgroundEffect(handle!, effect.index);
  }

  @override
  bool get isMainWindow =>
      BitsdojoWindowPlatform.instance.isMainWindow(this.handle ?? 0);

  int _depth = 0;
  String? _name;
  Map<String, dynamic>? _arguments;

  @override
  int get depth => _depth;
  set depth(int value) => _depth = value;

  @override
  String? get name => _name;
  set name(String? value) => _name = value;

  @override
  Map<String, dynamic>? get arguments => _arguments;
  set arguments(Map<String, dynamic>? value) => _arguments = value;

  @override
  Future<void> openNewWindow({
    String? name,
    Size? size,
    Offset? position,
    Map<String, dynamic>? arguments,
  }) {
    return BitsdojoWindowPlatform.instance.openNewWindow(
      name: name,
      size: size,
      position: position,
      arguments: arguments,
    );
  }

  @override
  void setWindowTitleBarButtonVisibility(
      DesktopWindowButton button, bool visible) {
    if (!isValidHandle(handle, "set window button visibility")) return;
    setWindowButtonVisibility(handle!, button.index, visible);
  }

  @override
  void setWindowTitleBarButtonOffset(
      DesktopWindowButton button, Offset offset) {
    if (!isValidHandle(handle, "set window button offset")) return;
    setWindowButtonOffset(handle!, button.index, offset.dx, offset.dy);
  }
}
