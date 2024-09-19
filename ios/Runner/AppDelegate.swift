import UIKit
import Flutter
import PerfectLibSkinCarePlus  // Import the Skincare SDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let skincareChannel = FlutterMethodChannel(name: "skincare_camera",
                                              binaryMessenger: controller.binaryMessenger)

    skincareChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "openCamera" {
        self?.openSkincareCamera()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openSkincareCamera() {
    // Implement the logic to open the Skincare camera
    let skincareCamera = PerfectLibSkinCarePlusCamera()  // Example initialization
    skincareCamera.presentCamera(from: UIApplication.shared.keyWindow?.rootViewController)
  }
}
