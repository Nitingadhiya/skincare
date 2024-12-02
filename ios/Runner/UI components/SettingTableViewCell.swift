//
//  SettingTableViewCell.swift
//  PerfectLibDemo
//
//  Created by Alex Lin on 2019/5/15.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit

class SettingCellTypeInput: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
}

class SettingCellTypeSwitch: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueSwitch: UISwitch!
    
    @IBAction func actionSwitched(_ sender: Any) {
    }
}
