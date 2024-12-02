import UIKit
import Flutter
import AVFoundation
import PerfectLibCore
import PerfectLibSkinCarePlus
import PerfectLibRecommendationHandler
import CoreMotion


//extension PFSkinCareQualityCheck {
//    func canCapture() -> Bool {
//        return lightingQuality.isOk && faceAreaQuality.isOk && faceFrontalQuality.isOk
//    }
//}


@main
@objc class AppDelegate: FlutterAppDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    var session: AVCaptureSession?
       private let wrapper = PerfectLibWrapper()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput: AVCapturePhotoOutput?
     private var countDownTimer: Timer?
    var skincare: SkinCare?
    weak var flutterViewController: FlutterViewController?
    private var originalImage:UIImage!
    private var allSkinImage:String?
    private var skincareReports: [PFSkinAnalysisData]?
    private var skincareReportDict: [String:Int]?
    private var cameraPos: AVCaptureDevice.Position = .front
      @IBOutlet weak var skincareView: UIView!
         @IBOutlet weak var qualityIndicatorView: UIStackView!

         @IBOutlet weak var lightingQuality: UIView!
         @IBOutlet weak var lightingQualityMsg: UILabel!
         @IBOutlet weak var faceFrontalQuality: UIView!
         @IBOutlet weak var faceAreaQuality: UIView!
         @IBOutlet weak var faceAreaQualityMsg: UILabel!
         @IBOutlet weak var countDownIndicator: UILabel!
         @IBOutlet weak var captureFlashView: UIView!
         @IBOutlet weak var importPhotoButton: UIButton!

         @IBOutlet weak var blockingView: UIView!
         @IBOutlet weak var blockingProgressMsg: UILabel!
         @IBOutlet weak var blockingProgressView: UIProgressView!
         @IBOutlet weak var photoAlbumButton: UIButton!
         @IBOutlet weak var cancelBtn: UIButton!
         private var syncServerTask: CancelableTask?
  private var currentState: State = .suspend
    enum State {
        case suspend
        case waitForCountDown
        case countingDown
        case capturing
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

           if let controller = window?.rootViewController as? FlutterViewController {
               // Register the custom camera view factory
               let factory = SkinCareCameraViewFactory()
               controller.registrar(forPlugin: "skincare_camera_view")?.register(factory, withId: "skincare_camera_view")

               let skincareChannel = FlutterMethodChannel(name: "skincare_camera", binaryMessenger: controller.binaryMessenger)

               // Method channel to listen for 'initializeView' from Flutter
               skincareChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                   if call.method == "initializeView" {
                       if let arguments = call.arguments as? [String: Any], let viewId = arguments["viewId"] as? Int {
                           self?.initializeSkincareView(viewId: viewId)
                           result("View initialized")
                       } else {
                           result(FlutterError(code: "INVALID_ARGUMENTS", message: "viewId is missing", details: nil))
                       }
                   } else if call.method == "skincare" {
                       if let arguments = call.arguments as? [String: Any], let skincareData = arguments["skincareData"] as? SkinCare {
                           self?.skincare = skincareData
                           result("Skincare data updated")
                       } else {
                           result(FlutterError(code: "INVALID_ARGUMENTS", message: "skincareData is missing", details: nil))
                       }
                   }
               }
           } else {
               print("Error: Root view controller is not a FlutterViewController")
           }

           return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//        return true
    }

    func skincareViewController() -> UIViewController {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            // Using guard let to safely unwrap the DetailViewController
            guard let skincareViewController = storyboard.instantiateViewController(withIdentifier: "SkincareViewController") as? SkincareViewController else {
                return UIViewController() // Return nil if we cannot instantiate the view controller
            }

            return UINavigationController(rootViewController: skincareViewController)
        }

func openStoryboard() {
    guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
          let flutterViewController = window.rootViewController as? FlutterViewController else {
        print("FlutterViewController not found!")
        return
    }

    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let skincareViewController = storyboard.instantiateViewController(withIdentifier: "SkincareViewController") as? SkincareViewController else {
        return
    }

    // Pass the FlutterViewController instance
    skincareViewController.flutterViewController = flutterViewController

    // Embed SkincareViewController in a UINavigationController
    let navigationController = UINavigationController(rootViewController: skincareViewController)

    // Present the UINavigationController modally
    flutterViewController.present(navigationController, animated: true, completion: nil)
}

    // Initialize skincareView from Flutter's view ID
    func initializeSkincareView(viewId: Int) {
        // Assuming the viewId maps to a PlatformView on Flutter side
        guard let controller = window?.rootViewController as? FlutterViewController else { return }

        // Get the native view associated with the PlatformView ID
        if let platformView = controller.view.viewWithTag(viewId) {
            self.skincareView = platformView
        } else {
            fatalError("Failed to initialize skincareView")
        }

        // Once skincareView is initialized, call setupCameraAndPreview

        setupCameraAndPreview()
         viewDidLoad()
           currentState = .waitForCountDown
    }


    private func doLongOperation(message: String, showCancel:Bool = true, closure: @escaping (@escaping ()->Void)->Void) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            self.blockingProgressMsg.text = message
            self.blockingView.isHidden = false
            self.blockingProgressView.progress = 0
            self.blockingProgressView.isHidden = !showCancel
            self.cancelBtn.isHidden = !showCancel
            closure({
                SynchronousTool.asyncMainSafe {
                    self.blockingView.isHidden = true
                }
            })
        }
    }

  func viewDidLoad() {
          let newViewController = UIViewController()
        wrapper.waitLibInit(newViewController) { [weak self,weak newViewController] in
           guard let self = self, let newViewController = newViewController else {   print("sync sddone"); return }

            self.createSkincare()
  print("sync sdone")
            guard let settingId = UserDefaults.standard.string(forKey: "skincareSettingId"), settingId.count > 0 else {
                return
            }
            self.doLongOperation(message: "Syncing skin care products and surveys, please wait.") { [weak newViewController] (completion) in
                guard let newViewController = newViewController else { return }

                 self.syncServerTask = RecommendationHandler.sharedInstance().syncServer(.skinCare, successBlock: { (done) in
                    completion()
                    print("sync done")
                    if (!done){
                        SynchronousTool.asyncMainSafe {
                            let alert = UIAlertController(title: "Error", message: "Syncing server operation failed or canceled.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Leave", style: .destructive, handler: { (_) in
                                newViewController.navigationController?.popViewController(animated: true)
                            }))
                            newViewController.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                }, failureBlock: { (error) in
                    guard let error = error as NSError? else { return }
                    SynchronousTool.asyncMainSafe { [ weak newViewController] in
                        guard let newViewController = newViewController else { return }
                        let alert = UIAlertController(title: "Error", message: error.localizedDescription + "\nRecovery suggestion : " + (error.localizedRecoverySuggestion ?? ""), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (_) in
                            newViewController.navigationController?.popViewController(animated: true)
                        }))
                        newViewController.present(alert, animated: true, completion: nil)
                    }
                }, progressBlock: { (progress) in
                    SynchronousTool.asyncMainSafe {
                        self.blockingProgressView.progress = Float(progress)
                    }
                    print("progress : \(progress)")
                })
            }
        }
    }

       func createSkincare(completion: ((_ created: Bool) -> Void)? = nil) {
             let newViewController = UIViewController()
             SkinCare.create { [weak self] (skincare, error) in
                 guard let self = self else { return }

                 if let error = error {

                     SynchronousTool.asyncMainSafe {
                         let alert = UIAlertController(
                             title: "Error 1212",
                             message: error.localizedDescription,
                             preferredStyle: .alert
                         )
                         alert.addAction(UIAlertAction(title: "OK", style: .destructive) { _ in
                             newViewController.navigationController?.popViewController(animated: true)
                         })

                         // Present the alert safely
                         if newViewController.isViewLoaded, newViewController.view.window != nil {
                             newViewController.present(alert, animated: true, completion: nil)
                         } else {
                             // Optionally present on rootViewController
                             if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                                 rootViewController.present(alert, animated: true, completion: nil)
                             }
                         }
                     }
                     return
                 }
                 print("progress : --------")
                 self.skincare = skincare
                 self.skincare?.delegate = self
                 completion?(error == nil)
             }
         }


    private func analyzeImage(image: UIImage, isLive: Bool) {
        if let skincare = skincare {
            originalImage = image
            skincare.setImage(originalImage, completion: { [weak self] (error) in
                if error != nil {
                    SynchronousTool.asyncMainSafe {
                        let alert = UIAlertController(title: "Error", message: "The photo quality isn't good, please retake!", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .destructive, handler: { (_) in
                            self?.session?.startRunning()
                            self?.currentState = .waitForCountDown
                        }))
//                        self?.present(alert, animated: true, completion: nil)
                    }
                } else {
                    SynchronousTool.asyncMainSafe { [weak self] in
                        guard let self = self else { return }
                        guard let skincare = self.skincare else { return }
                        guard let dst = SkincareReportViewController.viewController(skincare: skincare, skinFeatures: skincare.availableFeatures, faceImage: self.originalImage) else {
                            return
                        }

                        if isLive {
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                self.fetchAndSendSkincareReports()
                            })
                            let alert = UIAlertController(title: nil, message: "Do you want to save the captured image for future reference?", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Sure", style: .default, handler: { [weak self] _ in
                                guard let self = self else { return }
                                let imageData = self.originalImage.pngData()
                                let pngImage = UIImage(data: imageData!)
                                UIImageWriteToSavedPhotosAlbum(pngImage!, nil, nil, nil)

                                print("--------<<<--- navigationController", skincare.availableFeatures)
//                                self.navigationController?.pushViewController(dst, animated: true)
                            }))
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
                                guard let self = self else { return }

                                print("--------<<<--- navigationController", skincare.availableFeatures)
//                                self.navigationController?.pushViewController(dst, animated: true)
                                // Add a delay before calling doLongOperation1
                                DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                    self.fetchAndSendSkincareReports()
                                })
                                
                            }))
//                            self.present(alert, animated: true)
                        } else {
//                            self.navigationController?.pushViewController(dst, animated: true)
                        }
                    }
                }
            })
        }
    }
    var selectedSkinFeatures: [String] = []
    var selectedSkinImageList: [String: String] = [:]
    private func updateImage(imanensme : String,skinFeatureList: [String]? = nil) {
        self.skincare?.getAnalyzedImage(bySkinFeatures: skinFeatureList ?? [imanensme], completion: { (image, error) in
            if let image = image {
                SynchronousTool.asyncMainSafe { [weak self] in
                    guard let self = self else { return }
                    print("-----image ----",image)
                    
                    if ((skinFeatureList?.isEmpty) != nil) {
                        let imagefile = self.saveImageToDocumentsDirectory(image:image, imageName:"allSkin")
                        self.allSkinImage = imagefile
                    } else {
                        let imagefile = self.saveImageToDocumentsDirectory(image:image, imageName:imanensme )
                                         self.selectedSkinImageList[imanensme] = imagefile
                        if self.selectedSkinImageList.count == self.selectedSkinFeatures.count{
                            if let flutterViewController = self.window?.rootViewController as? FlutterViewController {
                                let channel = FlutterMethodChannel(
                                    name: "skincare_channel",
                                    binaryMessenger: flutterViewController.binaryMessenger
                                )
        if let imageData = self.originalImage?.pngData() {
                                 let base64Image = imageData.base64EncodedString()
                                let arguments: [String: Any] = [
                                    "skincareReportDict": self.skincareReportDict,
                                       "imageBase64": base64Image,
                                    "selectedSkinImageList" : self.selectedSkinImageList,
                                    "allSkinImage" : self.allSkinImage
                                ]

                                // Log the data being sent to Flutter
        print("Sending skincare report data to Flutter: \(String(describing: self.skincareReportDict))")

                                // Send the dictionary to Flutter
            self.previewLayer?.removeFromSuperlayer()
            self.session?.stopRunning()
                                channel.invokeMethod("updateSkincareData1", arguments: arguments) { result in
                                    // Optional: Handle the result from Flutter
                                    if let error = result as? FlutterError {
                                        print("Error sending data to Flutter: \(error.message ?? "Unknown error")")
                                    } else {
                                        print("Successfully sent data to Flutter.")
                                    }
                                }
                                }else {
                                                                 print("Error: Image data is nil")
                                                             }
                            } else {
                                print("FlutterViewController is nil, unable to send data.")
                            }
                        }
                    }
                 
          
                    
                    
                                     // Optionally, you can set the image to an imageView or update the UI
                                     // self.imageView.image = image
                                 
//                    self.imageView.image = image
                }
            }
//            if let error = error {
//                let alert = UIAlertController(title: "Get Analyzed Image Failed", message: error.localizedDescription, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .default))
////                self.present(alert, animated: true)
//            }
        })
    }

    func saveImageToDocumentsDirectory(image: UIImage, imageName: String) -> String? {
        // Get the document directory path
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Create the full file path using the image name
            let imagePath = documentsDirectory.appendingPathComponent("\(imageName).png")

            // Convert the UIImage to PNG data
            if let imageData = image.pngData() {
                do {
                    // Write the data to the image file path
                    try imageData.write(to: imagePath)
                    print("Image saved at path: \(imagePath.path)")
                    return imagePath.path  // Return the path to the saved image
                } catch {
                    print("Error saving image: \(error.localizedDescription)")
                }
            } else {
                print("Error: Failed to convert image to data.")
            }
        }
        return nil
    }

    
    func fetchAndSendSkincareReports() {
       DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
           self?.doLongOperation1 { [weak self] completion in
               guard let self = self, let skincare = self.skincare else { return }
               print("Report: Report")
               let features = skincare.availableFeatures
               
               skincare.getReports(bySkinFeatures: features) { [weak self] reports in
                   guard let self = self else { return }
                   
                   DispatchQueue.global().async {
                       // Update reports and dictionary on background thread
                       self.skincareReports = reports
                       print("Report: \(reports)")
                       
                       // Reduce reports to a dictionary
                       self.skincareReportDict = reports.reduce([String: Int]()) { partialResult, data in
                           var result = partialResult
                           result[data.feature] = Int(data.score) // Ensure this is a valid conversion
                           return result
                       }
                       
                       DispatchQueue.main.async { // Switch to main thread for UI updates
                           // Check if rootViewController is a UINavigationController
                      
                           if let reportDict = self.skincareReportDict {
                               self.selectedSkinFeatures = Array(reportDict.keys) // Extract keys from the unwrapped dictionary
                           } else {
                               print("skincareReportDict is nil")
                           }
                           
                           print("view cdata",self.selectedSkinFeatures.count)
                           self.updateImage(imanensme: "", skinFeatureList: self.selectedSkinFeatures)
                           
                           for (i, item) in self.selectedSkinFeatures.enumerated() {
                               self.updateImage(imanensme: item)
                           }
                           
                       
                       }
                   }
               }
           }
       }
   }
    
    private func doLongOperation1(closure: @escaping (@escaping ()->Void)->Void) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
         
            closure({
                SynchronousTool.asyncMainSafe {
                
                }
            })
        }
    }



    // Camera setup and preview
func setupCameraAndPreview() {
    print("Setting up camera preview...")

    // Check if skincareView is initialized
    guard let skincareView = self.skincareView else {
        fatalError("skincareView is not initialized")
    }

    // Initialize session
    let session = AVCaptureSession()

    // Begin camera session configuration
    session.beginConfiguration()

    // Get the front camera device
    guard let input = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
        fatalError("Failed to get AVCaptureDevice")
    }

    // Add the input to the session
    guard let deviceInput = try? AVCaptureDeviceInput(device: input) else {
        fatalError("Failed to create AVCaptureDeviceInput")
    }
    if session.canAddInput(deviceInput) {
        session.addInput(deviceInput)
    } else {
        fatalError("Cannot add input device to session")
    }

    // Set up video output
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
    output.alwaysDiscardsLateVideoFrames = false

    // Set up delegate queue
    let queue = DispatchQueue(label: "com.example.cameraQueue")
    output.setSampleBufferDelegate(self, queue: queue)

    // Add video output to session
    if session.canAddOutput(output) {
        session.addOutput(output)
    } else {
        fatalError("Cannot add output to session")
    }

    // Set up photo output
    let photoOutput = AVCapturePhotoOutput()
    if session.canAddOutput(photoOutput) {
        session.addOutput(photoOutput)
        self.photoOutput = photoOutput
        photoOutput.isHighResolutionCaptureEnabled = true
    } else {
        fatalError("Cannot add photo output to session")
    }

    // Set session preset
    session.sessionPreset = .high

    // Commit session configuration
    session.commitConfiguration()
    print("Session configuration completed.")

    // Set up preview layer for camera feed
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.frame = CGRect(x: 50, y: 100, width: 250, height: 250)

    previewLayer.videoGravity = .resizeAspectFill

    // Check if the previewLayer is correctly added to the skincareView
    if skincareView.layer.sublayers?.contains(previewLayer) == false {
        skincareView.layer.addSublayer(previewLayer)
        print("Preview layer added successfully.")
    } else {
        print("Preview layer already exists.")
    }

    self.previewLayer = previewLayer

    // Start camera session on a background thread
    DispatchQueue.global(qos: .background).async {
        print("Starting camera session...")
        session.startRunning()
        DispatchQueue.main.async {
            print("Camera session started")
        }
    }

    // Save session reference
    self.session = session
}

    private var countDownValue: Int = 3 { // 3 is the initial value
        didSet {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
//                self.countDownIndicator.text = "\(self.countDownValue)"
//                self.countDownIndicator.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
//                UIView.animate(withDuration: 0.3) {
//                    self.countDownIndicator.transform = CGAffineTransform.identity
//                }
            }
        }
    }
        @objc private func timerMethod(timer: Timer) {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                self.countDownValue -= 1
                if let flutterViewController = self.window?.rootViewController as? FlutterViewController {
                    let channel = FlutterMethodChannel(
                        name: "skincare_channel",
                        binaryMessenger: flutterViewController.binaryMessenger
                    )
                    let arguments: [String: Any] = [
                        "countDownValue": self.countDownValue,
                    ]
                    channel.invokeMethod("updateSkincareData2", arguments: arguments) { result in
                        // Optional: Handle the result from Flutter
                        if let error = result as? FlutterError {
                            print("Error sending data to Flutter: \(error.message ?? "Unknown error")")
                        } else {
                            print("Successfully sent data to Flutter.")
                        }
                    }
                } else {
                    print("FlutterViewController is nil, unable to send data.")
                }
                print("-sdsd-----done",self.countDownValue)
                if self.countDownValue == 0 {
//                    self.countDownIndicator.isHidden = true
                    self.countDownTimer?.invalidate()
                    self.countDownTimer = nil
                    print("------done")

                    self.capture()
                }
            }
        }
    
    
    private func capture() {
        currentState = .capturing
//        self.captureFlashView.alpha = 0
//        self.captureFlashView.isHidden = false
//        UIView.animate(withDuration: 0.3, animations: {
//            self.captureFlashView.alpha = 1
//        }) { (_) in
//            self.captureFlashView.isHidden = true
//        }
        if let photoOutput = self.photoOutput {
            let setting = AVCapturePhotoSettings()
            setting.isHighResolutionPhotoEnabled = true
            setting.flashMode = .off
            photoOutput.capturePhoto(with: setting, delegate: self)
        }
    }


       private func startCountingDown() {
            currentState = .countingDown
//            countDownIndicator.isHidden = false
            countDownValue = 3
            countDownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerMethod(timer:)), userInfo: nil, repeats: true)
        }

           private func stopCountingDown() {
//                countDownIndicator.isHidden = true
                countDownTimer?.invalidate()
                countDownTimer = nil
                currentState = .waitForCountDown
            }


    // AVCaptureVideoDataOutputSampleBufferDelegate method for processing camera buffers
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        skincare?.sendCameraBuffer(sampleBuffer)
    }
    
    
    private func currentDeviceOrientation() -> UIDeviceOrientation {
        guard (UIDevice.current.orientation != .portrait && UIDevice.current.orientation != .portraitUpsideDown &&
               UIDevice.current.orientation != .landscapeRight && UIDevice.current.orientation != .landscapeLeft) else {
            return UIDevice.current.orientation
        }

        var orientation : UIInterfaceOrientation?
        if #available(iOS 13.0, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }

        switch orientation {
        case .unknown:
            return .portrait
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            // UIInterfaceOrientationLandscapeLeft is equal to UIDeviceOrientationLandscapeRight
            return .landscapeRight
        case .landscapeRight:
            // UIInterfaceOrientationLandscapeRight is equal to UIDeviceOrientationLandscapeLeft
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
}


class SkinCareCameraViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments: Any?) -> FlutterPlatformView {
        return SkinCareCameraView(frame: frame, viewId: viewId, arguments: arguments)
    }
}

class SkinCareCameraView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(frame: CGRect, viewId: Int64, arguments: Any?) {
        _view = UIView(frame: frame)
        super.init()
        // Set up your view (camera preview, etc.) here
    }

    func view() -> UIView {
        return _view
    }
}


    @available(iOS 10.0, *)
    extension AppDelegate: SkinCareDelegate {
        func skinCare(_ skinCare: SkinCare, checkedResult: PFSkinCareQualityCheck) {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self, self.currentState != .capturing else { return }
                print("----------view");
//                self.lightingQuality.backgroundColor = checkedResult.lightingQuality.color
//                self.faceFrontalQuality.backgroundColor = checkedResult.faceFrontalQuality.color
//                self.faceAreaQuality.backgroundColor = checkedResult.faceAreaQuality.color
//                self.lightingQualityMsg.text = checkedResult.lightingQuality.string
//                self.faceAreaQualityMsg.text = checkedResult.faceAreaQuality.string
//                let color = checkedResult.lightingQuality.color // Assuming it's a non-optional UIColor
                 let lightingQuality = checkedResult.lightingQuality.color.toHex()
                 let faceAreaQuality = checkedResult.faceAreaQuality.color.toHex()
                 let faceFrontalQuality = checkedResult.faceFrontalQuality.color.toHex()
 print("checkedResult Flutter: \(checkedResult.lightingQuality.color)")
                if let flutterViewController = self.window?.rootViewController as? FlutterViewController {
                    let channel = FlutterMethodChannel(
                        name: "skincare_channel",
                        binaryMessenger: flutterViewController.binaryMessenger
                    )
                    let arguments: [String: Any] = [
                        "lightingQuality_color": lightingQuality,
                        "faceFrontalQuality_color": faceAreaQuality,
                        "faceAreaQuality_color": faceFrontalQuality,
                        "lightingQuality": checkedResult.lightingQuality.string ?? "Lighting",
                        "faceFrontalQuality": checkedResult.faceAreaQuality.string ?? "Face Frontal",
                        "faceAreaQuality": checkedResult.faceFrontalQuality.string ?? "Face Area"
                    ]
                    channel.invokeMethod("updateSkincareData", arguments: arguments) { result in
                        // Optional: Handle the result from Flutter
                        if let error = result as? FlutterError {
                            print("Error sending data to Flutter: \(error.message ?? "Unknown error")")
                        } else {
                            print("Successfully sent data to Flutter.")
                        }
                    }
                } else {
                    print("FlutterViewController is nil, unable to send data.")
                }
               if checkedResult.canCapture() {
                             if self.currentState == .waitForCountDown {
                               
                                 
                                 self.startCountingDown()
                             }
                         }
                         else {
                             if self.currentState == .countingDown {
                                 print("checkedResult",checkedResult.lightingQuality.string)
                                 print("checkedResult",checkedResult.faceFrontalQuality.string)
                                 print("checkedResult",checkedResult.faceAreaQuality.string)
                                 self.stopCountingDown()
                             }
                         }
            }
        }
    }

@available(iOS 10.0, *)
extension AppDelegate : AVCapturePhotoCaptureDelegate
{
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        if let previewImage = UIImage(data: imageData) {
            var rotatedImage : UIImage
            switch currentDeviceOrientation() {
            case .portrait:
                rotatedImage = UIImage(cgImage: (previewImage.rotate(radians: .pi * 2))!.cgImage!, scale: 1.0, orientation: .up)
            case .landscapeLeft:
                rotatedImage = UIImage(cgImage: (previewImage.rotate(radians: -.pi * 1.5))!.cgImage!, scale: 1.0, orientation: .up)
            case .landscapeRight:
                rotatedImage = UIImage(cgImage: previewImage.cgImage!, scale: 1.0, orientation: .up)
            default:
                rotatedImage = UIImage(cgImage: (previewImage.rotate(radians: .pi * 2))!.cgImage!, scale: 1.0, orientation: .up)
            }
            if cameraPos == .front {
                rotatedImage = rotatedImage.flipImage()!
            }
            print("----------------------")
            analyzeImage(image: rotatedImage, isLive: true)
        }
    }
}
