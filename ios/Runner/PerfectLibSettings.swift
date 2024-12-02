//
//  PerfectLibSettings.swift
//  Runner
//
//  Created by nitinrgadhiya on 26/11/24.
//

import Foundation
import UIKit
import PerfectLibCore

class PerfectLibSettings: NSObject {
    private static let cacheStrategy = "USERDEFAULT_CACHE_STRATEGY"
    private static let imageSourceUserDefault = "USERDEFAULT_IMAGE_SOURCE"
    private static let configFileUserDefault = "configFileUserDefault"
    
    static let shared: PerfectLibSettings = PerfectLibSettings()
    
    public var configFile: String? {
        get {
            UserDefaults.standard.string(forKey: Self.configFileUserDefault)
        }
        set(value) {
            if let value = value {
                UserDefaults.standard.set(value, forKey: Self.configFileUserDefault)
            }
            else {
                UserDefaults.standard.removeObject(forKey: Self.configFileUserDefault)
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    public var cacheStrategy: Int {
        get {
            return Int(PerfectLib.getDownloadCacheStrategy().rawValue)
        }
        set(value) {
            PerfectLib.setDownloadCacheStrategy(PFDownloadCacheStrategy(rawValue: PFDownloadCacheStrategy.RawValue(value)) ?? .cacheFirst)
        }
    }
    
    public var cacheStrategyE: PFDownloadCacheStrategy {
        get {
            return PFDownloadCacheStrategy(rawValue: UInt(cacheStrategy)) ?? .cacheFirst
        }
    }
    
    public var imageSource: Int {
        get {
            return UserDefaults.standard.integer(forKey: PerfectLibSettings.imageSourceUserDefault)
        }
        set(value) {
            UserDefaults.standard.set(value, forKey: PerfectLibSettings.imageSourceUserDefault)
            UserDefaults.standard.synchronize()
        }
    }
    
    public var maxCacheSize: UInt {
        get {
            return PerfectLib.getMaxCacheSize()
        }
        set(value) {
            PerfectLib.setMaxCacheSize(value)
        }
    }
}
