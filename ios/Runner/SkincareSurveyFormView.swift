//
//  SkincareSurveyFormView.swift
//  PerfectLibDemo
//
//  Created by PX Chen on 2020/5/20.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

import Foundation
import UIKit
import PerfectLibCore
import PerfectLibRecommendationHandler

class SkincareSurveyQuestionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel:UILabel!
    @IBOutlet weak var stackView:UIStackView!
    var optionsChanged: ((_ options:[SkinCareSurveyFormOption]) -> Void)?

    var question:SkinCareSurveyFormQuestion? {
        didSet {
            optionButtons.forEach { $0.removeFromSuperview() }
            optionButtons.removeAll()
            
            if let question = question, let title = question.title.stripOutHtml(), let desc = question.detailDescription.stripOutHtml() {
                titleLabel.text = title + " (" + desc.trimmingCharacters(in: .newlines) + ")"
            }
                        
            question?.options.forEach {
                let button = UIButton()
                button.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                button.setTitle($0.title.stripOutHtml(), for: .normal)
                button.addTarget(self, action: #selector(self.pressed(sender:)), for: .touchUpInside)
                button.setTitleColor(.red, for: .selected)
                stackView.addArrangedSubview(button)
                optionButtons.append(button)
            }
            if let question = question {
                isMultipleChoice = question.type == .multipleChoice
            }
        }
    }
    var isMultipleChoice = false
    var optionButtons:[UIButton] = []
    var selectedOptions: [SkinCareSurveyFormOption]? {
        didSet {
            for (index, element) in question!.options.enumerated() {
                if let _ = selectedOptions?.first(where: { (option) -> Bool in
                    option.optionId == element.optionId
                }) {
                    optionButtons[index].isSelected = true
                }
            }
        }
    }
    
    @objc func pressed(sender: UIButton!) {
        sender.isSelected.toggle()
        
        if isMultipleChoice {
            optionButtons.forEach { if $0 != sender {
                $0.isSelected = false
            }}
        }
        let selectedAry = optionButtons.map { (button) -> Bool in button.isSelected }
        var newOptions:[SkinCareSurveyFormOption] = []
        
        for (index, element) in question!.options.enumerated() {
            if selectedAry[index] {
                newOptions.append(element)
            }
        }
        optionsChanged?(newOptions)
    }
}

class SkincareSurveyFormView: UIViewController {
    
    var completion: ((_ options:[String]) -> Void)?
    var form:SkinCareSurveyForm?
    var currOptions:[Int:[SkinCareSurveyFormOption]] = [:]
    var currentIndex = 0 {
        didSet {
            prevButton.isEnabled = currentIndex != 0
            
            if currentIndex + 1 == form?.questions.count {
                nextButton.setTitle(form?.doneButtonText, for: .normal)
            } else {
                nextButton.setTitle(form?.nextButtonText, for: .normal)
            }
        }
    }
    @IBOutlet weak var collectionView:UICollectionView!
    @IBOutlet weak var titleLabel:UILabel!
    @IBOutlet weak var nextButton:UIButton!
    @IBOutlet weak var prevButton:UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = form?.title
        nextButton.setTitle(form?.nextButtonText, for: .normal)
        prevButton.setTitle(form?.previousButtonText, for: .normal)
        collectionView.reloadData()
    }
}

extension SkincareSurveyFormView {
    
    @IBAction func actionNext(_ uibutton:UIButton) {
        if currentIndex + 1 == form?.questions.count {
            let selectedIds = currOptions.map { (key,value) -> [SkinCareSurveyFormOption] in
                value
            }.flatMap { (options) -> [SkinCareSurveyFormOption] in
                options
            }.map { (option) -> String in
                option.optionId
            }
            completion?(selectedIds)
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        currentIndex += 1
        collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    @IBAction func actiionPrev(_ uibutton:UIButton) {
        currentIndex -= 1
        collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
    }
    
}

extension SkincareSurveyFormView : UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        form?.questions.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SkincareSurveyQuestionViewCell", for: indexPath) as? SkincareSurveyQuestionViewCell, let form = form {
            
            let question = form.questions[indexPath.row]
            cell.question = question
            cell.selectedOptions = currOptions[indexPath.row]
            cell.optionsChanged = { [weak self] (value) -> Void in
                self?.currOptions[indexPath.row] = value
                self?.nextButton.isEnabled = value.count != 0 || !question.isRequired
            }
            return cell
        } else {
            return UICollectionViewCell.init()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.frame.size
    }
}

extension String {

    func stripOutHtml() -> String? {
        do {
            guard let data = self.data(using: .unicode) else {
                return nil
            }
            let attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
            return attributed.string
        } catch {
            return nil
        }
    }
}
