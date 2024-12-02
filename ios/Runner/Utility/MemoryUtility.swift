//
//  MemoryUtility.swift
//  PerfectLibDemo
//
//  Created by I Lin on 2020/4/16.
//  Copyright © 2020 Perfect Corp. All rights reserved.
//

import Foundation
import UIKit
struct MemoryUtility {
    private static var memoryLabel : UILabel?
    private static var getFrameInfoTimer : Timer?
    
    private static func getMemory(_ s: String? = "") -> String? {
        
        let TASK_VM_INFO_COUNT = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size

        var vmInfo = task_vm_info_data_t()
        var vmInfoSize = mach_msg_type_number_t(TASK_VM_INFO_COUNT)

        let kern: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                              task_flavor_t(TASK_VM_INFO),
                              $0,
                              &vmInfoSize)
                    }
                }

        if kern == KERN_SUCCESS {
            let usedSize = Double(vmInfo.phys_footprint) / (1024.0*1024.0)
            let roundedSize = String(format: "%.1f", usedSize)
            return roundedSize
        } else {
            let errorString = String(cString: mach_error_string(kern), encoding: .ascii) ?? "unknown error"
            print("Error with task_info(): \(errorString)")
            return nil
        }
        
    }
    
    static func displayMemoryUsage() {
        if UserDefaults.standard.bool(forKey: "enableDisplayMemoryUsage") {
            if memoryLabel == nil {
                getFrameInfoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                    DispatchQueue.main.async {
                        memoryLabel?.text = "\(getMemory() ?? "0.0") MB"
                    }
                })
                memoryLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 100, y: 140, width: 80, height: 35))
                memoryLabel?.text = "0.0 MB"
                memoryLabel?.textAlignment = .center
                memoryLabel?.backgroundColor = .lightText
                memoryLabel?.font = UIFont.systemFont(ofSize: 14.0)
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.window?.addSubview(memoryLabel!)
                }
            }
        } else {
            getFrameInfoTimer?.invalidate()
            if memoryLabel != nil {
                memoryLabel?.removeFromSuperview()
            }
            memoryLabel = nil
        }
    }
}
