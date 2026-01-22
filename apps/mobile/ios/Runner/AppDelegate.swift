import Flutter
import UIKit
import ReplayKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "media_projection", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler({ [weak self] (call, result) in
        if call.method == "startMediaProjectionService" {
          self?.showBroadcastPicker()
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return result
  }

  private func showBroadcastPicker() {
    DispatchQueue.main.async {
      if #available(iOS 12.0, *) {
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        pickerView.preferredExtension = "com.castnow.app.BroadcastExtension"
        pickerView.showsMicrophoneButton = false
        
        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.keyWindow
        
        if let keyWindow = window {
          keyWindow.addSubview(pickerView)
          pickerView.center = keyWindow.center
          pickerView.alpha = 0.01
          
          for view in pickerView.subviews {
            if let button = view as? UIButton {
              button.sendActions(for: .touchUpInside)
              break
            }
          }
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              pickerView.removeFromSuperview()
          }
        }
      }
    }
  }
}
