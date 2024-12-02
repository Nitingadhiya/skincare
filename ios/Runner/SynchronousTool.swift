//
//  SynchronousTool.swift
//  Runner
//
//  Created by nitinrgadhiya on 26/11/24.
//

import Foundation
import UIKit

class SynchronousTool {
    static func synced(_ lock: Any, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    static func asyncMainSafe(closure: @escaping () -> ()) {
        if Thread.isMainThread {
            closure()
        }
        else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
}
