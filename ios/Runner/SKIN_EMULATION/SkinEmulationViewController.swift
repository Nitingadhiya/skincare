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

@available(iOS 10.0, *)
class SkinEmulationViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    @IBOutlet weak var skinemulationView: UIView!
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

    enum State {
        case suspend
        case waitForCountDown
        case countingDown
        case capturing
    }

    private let wrapper = PerfectLibWrapper()
    private var skinemulation: SkinEmulation?
    
    private var currentState: State = .suspend
    private var countDownTimer: Timer?
    private var faceImageKeeper: [PerfectLibFaceSide:UIImage] = [:]
    private var session: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var hasSetCamera = false
    private var skinFeatures:[String]?
    private var originalImage:UIImage!
    
    private func correctView(to size: CGSize? = nil) {
        // Set device orientation based on UI
        let height = size?.height ?? UIScreen.main.bounds.height
        let width = size?.width ?? UIScreen.main.bounds.width
        
        self.skinemulationView.center = CGPoint(x: width / 2, y: height / 2)
        
        switch currentDeviceOrientation() {
        case .portrait:
            self.skinemulationView.transform = .identity
        case .portraitUpsideDown:
            self.skinemulationView.transform = CGAffineTransform(rotationAngle: .pi)
        case .landscapeLeft:
            self.skinemulationView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        case .landscapeRight:
            self.skinemulationView.transform = CGAffineTransform(rotationAngle: .pi / 2)
        default:
            self.skinemulationView.transform = .identity
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
                self.skinemulationView.bounds = frame
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        wrapper.waitLibInit(self) { [weak self] in
            guard let self = self else { return }
            SkinEmulation.create() { [weak self] (skinemulation, error) in
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
                self?.skinemulation = skinemulation
                self?.skinemulation?.delegate = self
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
        skinemulation = nil
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
            setting.flashMode = .off
            photoOutput.capturePhoto(with: setting, delegate: self)
        }
    }
    
    private func analyzeImage(image: UIImage) {
        if let skinemulation = skinemulation {
            originalImage = image
            skinemulation.setImage(originalImage, completion: { [weak self] (error) in
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
                        guard let skinemulation = self.skinemulation else { return }
                        guard let faceImage = self.originalImage, let dst = SkinEmulationResultViewController.viewController(skinemulation: skinemulation, faceImage: faceImage) else {
                            return
                        }

                        self.navigationController?.pushViewController(dst, animated: true)
                    }
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
extension SkinEmulationViewController: SkinEmulationDelegate {
    func skinEmulation(_ skinEmulation: SkinEmulation, checkedResult: PFSkinCareQualityCheck) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self, self.currentState != .capturing else { return }
            self.lightingQuality.backgroundColor = checkedResult.lightingQuality.color
            self.faceFrontalQuality.backgroundColor = checkedResult.faceFrontalQuality.color
            self.faceAreaQuality.backgroundColor = checkedResult.faceAreaQuality.color
            self.lightingQualityMsg.text = checkedResult.lightingQuality.string
            self.faceAreaQualityMsg.text = checkedResult.faceAreaQuality.string

            
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
extension SkinEmulationViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
        guard let input = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { fatalError() }
        let session = AVCaptureSession()
        
        session.beginConfiguration()
        guard let deviceInput = try? AVCaptureDeviceInput(device: input) else { fatalError() }
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = false
        
        let queue = DispatchQueue(label: "com.perfectlib.processsamplebuffer")
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            self.photoOutput = photoOutput
            photoOutput.isHighResolutionCaptureEnabled = true
            
            let deviceOrientation = UIDevice.current.orientation
            if let photoOutputConnection = photoOutput.connection(with: .video), let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
                photoOutputConnection.videoOrientation = newVideoOrientation
            }
        }
        
        session.sessionPreset = currentPreset!
        
        session.commitConfiguration()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(origin: CGPoint.zero, size: self.skinemulationView.frame.size)
        previewLayer.videoGravity = .resizeAspectFill
        skinemulationView.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
        
        self.session = session
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        skinemulation?.sendCameraBuffer(sampleBuffer)
    }
}

@available(iOS 10.0, *)
extension SkinEmulationViewController : AVCapturePhotoCaptureDelegate
{
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        if let previewImage = UIImage(data: imageData) {
            var rotatedImage : UIImage;
            switch currentDeviceOrientation() {
            case .portrait:
                rotatedImage = (previewImage.rotate(radians: .pi * 2))!
            case .landscapeLeft:
                rotatedImage = (previewImage.rotate(radians: -.pi * 1.5))!
            case .landscapeRight:
                rotatedImage = previewImage
            default:
                rotatedImage = (previewImage.rotate(radians: .pi * 2))!
            }
            
            let image = rotatedImage.flipImage()!
            
            analyzeImage(image: image)
        }
        
    }
}

extension SkinEmulationViewController : UIAdaptivePresentationControllerDelegate {
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
            
            analyzeImage(image: rotatedImage!)
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
