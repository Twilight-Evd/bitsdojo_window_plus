import Cocoa
import FlutterMacOS
import bitsdojo_window_macos

@main
class AppDelegate: FlutterAppDelegate {
  private var isExiting = false
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Listen for primary window close notification from plugin
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("BitsdojoWindowPrimaryWillClose"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.isExiting = true
      NSApp.terminate(self)
    }
    
    // Standard Flutter initialization
    signal(SIGPIPE, SIG_IGN)
    super.applicationDidFinishLaunching(notification)
  }
  
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if isExiting {
      return .terminateNow
    }
    if let window = mainFlutterWindow {
      BitsdojoWindowPlugin.closeRequested(window)
      return .terminateCancel
    }
    return .terminateNow
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }
  
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
