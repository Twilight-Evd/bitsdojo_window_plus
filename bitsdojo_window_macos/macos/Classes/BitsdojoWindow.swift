import Cocoa
import FlutterMacOS

let bdwAPI = bitsdojo_window_api().pointee;
let bdwPrivateAPI = bdwAPI.privateAPI.pointee;
let bdwPublicAPI = bdwAPI.publicAPI.pointee;

public let BDW_CUSTOM_FRAME: UInt = 0x1
public let BDW_HIDE_ON_STARTUP: UInt = 0x2

open class BitsdojoWindow: NSWindow {
  @objc public var depth: Int = 0
  @objc public var windowName: String?
  @objc public var windowArguments: [String: Any]?

  // MARK: - Window Handle
  
  /// Returns a unique handle for this window (used for Dart communication)
  public var windowHandle: Int {
    return Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
  }

  override public var canBecomeKey: Bool {
    get {
      return true
    }
  }

  override public var isOpaque: Bool {
    get {
      return false
    }
    set {
      // Ignore attempts to make it opaque to preserve Acrylic effect
      super.isOpaque = false
    }
  }

  open func bitsdojo_window_configure() -> UInt {
    return 0
  }

  @objc open func bitsdojo_window_title_bar_height() -> Double {
    return 28.0 // Standard macOS title bar height
  }

  private var isConfigured = false
  private var hideOnStartupFlag = false
  
  /// Configures the window with bitsdojo_window settings.
  /// This must be called BEFORE setupFlutter() to ensure Flutter receives correct initial metrics.
  private func configureWindow() {
    guard !isConfigured else { return }
    
    bdwPrivateAPI.setAppWindow(self)
    let flags = self.bitsdojo_window_configure()
    
    let hideOnStartup: Bool = ((flags & BDW_HIDE_ON_STARTUP) != 0)
    let hasCustomFrame: Bool = ((flags & BDW_CUSTOM_FRAME) != 0)
    
    if hasCustomFrame {
      var localStyle = self.styleMask
      localStyle.insert(.fullSizeContentView)
      self.styleMask = localStyle
      self.titlebarAppearsTransparent = true
      self.titleVisibility = .hidden
      self.isOpaque = false
    }
    
    hideOnStartupFlag = hideOnStartup
    isConfigured = true
    
    isConfigured = true
    
    // print("[BitsdojoWindow] Window configured: frame=\(self.frame)")
  }
  
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    // Apply hide-on-startup alpha if needed (must happen at order time)
    if hideOnStartupFlag && !bdwPrivateAPI.windowCanBeShown(self) {
      self.alphaValue = 0
    }
    
    super.order(place, relativeTo: otherWin)
  }

  // Remove debug setFrame override
  
  // MARK: - Flutter Setup
  
  /// Sets up the Flutter engine and view controller for this window.
  /// This method is called automatically for secondary windows created via MultiWindowManager.
  /// For the primary window, it's called via awakeFromNib() or can be called manually.
  /// 
  /// Override this method in your subclass to customize Flutter setup or register plugins.
  /// Make sure to call super.setupFlutter() if you override this method.
  open func setupFlutter() {
    if self.contentViewController == nil {
       let viewBounds = self.contentView!.bounds
       let flutterViewController = FlutterViewController()
       
       // Configure frame and mask BEFORE assignment to ensure valid geometry for window creation.
       flutterViewController.view.frame = viewBounds
       flutterViewController.view.autoresizingMask = [.width, .height]
       
       self.contentViewController = flutterViewController
       
       // Configure layer and scale AFTER assignment to ensure external monitor scaling works.
       // Assigning the contentViewController can reset layer properties, so we set them last.
       flutterViewController.view.wantsLayer = true
       flutterViewController.view.layer?.contentsScale = self.backingScaleFactor
       flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor
       
       self.isOpaque = false
       self.backgroundColor = .clear

       flutterViewController.view.needsLayout = true
       flutterViewController.view.layoutSubtreeIfNeeded()
       
       // Plugin registration is handled by the window subclass (e.g. MainFlutterWindow).
    }
  }
  
  override public func awakeFromNib() {
    super.awakeFromNib()
    // For primary window loaded from storyboard, configure first
    configureWindow()
    
    // Disable window state restoration to prevent MacOS from restoring 
    // the previous window size/position which might be incorrect (e.g. 800x600)
    // This ensures we always start with a clean state and our programmatic size
    self.isRestorable = false
    
    // Setup Flutter immediately
    setupFlutter()
  }
  
  // MARK: - Initializers
  
  /// Required initializer to support metatype instantiation in MultiWindowManager
  public required override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
    super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    // Configure window immediately after initialization, before any Flutter setup
    configureWindow()
  }
  
  /// Creates a window with the specified frame and default style.
  /// - Parameters:
  ///   - contentRect: The initial frame rectangle
  ///   - configure: If true, automatically calls setupFlutter()
  public convenience init(contentRect: NSRect, configure: Bool = false) {
    let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    self.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
    // Window is already configured by required init
    
    if configure {
      self.setupFlutter()
    }
  }
  
  /// Creates a window with default size (80% of screen, centered)
  public convenience init() {
    let screen = NSScreen.main ?? NSScreen.screens.first
    var initialFrame = NSRect(x: 0, y: 0, width: 1280, height: 720)
    if let screen = screen {
      let screenFrame = screen.visibleFrame
      let width = screenFrame.width * 0.8
      let height = screenFrame.height * 0.8
      let x = screenFrame.origin.x + (screenFrame.width - width) / 2
      let y = screenFrame.origin.y + (screenFrame.height - height) / 2
      initialFrame = NSRect(x: x, y: y, width: width, height: height)
    }
    self.init(contentRect: initialFrame, configure: false)
  }
}



