import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:vidra_player/core/interfaces/window_delegate.dart';

class BitsdojoWindowDelegate implements WindowDelegate {
  @override
  Future<void> close() async {
    appWindow.close();
  }

  @override
  Future<void> enterFullscreen() async {
    appWindow.toggleFullScreen();
  }

  @override
  Future<void> exitFullscreen() async {
    appWindow.toggleFullScreen();
  }

  @override
  Future<void> maximize() async {
    appWindow.maximize();
  }

  @override
  Future<void> minimize() async {
    appWindow.minimize();
  }

  @override
  Future<void> restore() async {
    appWindow.restore();
  }

  @override
  Future<void> setTitle(String title) async {
    appWindow.title = title;
  }

  @override
  Future<void> toggleFullscreen() async {
    appWindow.toggleFullScreen();
  }

  @override
  Future<void> enterPip() async {
    appWindow.alignment = Alignment.bottomRight;
    appWindow.size = Size(540, 305);
    appWindow.minSize = Size(540, 305);
    appWindow.alwaysOnTop = true;
  }

  @override
  Future<void> exitPip() async {
    appWindow.alignment = Alignment.center;
    appWindow.size = Size(1280, 720);
    appWindow.minSize = Size(540, 305);
    appWindow.alwaysOnTop = false;
  }
}
