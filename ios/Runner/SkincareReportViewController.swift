//
//  SkincareReportViewController.swift
//  Runner
//
//  Created by nitinrgadhiya on 28/11/24.
//

import Foundation
//
//  SkincareV2ReportViewController.swift
//  PerfectLibDemo
//
//  Created by alex lin on 2019/10/17.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit
import PerfectLibCore
import PerfectLibSkinCarePlus
import PerfectLibRecommendationHandler

enum SkinTypeFeature : String, CaseIterable {
    case FullFace = "FullFace"
    case TZone = "T-Zone"
    case UZone = "U-Zone"
    
    var name : String {
        switch self {
        case .FullFace:
            return "Full Face"
        case .TZone:
            return "T Zone"
        case .UZone:
            return "U Zone"
        }
    }
}

class RoundScoreCellView: UICollectionViewCell {
    @IBOutlet weak var featureNameLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var roundCornerView: PFRoundCornerView!

    public var featureSelected: Bool = false {
        didSet {
            self.roundCornerView.backgroundColor = featureSelected ? #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 0.4198668574) : #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
}

class RoundScoreView: UIView {
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var roundCornerView: PFRoundCornerView!
    
    public var selected: Bool = false {
        didSet {
            self.roundCornerView.backgroundColor = selected ? #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 0.4198668574) : #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
    
    public var score: Int32 = 0 {
        didSet {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                self.scoreLabel.text = String(format: "%d", self.score)
            }
        }
    }
}

class SkincareReportViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var loadingView: UIView!
    
    @IBOutlet weak var skinAgeScoreView: RoundScoreView!
    @IBOutlet weak var overallScoreView: RoundScoreView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var skinTypeOverAllLabel: UILabel!
    @IBOutlet weak var skinTypeTZoneLabel: UILabel!
    @IBOutlet weak var skinTypeUZoneLabel: UILabel!
    @IBOutlet weak var skinTypeButton: UIButton!
    @IBOutlet weak var skinTypeView: PFRoundCornerView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var surveyFormButton:UIButton!
    @IBOutlet weak var recommendProductsButton: UIButton!
    @IBOutlet weak var emulationButton: UIButton!
    
    var lastAnswer: SurveyAnswer?
    
    @IBOutlet var scoreViews: [RoundScoreView]!
    
    private var skinCare: SkinCare?
    private var skinFeatures: [String]?
    private var faceImage: UIImage?
    
    private var skinTypeReports: [PFSkinTypeAnalysisData]? {
        didSet {
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                
                for report in self.skinTypeReports! {
                    if let reportFeature = SkinTypeFeature(rawValue: report.feature) {
                        print("-----reports ------",reportFeature)
                        switch reportFeature {
                        case .FullFace:
                            self.skinTypeOverAllLabel.text = "\(reportFeature.name): \(String(describing: report.skinType.string)) Skin"
                        case .TZone:
                            self.skinTypeTZoneLabel.text = "\(reportFeature.name): \(String(describing: report.skinType.string)) Skin"
                        case .UZone:
                            self.skinTypeUZoneLabel.text = "\(reportFeature.name): \(String(describing: report.skinType.string)) Skin"
                        }
                    }
                }
            }
        }
    }
        
    private var skincareReports: [PFSkinAnalysisData]?
    
    private var skincareReportDict: [String:Int]?
    
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
        getSkincareReport()
        correctView()
        if let surveyId = UserDefaults.standard.string(forKey: "skincareSurveyId"), let settingId = UserDefaults.standard.string(forKey: "skincareSettingId"), surveyId.count > 0, settingId.count > 0 {
            recommendProductsButton.isEnabled = false
            recommendProductsButton.alpha = 0.5
        }
        else if let settingId = UserDefaults.standard.string(forKey: "skincareSettingId"), settingId.count > 0 {
            recommendProductsButton.isEnabled = true
            surveyFormButton.isHidden = true
        }
        else {
            surveyFormButton.isHidden = true
            recommendProductsButton.isHidden = true
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        correctView(to: size)
    }
    
    public static func viewController(skincare: SkinCare, skinFeatures:[String], faceImage:UIImage) -> SkincareReportViewController? {
        let dst = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SkincareReportViewController") as? SkincareReportViewController
        dst?.skinCare = skincare
        dst?.skinFeatures = skinFeatures
        dst?.faceImage = faceImage
        return dst
    }
    
    private func updateSelectedFeatures(_ feature:String, isAdd:Bool) {
        if isAdd {
            selectedSkinFeatures.append(feature)
        } else {
            if let index = selectedSkinFeatures.firstIndex(where: { (variable) -> Bool in variable == feature }) {
                selectedSkinFeatures.remove(at: index)
            }
        }
    }
    
    // MARK: - actions
    var selectedSkinFeatures: [String] = []
    @IBAction func actionSkinType(_ sender: UIButton) {
        skinTypeButton.isSelected.toggle()
        let selected = skinTypeButton.isSelected
        
        if selected {
            skinCare?.getSkinTypeAnalyzedImage({ (image, error) in
                SynchronousTool.asyncMainSafe { [weak self] in
                    self?.imageView.image = image
                }
            })
        } else {
            updateImage()
        }
        skinTypeView.backgroundColor = selected ? #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 0.4198668574) : #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        
        updateOverallScore()
        updateSkinTypeResult()
    }
    
    
    @IBAction func actionBack(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - private functions
    private func getSkincareReport() {
        doLongOperation { [weak self] (completion) in
            guard let self = self else { return }
            guard let skincare = self.skinCare, let features = self.skinFeatures else { return }
            DispatchQueue.global().async {
                let group = DispatchGroup()
                group.enter()
                skincare.getReports(bySkinFeatures: features) { [weak self] (reports) in
                    self?.skincareReports = reports
                    print("report-----",reports)
                    self?.skincareReportDict = reports.reduce([String:Int](), { partialResult, data in
                        var result = partialResult
                        result[data.feature] = Int(data.score)
                        return result
                    })
                    SynchronousTool.asyncMainSafe {
                        self?.collectionView.reloadData()
                    }
                    self?.updateSkinTypeResult()
                    self?.updateOverallScore()
                    group.leave()
                }
                group.wait()
                completion()
            }
        }
    }
    
    private func doLongOperation(closure: @escaping (@escaping ()->Void)->Void) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            self.loadingView.isHidden = false
            closure({
                SynchronousTool.asyncMainSafe {
                    self.loadingView.isHidden = true
                }
            })
        }
    }
    
    private func updateImage() {
        skinCare?.getAnalyzedImage(bySkinFeatures: selectedSkinFeatures, completion: { (image, error) in
            if let image = image {
                SynchronousTool.asyncMainSafe { [weak self] in
                    guard let self = self else { return }
                    print("-----image ----",image)
                    self.imageView.image = image
                }
            }
            if let error = error {
                let alert = UIAlertController(title: "Get Analyzed Image Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        })
    }
    
    private func updateSkinTypeResult() {
        guard let skincare = skinCare else {
            return
        }
        
        skincare.getSkinTypes() {[weak self] (reports) in
            if reports.isEmpty {
                return
            }
            
            SynchronousTool.asyncMainSafe { [weak self] in
                self?.skinTypeOverAllLabel.isHidden = false
                self?.skinTypeTZoneLabel.isHidden = false
                self?.skinTypeUZoneLabel.isHidden = false
                self?.skinTypeView.isHidden = false
            }
            
            self?.skinTypeReports = reports
        }
    }
    
    private func updateOverallScore() {
        guard let skincare = skinCare else {
            overallScoreView.score = 0
            skinAgeScoreView.score = 0
            return
        }
        skincare.getOverallScore { [weak self] (score, age) in
            self?.overallScoreView.score = score
            self?.skinAgeScoreView.score = age
        }
    }
    
    @IBAction func actionSurveyForm(_ sender: UIButton) {
        surveyFormButton.isEnabled = false
        
        RecommendationHandler.sharedInstance().getSurveyForm(.skinCare, successBlock: { [weak self] (form) in
            DispatchQueue.main.async { [weak self] in
                let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
                if let dst = storyboard.instantiateViewController(withIdentifier: "SkincareSurveyFormView") as? SkincareSurveyFormView {
                    dst.form = form as? SkinCareSurveyForm
                    dst.completion = { [weak self] (options) -> Void in
                        self?.lastAnswer = SurveyAnswer(result: options)
                        self?.surveyFormButton.isEnabled = true
                        self?.recommendProductsButton.isEnabled = true
                        self?.recommendProductsButton.alpha = 1
                    }
                    self?.navigationController?.pushViewController(dst, animated: true);
                }
            }
        }) { (err) in

        }
    }
    
    @IBAction func actionRecommendProducts(_ sender: Any) {
        guard let reports = skincareReports else {
            return;
        }
        
        let data = SkinCareRecommendationData(skinAnalysisData: reports, skinAge: skinAgeScoreView.score, overallScore: overallScoreView.score, andSurveyAnswer: lastAnswer)
        RecommendationHandler.sharedInstance().getRecommendedResult(.skinCare, data: data, successBlock: { [weak self] (recommendationResult) in
            self?.recommendProductsButton.isEnabled = false
            self?.recommendProductsButton.alpha = 0.5
            let products = (recommendationResult as? SkinCareRecommendationResult)?.products
            let extraInfo = (recommendationResult as? SkinCareRecommendationResult)?.extraInfo
            SynchronousTool.asyncMainSafe { [weak self] in
                guard let self = self else { return }
                if let products = products, products.count > 0 {
                    guard let dst = self.storyboard?.instantiateViewController(withIdentifier: "SkinCareProductListViewController") as? SkinCareProductListViewController else { return }
                    let customerInfos = products.compactMap{($0.customerInfo?.toJSON())}
                    SkinCareProduct.getInventory(customerInfos.compactMap{($0 as! Dictionary<String, Any>)["defaultSkuId"]}) { inventories, error in
                        if (error == nil) {
                            dst.inventories = inventories
                        }
                        if let extraInfo = extraInfo, !extraInfo.isEmpty {
                            dst.extraInfo = extraInfo
                        }
                        dst.skinCareProducts = products
                        SynchronousTool.asyncMainSafe { [weak self] in
                            guard let self = self else { return }
                            self.navigationController?.pushViewController(dst, animated: true)
                        }
                    }
                }
                else {
                    let alert = UIAlertController(title: nil, message: "No recommended product found.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                self.recommendProductsButton.isEnabled = true
                self.recommendProductsButton.alpha = 1
            }
        }) { [weak self] (error) in
            let alert = UIAlertController(title: "Error", message: "There is no recommendation data available!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .destructive, handler: { (_) in

            }))
            self?.present(alert, animated: true, completion: nil)
        }
    }
}

extension SkincareReportViewController : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}

extension SkincareReportViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        skinFeatures?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RoundScoreCellView", for: indexPath) as! RoundScoreCellView
       let feature = skinFeatures?[indexPath.row] ?? ""
        var editedFeatureName = feature
        // Change to common feature name
        ["sag_","common_"].forEach {
            editedFeatureName = editedFeatureName.replacingOccurrences(of: $0, with: "")
        }

        cell.featureNameLabel.text = editedFeatureName
        cell.featureSelected = selectedSkinFeatures.contains(feature)
        cell.isSelected.toggle()
        if let score = skincareReportDict?[feature] {
            cell.scoreLabel.text = "\(score)"
        }
        else {
            cell.scoreLabel.text = "--"
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let feature = skinFeatures?[indexPath.row] else { return }
        if let selectedIndex = selectedSkinFeatures.firstIndex(of: feature) {
            selectedSkinFeatures.remove(at: selectedIndex)
        }
        else {
            selectedSkinFeatures.append(feature)
        }
        collectionView.reloadData()
        if skinTypeButton.isSelected {
            actionSkinType(skinTypeButton)
        }
        updateImage()
    }
}

extension PFSkinType {
    var string: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .normal:
            return "Normal"
        case .dry:
            return "Dry"
        case .oily:
            return "Oily"
        case .combination:
            return "Combination"
        case .normalAndSensitive:
            return "Normal and Sensitive"
        case .dryAndSensitive:
            return "Dry and Sensitive"
        case .oilyAndSensitive:
            return "Oily and Sensitive"
        case .combinationAndSensitive:
            return "Combination and Sensitive"
        default:
            return ""
        }
    }
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
    
    func prettyPrint() -> String? {
        let json = self.toJSON()
        let jsonData = try? JSONSerialization.data(withJSONObject: json as Any, options: .prettyPrinted)
        return String(decoding: jsonData!, as: UTF8.self)

    }
}

