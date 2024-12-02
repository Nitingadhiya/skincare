//
//  SkincareV2ViewController.swift
//  PerfectLibDemo
//
//  Created by alex lin on 2019/10/15.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit
import PerfectLibCore
import AVFoundation
import PerfectLibSkinCarePlus
import PerfectLibRecommendationHandler


extension PFSkinCareQualityCheck {
    func canCapture() -> Bool {
        return lightingQuality.isOk && faceAreaQuality.isOk && faceFrontalQuality.isOk
    }
}

@available(iOS 10.0, *)
class SkincareViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
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
   weak var flutterViewController: FlutterViewController?
    enum State {
        case suspend
        case waitForCountDown
        case countingDown
        case capturing
    }

    private let wrapper = PerfectLibWrapper()
    private var skincare: SkinCare?
    private var skincareReportDict: [String:Int]?
    private var skincareReports: [PFSkinAnalysisData]?
    private var currentState: State = .suspend
    private var countDownTimer: Timer?
    private var faceImageKeeper: [PerfectLibFaceSide:UIImage] = [:]
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var hasSetCamera = false
    private var skinFeatures:[String]?
    private var originalImage:UIImage!

    private var cameraPos: AVCaptureDevice.Position = .front

    private func correctView(to size: CGSize? = nil) {
        // Set device orientation based on UI
        let height = size?.height ?? UIScreen.main.bounds.height
        let width = size?.width ?? UIScreen.main.bounds.width

        self.skincareView.center = CGPoint(x: width / 2, y: height / 2)

        switch currentDeviceOrientation() {
        case .portrait:
            self.skincareView.transform = .identity
        case .portraitUpsideDown:
            self.skincareView.transform = CGAffineTransform(rotationAngle: .pi)
        case .landscapeLeft:
            self.skincareView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        case .landscapeRight:
            self.skincareView.transform = CGAffineTransform(rotationAngle: .pi / 2)
        default:
            self.skincareView.transform = .identity
        }
    }

    var currentPreset: AVCaptureSession.Preset? {
        didSet {
            guard let preset = self.currentPreset else { return }
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                var frame : CGRect
                if preset == .photo {
                    frame = self.getFrameBy(aspectRatio: 4.0/3.0)
                }
                else {
                    frame = self.getFrameBy(aspectRatio: 16.0/9.0)
                }
                self.skincareView.bounds = frame
            }
        }
    }

    func createSkincare(completion: ((_ created: Bool)->Void)? = nil) {
        SkinCare.create() { [weak self] (skincare, error) in
            if let error = error {
                SynchronousTool.asyncMainSafe {
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { (_) in
                        self?.navigationController?.popViewController(animated: true)
                    }))
                    self?.present(alert, animated: true, completion: nil)
                }
                return
            }
            self?.skincare = skincare
            self?.skincare?.delegate = self
            completion?(error == nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        wrapper.waitLibInit(self) { [weak self] in
            guard let self = self else { return }
            self.createSkincare()

            guard let settingId = UserDefaults.standard.string(forKey: "skincareSettingId"), settingId.count > 0 else {
                return
            }
            self.doLongOperation(message: "Syncing skin care products and surveys, please wait.") { [weak self] (completion) in
                guard let self = self else { return }

                self.syncServerTask = RecommendationHandler.sharedInstance().syncServer(.skinCare, successBlock: { (done) in
                    completion()
                    print("sync done")
                    if (!done){
                        SynchronousTool.asyncMainSafe {
                            let alert = UIAlertController(title: "Error", message: "Syncing server operation failed or canceled.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Leave", style: .destructive, handler: { (_) in
                                self.navigationController?.popViewController(animated: true)
                            }))
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                }, failureBlock: { (error) in
                    guard let error = error as NSError? else { return }
                    SynchronousTool.asyncMainSafe { [ weak self] in
                        guard let self = self else { return }
                        let alert = UIAlertController(title: "Error", message: error.localizedDescription + "\nRecovery suggestion : " + (error.localizedRecoverySuggestion ?? ""), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (_) in
                            self.navigationController?.popViewController(animated: true)
                        }))
                        self.present(alert, animated: true, completion: nil)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasSetCamera {
            currentPreset = .photo
            #if !targetEnvironment(simulator)
            setupCameraAndPreview()
            #endif
            correctView()
            hasSetCamera.toggle()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        correctView(to: size)
    }

    private var appActiveObserver: NSObjectProtocol? = nil
    private var appInactiveObserver: NSObjectProtocol? = nil
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        faceImageKeeper.removeAll()
        currentState = .waitForCountDown

        session?.startRunning()
        appActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (notification) in
            guard let self = self else {
                return
            }
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.session?.startRunning()
            }
        }

        appInactiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] (notification) in
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.session?.stopRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let timer = countDownTimer {
            timer.invalidate()
            countDownTimer = nil
        }

        session?.stopRunning()
        if let appActiveObserver = appActiveObserver {
            NotificationCenter.default.removeObserver(appActiveObserver)
        }
        if let appInactiveObserver = appInactiveObserver {
            NotificationCenter.default.removeObserver(appInactiveObserver)
        }
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

    deinit {
        skincare = nil
    }

    // MARK: - actions
    @IBAction func actionBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func actionImportPhoto(_ sender: Any) {
        SynchronousTool.asyncMainSafe {
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .photoLibrary
            imagePicker.delegate = self
            imagePicker.presentationController?.delegate = self
            self.present(imagePicker, animated: false, completion: nil)
            self.session?.stopRunning()
            self.stopCountingDown()
        }
    }

    @IBAction func actionSwitchCamera(_ sender: Any) {
        session?.stopRunning()
        session = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        skincare = nil
        cameraPos = cameraPos == .front ? .back : .front
        createSkincare() { [weak self] created in
            if created {
                self?.setupCameraAndPreview()
            }
        }
    }

    // MARK: - private
    private func getFrameBy(aspectRatio ratio:CGFloat) -> CGRect {
        let screenW = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let screenH = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        var w = screenW
        var h = w * ratio

        if h > screenH {
            h = screenH
            w = h / ratio
        }

        return CGRect(x: 0, y: 0, width: w, height: h)
    }

    private var countDownValue: Int = 3 { // 3 is the initial value
        didSet {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                self.countDownIndicator.text = "\(self.countDownValue)"
                self.countDownIndicator.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                UIView.animate(withDuration: 0.3) {
                    self.countDownIndicator.transform = CGAffineTransform.identity
                }
            }
        }
    }

    private func startCountingDown() {
        currentState = .countingDown
        countDownIndicator.isHidden = false
        countDownValue = 3
        countDownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerMethod(timer:)), userInfo: nil, repeats: true)
    }

    private func stopCountingDown() {
        countDownIndicator.isHidden = true
        countDownTimer?.invalidate()
        countDownTimer = nil
        currentState = .waitForCountDown
    }

    private func capture() {
        currentState = .capturing
        self.captureFlashView.alpha = 0
        self.captureFlashView.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            self.captureFlashView.alpha = 1
        }) { (_) in
            self.captureFlashView.isHidden = true
        }
        if let photoOutput = self.photoOutput {
            let setting = AVCapturePhotoSettings()
            setting.isHighResolutionPhotoEnabled = true
            setting.flashMode = .off
            photoOutput.capturePhoto(with: setting, delegate: self)
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
                        self?.present(alert, animated: true, completion: nil)
                    }
                } else {
                    SynchronousTool.asyncMainSafe { [weak self] in
                        guard let self = self else { return }
                        guard let skincare = self.skincare else { return }
                        guard let dst = SkincareReportViewController.viewController(skincare: skincare, skinFeatures: skincare.availableFeatures, faceImage: self.originalImage) else {
                            return
                        }

                        if isLive {
                            let alert = UIAlertController(title: nil, message: "Do you want to save the captured image for future reference?", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Sure", style: .default, handler: { [weak self] _ in
                                guard let self = self else { return }
                                let imageData = self.originalImage.pngData()
                                let pngImage = UIImage(data: imageData!)
                                UIImageWriteToSavedPhotosAlbum(pngImage!, nil, nil, nil)

                                print("--------<<<--- navigationController", skincare.availableFeatures)
                                self.navigationController?.pushViewController(dst, animated: true)
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
                            self.present(alert, animated: true)
                        } else {
                            self.navigationController?.pushViewController(dst, animated: true)
                        }
                    }
                }
            })
        }
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
                            if let flutterViewController = self.flutterViewController {
                                let channel = FlutterMethodChannel(
                                    name: "skincare_channel",
                                    binaryMessenger: flutterViewController.binaryMessenger
                                )
                                let arguments: [String: Any] = [
                                           "skincareReportDict": self.skincareReportDict,  // Your skincare report dictionary
                                           "skincare": skincare  // The skincare object (ensure it is serializable to Flutter)
                                       ]
                                // Send the dictionary to Flutter
                                channel.invokeMethod("updateSkincareData1", arguments:arguments )
                                self.dismiss(animated: true)
                            } else {
                                print("FlutterViewController is nil")
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Memory warning received!")
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

    @objc private func timerMethod(timer: Timer) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            self.countDownValue -= 1
            if self.countDownValue == 0 {
                self.countDownIndicator.isHidden = true
                self.countDownTimer?.invalidate()
                self.countDownTimer = nil

                self.capture()
            }
        }
    }
}

@available(iOS 10.0, *)
extension SkincareViewController: SkinCareDelegate {
    func skinCare(_ skinCare: SkinCare, checkedResult: PFSkinCareQualityCheck) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self, self.currentState != .capturing else { return }
            self.lightingQuality.backgroundColor = checkedResult.lightingQuality.color
            self.faceFrontalQuality.backgroundColor = checkedResult.faceFrontalQuality.color
            self.faceAreaQuality.backgroundColor = checkedResult.faceAreaQuality.color
            self.lightingQualityMsg.text = checkedResult.lightingQuality.string
            self.faceAreaQualityMsg.text = checkedResult.faceAreaQuality.string

  if let flutterViewController = self.flutterViewController {
                let channel = FlutterMethodChannel(name: "skincare_channel", binaryMessenger: flutterViewController.binaryMessenger)
                let data: [String: Any] = [
                    "lightingQuality": checkedResult.lightingQuality.string,
                    "faceFrontalQuality": checkedResult.faceFrontalQuality.string,
                    "faceAreaQuality": checkedResult.faceAreaQuality.string
                ]
                channel.invokeMethod("updateSkincareData", arguments: data)
            } else {
                print("FlutterViewController is nil")
            }


            if checkedResult.canCapture() {
                if self.currentState == .waitForCountDown {
                    self.startCountingDown()
                }
            }
            else {
                if self.currentState == .countingDown {
                    self.stopCountingDown()
                }
            }
        }
    }
}

@available(iOS 10.0, *)
extension SkincareViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func showCameraAccessDenied() {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Camera Access Denied", message: "Camera access is required. Please enable camera access for the app in Settings -> Privacy -> Camera.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
                self.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func requestCameraAuthentication(_ completion: @escaping (_ authorized: Bool)->Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                completion(authorized)
            }
        }
        else {
            completion(status == .authorized)
        }
    }

    func setupCameraAndPreview() {
        requestCameraAuthentication { [weak self] authorized in
            guard let self = self else { return }
            if authorized {
                SynchronousTool.asyncMainSafe { [ weak self] in
                    guard let self = self else { return }
                    self._setupCameraAndPreview()
                }
            }
            else {
                self.showCameraAccessDenied()
            }
        }
    }

   func _setupCameraAndPreview() {
         let session = AVCaptureSession()

              // Begin camera session configuration
              session.beginConfiguration()

              // Get the back camera device
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
              let queue = DispatchQueue(label: "com.perfectlib.processsamplebuffer")
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

                  // Set video orientation based on device orientation
                  let deviceOrientation = UIDevice.current.orientation
                  if let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) {
                      photoOutput.connection(with: .video)?.videoOrientation = newVideoOrientation
                  }
              } else {
                  fatalError("Cannot add photo output to session")
              }

              // Set session preset
              session.sessionPreset = .high

              // Commit session configuration
              session.commitConfiguration()

              // Set up preview layer for camera feed
              let previewLayer = AVCaptureVideoPreviewLayer(session: session)
              previewLayer.frame = CGRect(origin: .zero, size: self.skincareView.frame.size)
              previewLayer.videoGravity = .resizeAspectFill
              self.skincareView.layer.addSublayer(previewLayer)
              self.previewLayer = previewLayer

              // Start camera session on background thread
              DispatchQueue.global(qos: .background).async {
                  session.startRunning()
              }

              // Save session reference
              self.session = session
   }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        skincare?.sendCameraBuffer(sampleBuffer)
    }
}

@available(iOS 10.0, *)
extension SkincareViewController : AVCapturePhotoCaptureDelegate
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
            analyzeImage(image: rotatedImage, isLive: true)
        }
    }
}

extension SkincareViewController : UIAdaptivePresentationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        self.dismiss(animated: true, completion: nil)

        guard let image = info[UIImagePickerController.InfoKey.originalImage] else { return }

        if let previewImage = image as? UIImage {
            var rotatedImage : UIImage? = nil
            switch previewImage.imageOrientation {
            case .up, .upMirrored:
                rotatedImage = previewImage
            case .left, .leftMirrored:
                rotatedImage = (previewImage.rotate(radians: .pi * 2))!
            case .right, .rightMirrored:
                rotatedImage = (previewImage.rotate(radians: -.pi * 2))!
            default:
                rotatedImage = previewImage
            }

            analyzeImage(image: rotatedImage!, isLive: false)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        session?.startRunning()
        picker.dismiss(animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        session?.startRunning()
    }
}
