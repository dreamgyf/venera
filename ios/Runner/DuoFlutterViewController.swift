import Flutter
import UIKit

/// Supplies the reserved regions that Flutter's iOS embedder does not yet expose.
class DuoFlutterViewController: FlutterViewController, FlutterStreamHandler {
  private var regionsChannel: FlutterEventChannel?
  private var supportChannel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?
  private var lastPayload: NSDictionary?

  override func awakeFromNib() {
    super.awakeFromNib()
    regionsChannel = FlutterEventChannel(
      name: "venera/display_regions", binaryMessenger: binaryMessenger)
    regionsChannel?.setStreamHandler(self)
    supportChannel = FlutterMethodChannel(
      name: "venera/display_regions_support", binaryMessenger: binaryMessenger)
    supportChannel?.setMethodCallHandler { call, result in
      if call.method == "isAvailable" {
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    var regions = [[String: Any]]()

    // Duo builds require Xcode 27.1+. Xcode 27.0 also has Swift 6.4 but
    // lacks this API. The compiler guard permits development with Xcode 26;
    // those builds have no reserved-region support or Duo full-screen opt-in.
    #if compiler(>=6.4)
    if #available(iOS 27.1, *) {
      for kind in [UIView.ReservedRegion.Kind.division, .occlusion] {
        // Read during layout so UIKit invalidates layout when regions change.
        // Frames already include the system's interaction margins.
        for region in view.reservedRegions(kind: kind) where region.isActive {
          let frame = region.frame.intersection(view.bounds)
          guard !frame.isNull, !frame.isEmpty,
                frame.origin.x.isFinite, frame.origin.y.isFinite,
                frame.width.isFinite, frame.height.isFinite else { continue }
          regions.append([
            "kind": kind == .division ? "division" : "occlusion",
            "x": frame.minX - view.bounds.minX,
            "y": frame.minY - view.bounds.minY,
            "width": frame.width,
            "height": frame.height,
          ])
        }
      }
    }
    #endif

    let payload: NSDictionary = [
      "width": view.bounds.width,
      "height": view.bounds.height,
      "regions": regions,
    ]
    guard let eventSink, lastPayload?.isEqual(payload) != true else { return }
    lastPayload = payload
    eventSink(payload)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    lastPayload = nil
    view.setNeedsLayout()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    lastPayload = nil
    return nil
  }
}
