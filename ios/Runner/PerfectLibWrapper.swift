//
//  libWrapper.swift
//  PerfectLibDemo
//
//  Created by Alex Lin on 2019/5/17.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit
import PerfectLibCore
import Foundation

class PerfectLibWrapper {
    public static let LibInitDoneNotification = "LibInitDoneNotification"
    public let userId: String
    private var observer: NSObjectProtocol? = nil
    private var initError: Error? = nil
    private var inited = false

    init() {
        // the user ID is user defined ID which can be any value, the lib will send this ID with logs
        // this is an optional value
        var userId: String? = UserDefaults.standard.string(forKey: "PerfectLib.Demo.Saved.UserId")

        if userId == nil {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: "PerfectLib.Demo.Saved.UserId")
            UserDefaults.standard.synchronize()
        }
        self.userId = userId!

        // Set debug mode to turn on the console log, download toast and some other debug features, better turn this on when developing
        PerfectLib.setDebugMode(true)
        // Setting the configuration to the PerfectLib
        // please see documents and console documents for further information about the items
        let imageSource = ImageSource(rawValue: UInt(PerfectLibSettings.shared.imageSource)) ?? .url
        let builder = PerfectLibConfigurationBuilder()
            .setImageSource(imageSource)
            .setUserId(self.userId)
            .setDeveloperMode(UserDefaults.standard.bool(forKey: "isDeveloperMode"))
            .setPreviewMode(UserDefaults.standard.bool(forKey: "isPreviewMode"))
            .setSkinCareSurveyId(UserDefaults.standard.string(forKey: "skincareSurveyId") ?? "", andSettingId: UserDefaults.standard.string(forKey: "skincareSettingId") ?? "")
            .setMappingMode(UserDefaults.standard.bool(forKey: "isMappingMode"))
        if let modelPath = Bundle.main.path(forResource: "model", ofType: "") {
            builder
                .setModelsPath(modelPath)
        }
        if let configFile = PerfectLibSettings.shared.configFile, let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString? {
            let configFilePath = docPath.appendingPathComponent(configFile)
            builder.setConfigFile(configFilePath)
        }
        let config = builder.build()

        // Ininitialize the PerfectLib with specified configuration, and a completion handler
        PerfectLib.initWith(config, successBlock: { (preloadError, list) in
            self.inited = true
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: PerfectLibWrapper.LibInitDoneNotification), object: preloadError)
        }, failureBlock: { [weak self] in
            print("library initialization failed, error = \(String(describing: $0))")
            self?.initError = $0
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: PerfectLibWrapper.LibInitDoneNotification), object: $0)
        })

        // Setup the maximun cache size in MB for the PerfectLib, when uninit PerfectLib, the library will do a clean up if the cache size exceeds the given maximun size according to the least recent used items
        if PerfectLib.getMaxCacheSize() == CUnsignedLong.max {
            PerfectLib.setMaxCacheSize(100)
        }

        let country = PerfectLib.getCountryCode() ?? "us"
        let locale = PerfectLib.getLocaleCode() ?? "en_US"

        // The country code and locale code must be specified before start using the library, this is important for we need the information to get the correct contents for AR makeup
        PerfectLib.setCountryCode(country)
        PerfectLib.setLocaleCode(locale)

    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }

        // When a library is no longer needed, call the uninit function to release the memories and resources
        PerfectLib.uninit()
    }

    public func waitLibInit(_ parent: UIViewController, closure: @escaping ()->Void) {
     print("Makeup 1")
        weak var viewController = parent
            print("Makeup 2")
        let handleError: (Error)->Void = { (error) in
            SynchronousTool.asyncMainSafe {
              print("Makeup 4")
                guard let viewController = viewController else { return }
  print("Makeup 4")
                if TARGET_OS_SIMULATOR != 0 && (error as NSError).code == PerfectLibErrorCode.moduleLoadFailed.rawValue {
                    print("Makeup apply engine doesn't support the simulator env.")
                    return;
                }
  print(error)
                let alert = UIAlertController(title: "Library initilization error", message: String(describing: error), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                viewController.present(alert, animated: true, completion: nil)
            }
        }
        let handlePreloadError: (NSDictionary)->Void = { (preloadError) in
            SynchronousTool.asyncMainSafe {
                guard let viewController = viewController else { return }

                let alert = UIAlertController(title: "Preload error", message: String(describing: preloadError), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                viewController.present(alert, animated: true, completion: nil)
            }
        }
        if let error = initError {
            handleError(error)
              print("Makeup s")
            return
        }
        else if inited {
            closure()
              print("Makeup s")
            return
        }
          print("Makeup d")
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(PerfectLibWrapper.LibInitDoneNotification), object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            if let error = notification.object as? Error {
                handleError(error)
            } else if let preloadError = notification.object as? NSDictionary {
                handlePreloadError(preloadError)
            } else {
                closure()
            }
            if let observer = self?.observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// MARK: - extensions for PerfectLib enumeratios
extension PerfectLibQuality {
    var color: UIColor {
        switch self {
        case .QUALITY_NOT_GOOD:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .QUALITY_OK:
            return #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
        case .QUALITY_GOOD:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .QUALITY_UNKNOWN:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        @unknown default:
            fatalError()
        }
    }

    var isOk: Bool {
        return self == .QUALITY_GOOD || self == .QUALITY_OK
    }
}

extension PFFaceFrontalQuality {
    var color: UIColor {
        switch self {
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .bad:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        @unknown default:
            fatalError()
        }
    }
    var string: String {
        switch self {
        case .bad: return "Look Straight"
        default: return ""
        }
    }
    var isOk: Bool {
        return self == .good
    }
}

extension PFFaceAreaQuality {
    var color: UIColor {
        switch self {
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .outOfBoundary:
            return #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
        case .tooSmall:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        @unknown default:
            fatalError()
        }
    }
    var string: String {
        switch self {
        case .tooSmall: return "Too Far Away"
        case .outOfBoundary: return "Move Backward"
        default: return ""
        }
    }
    var isOk: Bool {
        return self == .good
    }
}

extension PFFaceCenterQuality {
    var color: UIColor {
        switch self {
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .tooLow:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .tooHigh:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .tooLeft:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .tooRight:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        @unknown default:
            fatalError()
        }
    }
    var string: String {
        switch self {
        case .tooLow: return "Too Low"
        case .tooHigh: return "Too high"
        case .tooLeft: return "Too left"
        case .tooRight: return "Too right"
        default: return ""
        }
    }
    var isOk: Bool {
        return self == .good
    }
}

extension PFLightingQuality {
    var color: UIColor {
        switch self {
        case .normal:
            return #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .dark:
            return #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        case .uneven:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        @unknown default:
            fatalError()
        }
    }
    var string: String {
        switch self {
        case .dark: return "Too dark"
        case .uneven: return "Uneven"
        default: return ""
        }
    }
    var isOk: Bool {
        return self == .good || self == .normal
    }
}

extension PFLightingQuality2 {
    var color: UIColor {
        switch self {
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        case .normal:
            return #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
        case .good:
            return #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        case .overExposed:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .uneven :
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .underExposed:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        case .backlighting:
            return #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        @unknown default: fatalError()
        }
    }

    var string: String {
        switch self {
        case .backlighting:
            return "BackLighting"
        case .uneven:
            return "Uneven"
        case .overExposed:
            return "OverExposed"
        case .underExposed:
            return "UnderExposed"
        default:
            return ""
        }
    }
    var isOk: Bool {
        return self == .good || self == .normal
    }
}


extension PFNakedEyeQuality {
    var color: UIColor {
        switch self {
        case .unknown:
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        case .no:
            return #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
        case .yes:
            return #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1)
        @unknown default:
            fatalError()
        }
    }
    var string: String {
        switch self {
        case .no: return "NO"
        case .yes: return "YES"
        default: return ""
        }
    }
    var isOk: Bool {
        return self == .no || self == .yes
    }
}

extension PerfectLibFaceSide {
    var string: String {
        switch self {
        case .front:
            return "Front"
        case .right:
            return "Right"
        case .left:
            return "Left"
        @unknown default:
            fatalError()
        }
    }

    var turnHeadString: String {
        switch self {
        case .right:
            return "⇦⇦⇦⇦⇦"
        case .left:
            return "⇨⇨⇨⇨⇨"
        default:
            return ""
        }
    }

    var countdownValue: Int {
        return (self == .front) ? 3 : 1;
    }

    var next: PerfectLibFaceSide? {
        let newValue = self.rawValue + 1
        if newValue > PerfectLibFaceSide.right.rawValue {
            return nil
        }
        return PerfectLibFaceSide(rawValue: newValue)
    }
}

extension PerfectLibQualityMsg {
    var string: String {
        switch self {
        case .faceAreaTooSmall:
            return "Too small"
        case .faceAreaOutOfBoundary:
            return "Out of boundary"
        case .lightingOverExposed:
            return "Over expo."
        case .lightingUnderExposed:
            return "Under expo."
        case .lightingBacklighting:
            return "Backlighting"
        case .lightingUneven:
            return "Uneven"
        default:
            return ""
        }
    }
}

extension String {
    func stringByAppendingPathComponent(path: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(path)
    }
}
