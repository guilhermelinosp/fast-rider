import CoreLocation
import Flutter
import UIKit

/// No permission requests here: Geolocator requests When In Use first.
/// Each capture owns its manager so cancelled delegates cannot fulfill a retry.
final class CurrentPositionPlugin: NSObject, FlutterPlugin {
  private var active: Capture?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "fast_rider/current_position", binaryMessenger: registrar.messenger())
    let plugin = CurrentPositionPlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    NotificationCenter.default.addObserver(
      plugin, selector: #selector(plugin.enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
      result(FlutterError(code: "invalid", message: "Missing capture ID", details: nil))
      return
    }
    switch call.method {
    case "capture":
      active?.cancel()
      let timeout = min(max((args["timeoutMs"] as? Double ?? 15000) / 1000, 1), 15)
      let capture = Capture(id: id, result: result)
      active = capture
      capture.start(timeout: timeout)
    case "cancel":
      if active?.id == id {
        active?.cancel()
        active = nil
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func enteredBackground() {
    active?.cancel()
    active = nil
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    active?.cancel()
  }
}

private final class Capture: NSObject, CLLocationManagerDelegate {
  let id: String
  private let manager = CLLocationManager()
  private var result: FlutterResult?
  private var timer: Timer?

  init(id: String, result: @escaping FlutterResult) {
    self.id = id
    self.result = result
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.allowsBackgroundLocationUpdates = false
    manager.showsBackgroundLocationIndicator = false
  }

  func start(timeout: TimeInterval) {
    guard manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways else {
      fail("denied")
      return
    }
    // Inactive is allowed because a just-dismissed OS prompt can be inactive.
    guard UIApplication.shared.applicationState != .background else {
      cancel()
      return
    }
    timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
      self?.fail("timeout")
    }
    manager.requestLocation()
  }

  func cancel() { fail("cancelled") }

  private func fail(_ code: String) {
    finish(FlutterError(code: code, message: "Location capture ended", details: nil))
  }

  private func finish(_ value: Any) {
    let callback = result
    result = nil
    timer?.invalidate()
    timer = nil
    // Cancels requestLocation as well as any still-pending delegate callback.
    manager.stopUpdatingLocation()
    manager.delegate = nil
    callback?(value)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else {
      fail("unavailable")
      return
    }
    finish([
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
      "has_accuracy": location.horizontalAccuracy >= 0,
      "timestamp": location.timestamp.timeIntervalSince1970 * 1000,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    fail((error as? CLError)?.code == .denied ? "denied" : "unavailable")
  }
}
