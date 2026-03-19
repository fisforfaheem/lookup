import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "lookup/activity",
        binaryMessenger: controller.engine.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(["idleMillis": 0, "highEngagement": "none"])
          return
        }

        switch call.method {
        case "getActivitySnapshot":
          result(self.getActivitySnapshot())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func getActivitySnapshot() -> [String: Any] {
    let idleSeconds = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: .null
    )
    let idleMillis = Int(idleSeconds * 1000.0)

    var highEngagement = "none"
    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
      let id = (frontmostApp.bundleIdentifier ?? "").lowercased()
      let name = (frontmostApp.localizedName ?? "").lowercased()
      let token = "\(id) \(name)"

      if token.contains("zoom") || token.contains("teams") || token.contains("meet") || token.contains("webex") {
        highEngagement = "meeting"
      } else if token.contains("obs") {
        highEngagement = "screenShare"
      } else if token.contains("vlc") || token.contains("quicktime") || token.contains("netflix") || token.contains("youtube") || token.contains("iina") {
        highEngagement = "videoPlayback"
      }
    }

    return [
      "idleMillis": idleMillis,
      "highEngagement": highEngagement,
      // Engagement is derived from the frontmost macOS app, not from Lookup itself.
      "isFrontmost": highEngagement != "none",
    ]
  }
}
