#import "bitsdojo_window_controller.h"
#import "titlebar_button_manager.h"
#import <QuartzCore/QuartzCore.h>
#include <cstdio>

// Helper function to keep visual effect view at the bottom
NSComparisonResult ensureVisualEffectAtBottom(__kindof NSView *_Nonnull view1,
                                              __kindof NSView *_Nonnull view2,
                                              void *_Nullable context) {
  NSVisualEffectView *effectView = (__bridge NSVisualEffectView *)context;
  if (view1 == effectView)
    return NSOrderedAscending;
  if (view2 == effectView)
    return NSOrderedDescending;
  return NSOrderedSame;
}

@implementation BitsdojoWindowController

- (instancetype)initWithWindow:(NSWindow *)window {
  self = [super init];
  if (self && window) {
    self.window = window;
    self.window.delegate = self;

    // Explicitly subscribe to fullscreen notifications to ensure we capture
    // them even if the window delegate is overwritten by another plugin.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowDidEnterFullScreen:)
               name:NSWindowDidEnterFullScreenNotification
             object:self.window];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowWillExitFullScreen:)
               name:NSWindowWillExitFullScreenNotification
             object:self.window];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowWillEnterFullScreen:)
               name:NSWindowWillEnterFullScreenNotification
             object:self.window];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowDidExitFullScreen:)
               name:NSWindowDidExitFullScreenNotification
             object:self.window];

    // 🔧 Debug Logging for App Activation
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(appDidBecomeActive:)
               name:NSApplicationDidBecomeActiveNotification
             object:nil];

    self.titleBarHeight = 28.0; // Default standard height

    SEL titleBarHeightSelector =
        NSSelectorFromString(@"bitsdojo_window_title_bar_height");

    if ([self.window respondsToSelector:titleBarHeightSelector]) {
      // Use dynamic dispatch to call the Swift method
      CGFloat height = ((CGFloat(*)(
          id, SEL))[self.window methodForSelector:titleBarHeightSelector])(
          self.window, titleBarHeightSelector);
      self.titleBarHeight = height;
    }

    self.canBeShown = NO;
    [TitleBarButtonManager adjustButtonPositionsForWindow:false
                                                forWindow:self.window
                                           withController:self];
    [self onScreenChange];

    [self.window
        addObserver:self
         forKeyPath:@"opaque"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            context:nil];
    [self.window
        addObserver:self
         forKeyPath:@"backgroundColor"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            context:nil];
  }
  return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"opaque"]) {
    // NSLog(@"[Bitsdojo][KVO] Window opaque changed: %@ -> %@",
    //       change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
    // NSLog(@"[Bitsdojo][KVO] Stack Trace: %@", [NSThread callStackSymbols]);
  } else if ([keyPath isEqualToString:@"backgroundColor"]) {
    // NSLog(@"[Bitsdojo][KVO] Window backgroundColor changed: %@ -> %@",
    //       change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
    // NSLog(@"[Bitsdojo][KVO] Stack Trace: %@", [NSThread callStackSymbols]);
  } else {
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

- (void)dealloc {
  [self.window removeObserver:self forKeyPath:@"opaque"];
  [self.window removeObserver:self forKeyPath:@"backgroundColor"];

  // 🔧 Explicitly invalidate timer
  [self stopFullScreenTransitionMonitoring];

  @try {
    NSView *contentView = [self.window contentView];
    [contentView.layer removeObserver:self forKeyPath:@"backgroundColor"];
    [contentView.layer removeObserver:self forKeyPath:@"opaque"];

    for (NSView *subview in contentView.subviews) {
      if ([NSStringFromClass([subview class]) containsString:@"Flutter"]) {
        [subview.layer removeObserver:self forKeyPath:@"backgroundColor"];
        [subview.layer removeObserver:self forKeyPath:@"opaque"];
      }
    }
  } @catch (NSException *exception) {
    // Ignore if observer not registered or view gone
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onScreenChange {
  self.isVisible = self.window.isVisible;
  self.isZoomed = self.window.isZoomed;
  [self setupScreenRects];
  [self setupWindowRects];
}

- (void)setupWindowRects {
  self.windowFrame = self.window.frame;
}

- (void)setupScreenRects {
  NSScreen *screen = self.window.screen;
  self.workingScreenRect = screen.visibleFrame;
  self.fullScreenRect = screen.frame;
}

- (void)windowDidResize:(NSNotification *)notification {
  NSWindow *resizedWindow = notification.object;
  if ([resizedWindow isKindOfClass:[NSWindow class]]) {
    [self setupWindowRects];
    self.windowSize = self.window.frame.size;
  }
}

- (void)handleWindowChanges {
  self.isZoomed = self.window.isZoomed;
}

- (void)windowDidBecomeVisible:(NSNotification *)notification {
  self.isVisible = YES;
}

- (void)windowDidBecomeHidden:(NSNotification *)notification {
  self.isVisible = NO;
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
  [self onScreenChange];
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
  [self onScreenChange];
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
  [self handleWindowChanges];
}
- (void)windowDidDeminiaturize:(NSNotification *)notification {
  [self handleWindowChanges];
}
- (void)windowDidEndLiveResize:(NSNotification *)notification {
  [self handleWindowChanges];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
}

- (void)windowDidResignKey:(NSNotification *)notification {
}

- (void)appDidBecomeActive:(NSNotification *)notification {
}

- (void)forceTransparency {
  [self.window setOpaque:NO];
  [self.window setBackgroundColor:[NSColor clearColor]];

  NSView *contentView = [self.window contentView];
  if (contentView) {
    [contentView setWantsLayer:YES];
    [[contentView layer] setBackgroundColor:[[NSColor clearColor] CGColor]];
    [[contentView layer] setOpaque:NO];

    for (NSView *subview in [contentView subviews]) {
      NSString *className = NSStringFromClass([subview class]);
      if ([className containsString:@"FlutterView"] ||
          [className containsString:@"FlutterSurface"]) {
        [subview setWantsLayer:YES];
        [[subview layer] setBackgroundColor:[[NSColor clearColor] CGColor]];
        [[subview layer] setOpaque:NO];
      }
    }
  }

  NSViewController *controller = [self.window contentViewController];
  if (controller && [controller view]) {
    NSView *view = [controller view];
    [view setWantsLayer:YES];
    [[view layer] setBackgroundColor:[[NSColor clearColor] CGColor]];
    [[view layer] setOpaque:NO];
  }
}

- (void)stopFullScreenTransitionMonitoring {
  if (self.fullScreenTransitionTimer) {
    [self.fullScreenTransitionTimer invalidate];
    self.fullScreenTransitionTimer = nil;
  }
}

- (void)enforceTransparencyDuringTransition {
  if ([self.window isOpaque]) {
    [self.window setOpaque:NO];
  }
  if (![[self.window backgroundColor] isEqual:[NSColor clearColor]]) {
    [self.window setBackgroundColor:[NSColor clearColor]];
  }

  NSView *contentView = [self.window contentView];
  NSVisualEffectView *visualEffectView = nil;

  for (NSView *subview in [contentView subviews]) {
    if ([subview isKindOfClass:[NSVisualEffectView class]]) {
      visualEffectView = (NSVisualEffectView *)subview;
      break;
    }
  }

  if (visualEffectView && visualEffectView.superview) {
    NSArray *subviews = contentView.subviews;
    if (subviews.firstObject != visualEffectView) {
      [contentView sortSubviewsUsingFunction:ensureVisualEffectAtBottom
                                     context:(__bridge void *)visualEffectView];
    }
  }
}

- (void)applyBackgroundEffect:(int)effect {
  self.lastBackgroundEffect = effect;
  NSWindow *window = self.window;
  NSView *contentView = [window contentView];
  NSVisualEffectView *visualEffectView = nil;

  for (NSView *subview in [contentView subviews]) {
    if ([subview isKindOfClass:[NSVisualEffectView class]]) {
      visualEffectView = (NSVisualEffectView *)subview;
      break;
    }
  }

  if (effect == 0) { // Disabled
    if (![window isOpaque])
      [window setOpaque:YES];
    if (![[window backgroundColor] isEqual:[NSColor windowBackgroundColor]])
      [window setBackgroundColor:[NSColor windowBackgroundColor]];

    if (!([window styleMask] & NSWindowStyleMaskFullSizeContentView)) {
      if ([window titlebarAppearsTransparent])
        [window setTitlebarAppearsTransparent:NO];
    }
    if (visualEffectView) {
      [visualEffectView removeFromSuperview];
    }
  } else {
    [window setOpaque:NO];
    [window setBackgroundColor:[NSColor clearColor]];
    [window setTitlebarAppearsTransparent:YES];

    if (@available(macOS 11.0, *)) {
      [window setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleNone];
    }

    [self forceTransparency];

    if (effect == 1) { // Transparent
      if (visualEffectView) {
        [visualEffectView removeFromSuperview];
      }
    } else { // Acrylic (2), Mica (3)
      if (!visualEffectView) {
        visualEffectView =
            [[NSVisualEffectView alloc] initWithFrame:[contentView bounds]];
        [visualEffectView
            setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [visualEffectView
            setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [visualEffectView setState:NSVisualEffectStateActive];

        [visualEffectView setWantsLayer:YES];
        [contentView addSubview:visualEffectView
                     positioned:NSWindowBelow
                     relativeTo:nil];

        [contentView
            sortSubviewsUsingFunction:ensureVisualEffectAtBottom
                              context:(__bridge void *)visualEffectView];
      }

      NSVisualEffectMaterial targetMaterial;
      BOOL isFullScreen =
          ([window styleMask] & NSWindowStyleMaskFullScreen) != 0;

      if (effect == 2) { // Acrylic
        if (isFullScreen) {
          targetMaterial = NSVisualEffectMaterialHeaderView;
        } else {
          targetMaterial = NSVisualEffectMaterialFullScreenUI;
        }
      } else { // Mica (3)
        targetMaterial = NSVisualEffectMaterialUnderWindowBackground;
      }

      [visualEffectView setMaterial:targetMaterial];
      [visualEffectView setState:NSVisualEffectStateActive];
      [visualEffectView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];

      [CATransaction begin];
      [CATransaction setDisableActions:YES];
      [visualEffectView setNeedsDisplay:YES];
      [CATransaction commit];
    }
  }
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {

  NSButton *closeButton =
      [self.window standardWindowButton:NSWindowCloseButton];
  NSButton *minButton =
      [self.window standardWindowButton:NSWindowMiniaturizeButton];
  NSButton *zoomButton = [self.window standardWindowButton:NSWindowZoomButton];

  self.wasCloseButtonVisible = !closeButton.isHidden;
  self.wasMiniaturizeButtonVisible = !minButton.isHidden;
  self.wasZoomButtonVisible = !zoomButton.isHidden;

  [self.window setHasShadow:NO];

  [self forceTransparency];

  NSView *contentView = [self.window contentView];
  NSVisualEffectView *visualEffectView = nil;

  for (NSView *subview in [contentView subviews]) {
    if ([subview isKindOfClass:[NSVisualEffectView class]]) {
      visualEffectView = (NSVisualEffectView *)subview;
      break;
    }
  }

  if (visualEffectView) {
    [contentView sortSubviewsUsingFunction:ensureVisualEffectAtBottom
                                   context:(__bridge void *)visualEffectView];
  }

  [self startFullScreenTransitionMonitoring];
}

- (void)startFullScreenTransitionMonitoring {
  if (self.fullScreenTransitionTimer) {
    [self.fullScreenTransitionTimer invalidate];
  }

  self.fullScreenTransitionTimer =
      [NSTimer scheduledTimerWithTimeInterval:0.1 // 10fps
                                       target:self
                                     selector:@selector
                                     (enforceTransparencyDuringTransition)
                                     userInfo:nil
                                      repeats:YES];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
  [self stopFullScreenTransitionMonitoring];

  [self forceTransparency];
  [self applyBackgroundEffect:self.lastBackgroundEffect];

  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self forceTransparency];
        [self applyBackgroundEffect:self.lastBackgroundEffect];
      });

  [TitleBarButtonManager showTitleBarButtonsForWindow:self.window];
  [TitleBarButtonManager adjustButtonPositionsForWindow:true
                                              forWindow:self.window
                                         withController:self];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
  [self.window setHasShadow:NO];
  [self forceTransparency];

  NSView *contentView = [self.window contentView];
  NSVisualEffectView *visualEffectView = nil;

  for (NSView *subview in [contentView subviews]) {
    if ([subview isKindOfClass:[NSVisualEffectView class]]) {
      visualEffectView = (NSVisualEffectView *)subview;
      break;
    }
  }

  if (visualEffectView) {
    [contentView sortSubviewsUsingFunction:ensureVisualEffectAtBottom
                                   context:(__bridge void *)visualEffectView];
  }

  [self startFullScreenTransitionMonitoring];

  NSButton *closeButton =
      [self.window standardWindowButton:NSWindowCloseButton];
  NSButton *minButton =
      [self.window standardWindowButton:NSWindowMiniaturizeButton];
  NSButton *zoomButton = [self.window standardWindowButton:NSWindowZoomButton];

  closeButton.hidden = !self.wasCloseButtonVisible;
  minButton.hidden = !self.wasMiniaturizeButtonVisible;
  zoomButton.hidden = !self.wasZoomButtonVisible;

  [TitleBarButtonManager adjustButtonPositionsForWindow:false
                                              forWindow:self.window
                                         withController:self];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
  [self stopFullScreenTransitionMonitoring];

  [self forceTransparency];
  [self applyBackgroundEffect:self.lastBackgroundEffect];

  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self forceTransparency];
        [self applyBackgroundEffect:self.lastBackgroundEffect];
      });

  [self.window setHasShadow:YES];
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
  if (self.window.occlusionState & NSWindowOcclusionStateVisible) {
    self.isVisible = YES;

    // Debug App/Window State
    NSLog(@"[Bitsdojo][DEBUG_LIFECYCLE] State Check - Key: %d, Main: %d, "
          @"AppActive: %d",
          [self.window isKeyWindow], [self.window isMainWindow],
          [NSApp isActive]);

    // 🔧 Aggressive Wake Up Strategy Iteration 2 REMOVED
    // Forcing Key and Active fights the OS window manager.
    // We only repaint to ensure content is up to date when revealed.

    // Force immediate repaint
    [self.window display];
    // Invalidate shadow to force visual refresh
    [self.window invalidateShadow];

    // 🔧 Iteration 3: Manual ViewController Lifecycle Trigger REMOVED
    // Calling lifecycle methods manually causes "Invalid engine handle" errors
    // and conflicts with standard macOS/Flutter lifecycle management.

    // Keep the explicit repaint call just in case
    [self.window.contentView setNeedsDisplay:YES];
  } else {
    self.isVisible = NO;
  }
}

- (void)windowWillClose:(NSNotification *)notification {
  // 1. Remove NSNotificationCenter observers
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSWindowDidEnterFullScreenNotification
              object:self.window];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSWindowWillExitFullScreenNotification
              object:self.window];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSWindowWillEnterFullScreenNotification
              object:self.window];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSWindowDidExitFullScreenNotification
              object:self.window];

  // 2. Explicitly remove KVO observers from the window BEFORE nil-ing it
  // This fixes the KVO leak where dealloc tries to remove observer from nil
  @try {
    [self.window removeObserver:self forKeyPath:@"opaque"];
    [self.window removeObserver:self forKeyPath:@"backgroundColor"];

    // NSView *contentView = [self.window contentView];
    // Note: We don't remove subview observers here as it's complex to track
    // them all properly without a stored list, but cleaning up the main window
    // observers is crucial.
  } @catch (NSException *exception) {
    // Ignore if not registered
  }

  // 3. Detach FlutterViewController to prevent invalid engine handle errors
  // If the engine is already dead, separating the controller helps it die
  // peacefully
  if ([self.window.contentViewController
          isKindOfClass:NSClassFromString(@"FlutterViewController")]) {
    self.window.contentViewController = nil;
  }

  self.window.delegate = nil;
  self.window = nil;
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
  // We notify the Dart side that a close was requested.
  // The Dart side will then decide whether to actually close the window or not.

  // Using dynamic dispatch to call the Swift method to avoid header import
  // issues.
  Class pluginClass =
      NSClassFromString(@"bitsdojo_window_macos.BitsdojoWindowPlugin");
  // If the above doesn't work (due to namespace), try without project name
  if (!pluginClass) {
    pluginClass = NSClassFromString(@"BitsdojoWindowPlugin");
  }

  SEL closeRequestedSelector = NSSelectorFromString(@"closeRequested:");
  if (pluginClass && [pluginClass respondsToSelector:closeRequestedSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [pluginClass performSelector:closeRequestedSelector withObject:sender];
#pragma clang diagnostic pop
  } else {
    // If we can't find the plugin class or method, just close the window
    return YES;
  }

  return NO; // Return NO to prevent the window from closing immediately.
}

@end
