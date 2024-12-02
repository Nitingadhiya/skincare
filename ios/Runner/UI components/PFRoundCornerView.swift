//
//  PFRoundCornerView.swift
//  PerfectLibDemo
//
//  Created by PX Chen on 2020/7/7.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

import UIKit

class PFRoundCornerView: UIView {
    
    @IBInspectable var borderColor:UIColor! {
        didSet {
            self.layer.borderColor = self.borderColor.cgColor
        }
    }
    
    @IBInspectable var borderWidth:CGFloat = 0.0 {
        didSet {
            layer.borderWidth = self.borderWidth / min(2.0, UIScreen.main.scale)
        }
    }
    
    @IBInspectable var cornerRadiusBasedOnWidth:Bool = false
    @IBInspectable var cornerRadiusRatio:CGFloat = 0.0
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = (cornerRadiusBasedOnWidth ? bounds.size.width : bounds.size.height) * cornerRadiusRatio
    }
}
