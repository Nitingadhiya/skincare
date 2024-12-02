//
//  SkinEmulationResultViewController.swift
//  SkincareDemo
//
//  Created by Alex Lin on 2022/6/7.
//  Copyright © 2022 Perfect Corp. All rights reserved.
//

import UIKit
import PerfectLibSkinCarePlus

class SkinEmulationResultViewController: UIViewController {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var foreheadSlider: UISlider!
    @IBOutlet weak var aroundEyeSlider: UISlider!
    @IBOutlet weak var lowerFaceSlider: UISlider!
    @IBOutlet weak var darkCircleSlider: UISlider!
    @IBOutlet weak var spotSlider: UISlider!
    @IBOutlet weak var poreSlider: UISlider!
    @IBOutlet weak var textureSlider: UISlider!
    @IBOutlet weak var rednessSlider: UISlider!
    @IBOutlet weak var eyebagSlider: UISlider!
    
    @IBOutlet weak var loadingView: UIView!
    
    fileprivate var faceImage: UIImage?
    fileprivate var skinEmulation: SkinEmulation?
    fileprivate var featuresValue = [String: NSNumber]()
    
    private func correctView(to size: CGSize? = nil) {
        // Set device orientation based on UI
        let height = size?.height ?? UIScreen.main.bounds.height
        let width = size?.width ?? UIScreen.main.bounds.width
        self.scrollView.zoomScale = 1.0
        self.scrollView.contentSize = CGSize(width: width, height: height);
        self.scrollView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.scrollView.center = CGPoint(x: width / 2, y: height / 2)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = faceImage
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        updateFeatureValues()
        correctView()
    }
    
    @available(iOS 13.0, *)
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
        return .none
    }

    public static func viewController(skinemulation: SkinEmulation, faceImage:UIImage) -> SkinEmulationResultViewController? {
        let dst = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SkinEmulationResultViewController") as? SkinEmulationResultViewController
        dst?.skinEmulation = skinemulation
        dst?.faceImage = faceImage
        return dst
    }
    
    private func updateFeatureValues() {
        guard let features = skinEmulation?.availableFeatures else { return }
        
        features.forEach { feature in
            if feature == "wrinkleForehead" {
                foreheadSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(foreheadSlider.value)) as NSNumber?
            } else if feature == "wrinkleAroundEyes" {
                aroundEyeSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(aroundEyeSlider.value)) as NSNumber?
            } else if feature == "wrinkleLowerFace" {
                lowerFaceSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(lowerFaceSlider.value)) as NSNumber?
            } else if feature == "darkCircle" {
                darkCircleSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(darkCircleSlider.value)) as NSNumber?
            } else if feature == "spot" {
                spotSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(spotSlider.value)) as NSNumber?
            } else if feature == "pore" {
                poreSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(poreSlider.value)) as NSNumber?
            } else if feature == "texture" {
                textureSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(textureSlider.value)) as NSNumber?
            } else if feature == "redness" {
                rednessSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(rednessSlider.value)) as NSNumber?
            } else if feature == "eyebag" {
                eyebagSlider.superview?.isHidden = false
                featuresValue[feature] = Int(round(eyebagSlider.value)) as NSNumber?
            }
        }
    }
    
    @IBAction func actionBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func actionGetEmulation(_ sender: Any) {
        loadingView.isHidden = false
        updateFeatureValues()
        skinEmulation?.getImage(featuresValue, completion: { [weak self] image, error in
            SynchronousTool.asyncMainSafe {
                guard let self = self else { return }
                self.loadingView.isHidden = true
                if let image = image {
                    self.imageView.image = image
                }
                else if let error = error {
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        })
    }
}

extension SkinEmulationResultViewController : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
