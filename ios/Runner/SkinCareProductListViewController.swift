//
//  SkinCareProductListViewController.swift
//  PerfectLibDemo
//
//  Created by Alex Lin on 2019/5/17.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit
import PerfectLibCore
import PerfectLibRecommendationHandler

class ProductCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var productIDLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    var product: SkinCareProduct? {
        didSet {
            guard let product = product else { return }
            if let imageURL = product.imageUrl, let url = URL(string: imageURL) {
                imageView.setImageUrl(url)
            }
            else {
                imageView.image = nil
            }
            nameLabel.text = product.productName
            brandLabel.text = product.brandName
            let productId = product.productId
            productIDLabel.text = productId
            typeLabel.text = product.skuType
        }
    }
    
    var inventory: Inventory? {
        didSet {
            guard let quantity = inventory?.quantity else { return }
            quantityLabel.text = "Quantity: \(String(describing: quantity.stringValue))"
        }
    }
}

class ProductHeader: UICollectionReusableView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var productIDLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var expandIcon: UIImageView!
    @IBOutlet weak var customerInfoButton: UIButton!
    var product: SkinCareProduct? {
        didSet {
            guard let product = product else { return }
            if let imageURL = product.imageUrl {
                imageView.setImage(url: imageURL)
            }
            else {
                imageView.image = nil
            }
            nameLabel.text = product.productName
            brandLabel.text = product.brandName
            productIDLabel.text = product.productId
            typeLabel.text = product.skuType
        }
    }
    
    var inventory: Inventory? {
        didSet {
            guard let quantity = inventory?.quantity else { return }
            quantityLabel.text = "Quantity: \(String(describing: quantity.stringValue))"
        }
    }
}

class SkinCareProductListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mappingModeSwitch: UISwitch!
    @IBOutlet weak var extraInfoButton: UIButton!
    var sectionExpended: [Int:Bool] = [:]
    
    var skinCareProducts: [SkinCareProduct]? {
        didSet {
            if collectionView == nil {
                return
            }
            collectionView.reloadData()
        }
    }
    
    var inventories: [Inventory]?
    
    var extraInfo: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        mappingModeSwitch.isOn = UserDefaults.standard.bool(forKey: "isMappingMode")
        extraInfoButton.isHidden = extraInfo == nil
    }

    @IBAction func actionBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func actionHeaderTapped(_ sender: Any) {
        guard let view = sender as? UIView else { return }
        guard let header = view.superview as? ProductHeader else { return }
        let expanded = sectionExpended[header.tag] ?? false
        sectionExpended[header.tag] = !expanded
        collectionView.performBatchUpdates({ [weak self] in
            guard let self = self else { return }
            self.collectionView.reloadSections(IndexSet(integer: header.tag))
        }) { (_) in
            
        }
    }
    
    @IBAction func actionShowCustomerInfo(_ sender: Any) {
        guard let view = sender as? UIView else { return }
        guard let header = view.superview as? ProductHeader else { return }
        
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            guard let product = self.skinCareProducts?[header.tag] else { return }
            let customerInfo = product.customerInfo?.toJSON()
            if let productId = product.productId, customerInfo != nil {
                let alert = UIAlertController(title: "ProductID : \(productId)", message: product.customerInfo?.prettyPrint(), preferredStyle: .alert)
                
                let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = NSTextAlignment.left
                let messageText = NSMutableAttributedString(
                    string: (product.customerInfo?.prettyPrint())!,
                    attributes: [
                        NSAttributedString.Key.paragraphStyle: paragraphStyle,
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10.0)
                    ]
                )
                alert.setValue(messageText, forKey: "attributedMessage")
                
                alert.addAction(UIAlertAction(title: "Copy Customer Info", style: .default, handler: { _ in
                    UIPasteboard.general.string = product.customerInfo?.prettyPrint()
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func actionShowExtraInfo(_ sender: Any) {
        SynchronousTool.asyncMainSafe { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Extra Info", message: self.extraInfo?.prettyPrint(), preferredStyle: .alert)
            
            let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = NSTextAlignment.left
            let messageText = NSMutableAttributedString(
                string: (self.extraInfo?.prettyPrint())!,
                attributes: [
                    NSAttributedString.Key.paragraphStyle: paragraphStyle,
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10.0)
                ]
            )
            alert.setValue(messageText, forKey: "attributedMessage")
            
            alert.addAction(UIAlertAction(title: "Copy Extra Info", style: .default, handler: { _ in
                UIPasteboard.general.string = self.extraInfo?.prettyPrint()
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard let skinCareProducts = skinCareProducts else { return 0 }
        return skinCareProducts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let expanded = sectionExpended[section] ?? false
        if !expanded {
            return 0
        }
        guard let skinCareProducts = skinCareProducts else { return 0 }
        let product = skinCareProducts[section]
        guard let products = product.products else { return 0 }
        return products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductCell
        guard let skinCareProducts = skinCareProducts else { return cell }
        let product = skinCareProducts[indexPath.section]
        guard let products = product.products else { return cell }
        cell.product = products[indexPath.row]
        let customerInfo = products[indexPath.row].customerInfo?.toJSON()
        if let defaultSkuId = (customerInfo as? Dictionary<String, Any>)?["defaultSkuId"] {
            cell.inventory = inventories?.first(where: {$0.inventoryId! == defaultSkuId as! String})
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ProductHeader", for: indexPath) as! ProductHeader
            guard let skinCareProducts = skinCareProducts else { return header }
            let product = skinCareProducts[indexPath.section]
            header.product = product
            header.customerInfoButton.titleLabel?.minimumScaleFactor = 0.5
            header.customerInfoButton.titleLabel?.adjustsFontSizeToFitWidth = true
            header.customerInfoButton.isHidden = true
            header.quantityLabel.isHidden = true
            let customerInfo = product.customerInfo?.toJSON()
            if let defaultSkuId = (customerInfo as? Dictionary<String, Any>)?["defaultSkuId"] {
                header.inventory = inventories?.first(where: {$0.inventoryId! == defaultSkuId as! String})
                header.customerInfoButton.isHidden = customerInfo == nil
                header.quantityLabel.isHidden = header.inventory == nil
            }
            header.tag = indexPath.section
            let count = (product.products == nil) ? 0 : product.products?.count
            header.expandIcon.isHidden = count == 0
            let expanded = sectionExpended[indexPath.section] ?? false
            header.expandIcon.transform = expanded ? CGAffineTransform.init(rotationAngle: CGFloat(Double.pi)) : CGAffineTransform.identity
            return header
        }
        return UICollectionReusableView(frame: CGRect.zero)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.size.width, height: 80)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.size.width, height: 120)
    }
}
