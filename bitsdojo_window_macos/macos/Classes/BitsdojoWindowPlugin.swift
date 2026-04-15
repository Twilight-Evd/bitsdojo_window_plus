import Cocoa
import FlutterMacOS

@objc(BitsdojoWindowPlugin)
public class BitsdojoWindowPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private static var instances = NSMapTable<NSWindow, BitsdojoWindowPlugin>(keyOptions: .weakMemory, valueOptions: .strongMemory)
  private static var globalObserverTokens: [NSObjectProtocol] = []
  private var lifecycleObserverTokens: [NSObjectProtocol] = []

  init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
    super.init()
  }

  deinit {
    removeLifecycleObservers()
  }

  public static func getPluginForWindow(_ window: NSWindow) -> BitsdojoWindowPlugin? {
    return instances.object(forKey: window)
  }

  public static func unregisterWindow(_ window: NSWindow) {
    if let plugin = instances.object(forKey: window) {
      plugin.removeLifecycleObservers()
      instances.removeObject(forKey: window)
    }
  }

  public static func registerWindow(_ window: NSWindow) {
    let bdwAPI = bitsdojo_window_api().pointee
    bdwAPI.privateAPI.pointee.setAppWindow(window)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "bitsdojo/window", binaryMessenger: registrar.messenger)
    let instance = BitsdojoWindowPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)

    instance.associateAndTrySendReady()
    
    // Auto-detect and register primary window
    // 🔧 Add delay to ensure Flutter engine is fully initialized on first launch
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      BitsdojoWindowPlugin.isReady = true
      MultiWindowManager.shared.autoDetectPrimaryWindow()
    }
  }
  
  // 🔧 Safety flag to prevent early lifecycle events
  private static var isReady = false

  private func associateAndTrySendReady() {
    guard let registrar = self.registrar else { return }
    // Try to find the window associated with this engine
    if let window = registrar.viewController?.view.window ?? NSApp.windows.first(where: { $0.contentViewController == registrar.viewController }) {
        BitsdojoWindowPlugin.instances.setObject(self, forKey: window)
        
        // 🔧 Ensure window is registered with the native API
        BitsdojoWindowPlugin.registerWindow(window)
        
        self.startLifecycleMonitoring(window: window)
        
        // Send ready in next run loop to ensure engine is ready for messages
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self = self, let window = window else { return }
            
            let handle = Int(bitPattern: Unmanaged.passUnretained(window).toOpaque())
            let bdwAPI = bitsdojo_window_api().pointee;
            let isPrimary = bdwAPI.publicAPI.pointee.isPrimaryWindow(window);
            
            let bdwWindow = window as? BitsdojoWindow
            let depth = bdwWindow?.depth ?? 0
            let name = bdwWindow?.windowName
            let arguments = bdwWindow?.windowArguments
            
            self.channel.invokeMethod("windowReady", arguments: [
                "handle": handle,
                "isPrimary": isPrimary,
                "depth": depth,
                "name": name as Any,
                "arguments": arguments as Any
            ])
        }
    } else {
        // Window not ready yet, try again with a SMALL delay to prevent high-frequency recursion
        // that could potentially hang the UI thread in merged engine mode.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.associateAndTrySendReady()
        }
    }
  }

  // 🔧 Native Lifecycle Management
  // Tracks global visibility and app activation to drive AppLifecycleState.
  
  private static var visibleWindowCount = 0
  private static var isAppActive: Bool = false
  private static var lastSentState: String? = nil
  private static var globalObserversRegistered = false

  private func startLifecycleMonitoring(window: NSWindow) {
      removeLifecycleObservers()

      // Enable mouse events even in background (fixes hover issue natively)
      window.acceptsMouseMovedEvents = true
      
      // 1. Register Global Observers (Once)
      if !BitsdojoWindowPlugin.globalObserversRegistered {
          let didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: NSApp, queue: nil) { _ in
              BitsdojoWindowPlugin.isAppActive = true
              BitsdojoWindowPlugin.recalculateLifecycle()
          }
          let didResignActiveObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApp, queue: nil) { _ in
              BitsdojoWindowPlugin.isAppActive = false
              BitsdojoWindowPlugin.recalculateLifecycle()
          }
          BitsdojoWindowPlugin.globalObserverTokens = [
            didBecomeActiveObserver,
            didResignActiveObserver,
          ]
           // Initialize app active state
          BitsdojoWindowPlugin.isAppActive = NSApp.isActive
          BitsdojoWindowPlugin.globalObserversRegistered = true
      }

      // 2. Monitor Window Occlusion
      let occlusionObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: nil) { _ in
          BitsdojoWindowPlugin.recalculateLifecycle()
      }
      
      // 3. Monitor Closing
      let closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
          BitsdojoWindowPlugin.unregisterWindow(window)
          // Delay check to let window close
          DispatchQueue.main.async {
              BitsdojoWindowPlugin.recalculateLifecycle()
          }
          self?.removeLifecycleObservers()
      }
      lifecycleObserverTokens = [occlusionObserver, closeObserver]
      
      // Initial State Check
      BitsdojoWindowPlugin.recalculateLifecycle()
  }

  private func removeLifecycleObservers() {
      for token in lifecycleObserverTokens {
          NotificationCenter.default.removeObserver(token)
      }
      lifecycleObserverTokens.removeAll()
  }

  private static func recalculateLifecycle() {
      var newVisibleCount = 0
      
      // Count visible windows (occlusionState contains .visible)
      // 🔧 Optimized iteration to avoid O(N^2) and potential enumerator instability
      let keys = instances.keyEnumerator()
      while let window = keys.nextObject() as? NSWindow {
          if window.occlusionState.contains(.visible) {
              newVisibleCount += 1
          }
      }
      visibleWindowCount = newVisibleCount
      
      // Determine Target State
      // 1. If NO windows are visible -> Hidden
      // 2. If windows visible, but App NOT Active -> Inactive
      // 3. If windows visible AND App Active -> Resumed
      
      var newState = "AppLifecycleState.hidden"
      
      if visibleWindowCount > 0 {
          if isAppActive {
              newState = "AppLifecycleState.resumed"
          } else {
              newState = "AppLifecycleState.inactive"
          }
      }
      
      // Dedup: Only send if changed
      if newState != lastSentState {
          sendLifecycleEvent(newState)
          lastSentState = newState
      }
  }
  
  private static func sendLifecycleEvent(_ event: String) {
      let iterator = instances.objectEnumerator()
      while let plugin = iterator?.nextObject() as? BitsdojoWindowPlugin {
          guard let registrar = plugin.registrar else { continue }
          
          
          // 🔧 Only send if the view controller is ready (engine initialized)
          guard registrar.viewController != nil else { continue }
          
          // 🔧 Gate lifecycle events until initialization is complete
          guard BitsdojoWindowPlugin.isReady else { continue }
          
          let lifecycleChannel = FlutterBasicMessageChannel(
              name: "flutter/lifecycle",
              binaryMessenger: registrar.messenger,
              codec: FlutterStringCodec.sharedInstance()
          )
          
          // 🔧 Send asynchronously to avoid blocking the UI thread during high-frequency events
          // and to prevent deadlocks in merged engine mode.
          DispatchQueue.main.async {
              lifecycleChannel.sendMessage(event)
          }
      }
  }






  @objc public static func closeRequested(_ window: NSWindow) {
    MultiWindowManager.shared.markWindowClosing(window)
    if let instance = instances.object(forKey: window) {
        let handle = Int(bitPattern: Unmanaged.passUnretained(window).toOpaque())
        instance.channel.invokeMethod("closeRequested", arguments: ["handle": handle])
    }
  }

  // MARK: - Backward Compatibility (Deprecated)
  
  public typealias OnOpenNewWindow = (String?, [String: Any]?, NSSize?, NSPoint?) -> Void
  
  @available(*, deprecated, message: "Use MultiWindowManager.shared.openNewWindow instead. This callback will be removed in v2.0.0")
  public static var onOpenNewWindow: OnOpenNewWindow? {
    get { return _legacyCallback }
    set { _legacyCallback = newValue }
  }
  
  private static var _legacyCallback: OnOpenNewWindow?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openNewWindow":
        let args = call.arguments as? [String: Any]
        let name = args?["name"] as? String
        let arguments = args?["arguments"] as? [String: Any]
        
        var size: NSSize? = nil
        if let width = args?["width"] as? Double, let height = args?["height"] as? Double {
            size = NSSize(width: width, height: height)
        }
        
        var position: NSPoint? = nil
        if let x = args?["x"] as? Double, let y = args?["y"] as? Double {
            position = NSPoint(x: x, y: y)
        }

        // Use MultiWindowManager to create the window
        DispatchQueue.main.async {
            let window = MultiWindowManager.shared.openNewWindow(
                name: name,
                arguments: arguments,
                size: size,
                position: position
            )
            result(["handle": window.windowHandle])
        }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func updateArguments(_ arguments: [String: Any]?) {
    self.channel.invokeMethod("argumentsChanged", arguments: ["arguments": arguments as Any])
  }


}
