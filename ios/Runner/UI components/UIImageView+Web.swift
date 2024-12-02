//
//  UIImageView+Web.swift
//  PerfectLibDemo
//
//  Created by Alex Lin on 2019/5/9.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

import UIKit
import Foundation

class WebImageManager {
    var url2ImageView: Dictionary<URL, Array<UIImageView>> = Dictionary.init()
    var downloadingUrls: Array<URL> = Array.init()
    var imageCache: Dictionary<URL, UIImage> = Dictionary.init()
    
    static let sharedManager = WebImageManager()
    
    func uiImageView(_ imageView: UIImageView, downloadingFromUrl url: URL) {
        var alreadyDownloading = false
        SynchronousTool.synced(self) {
            var imageFromCache: UIImage? = imageCache[url]
            if imageFromCache == nil {
                imageFromCache = imageFromDiscCacheFor(url: url)
            }
            if imageFromCache != nil {
                SynchronousTool.asyncMainSafe {
                    imageView.image = imageFromCache
                }
                return
            }
            
            var array = self.url2ImageView[url]
            if array == nil {
                array = Array<UIImageView>.init()
            }
            array?.append(imageView)
            self.url2ImageView[url] = array
            if self.downloadingUrls.contains(url) {
                alreadyDownloading = true
            }
        }
        
        if !alreadyDownloading {
            download(url)
        }
    }
    
    func download(_ url:URL)  {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            SynchronousTool.synced(self) {
                self.downloadingUrls.append(url)
            }
            do {
                let data = try Data(contentsOf: url)
                let image = UIImage(data: data)
                
                if let filePath = self.filePathFrom(url) {
                    do {
                        try data.write(to: URL(fileURLWithPath: filePath))
                    }
                    catch {
                        print(error)
                    }
                }

                SynchronousTool.synced(self) {
                    self.imageCache[url] = image
                    guard let imageViews = self.url2ImageView[url] else { return }
                    for imageView in imageViews {
                        SynchronousTool.asyncMainSafe {
                            imageView.image = image
                        }
                    }
                    self.url2ImageView.removeValue(forKey: url)
                }
            }
            catch {
                print(error)
            }
            SynchronousTool.synced(self) {
                if let i = self.downloadingUrls.firstIndex(of: url) {
                    self.downloadingUrls.remove(at: i)
                }
            }
        }
    }
    
    func imageFromDiscCacheFor(url: URL) -> UIImage? {
        guard let filePath = filePathFrom(url) else { return nil }
        
        if FileManager.default.fileExists(atPath: filePath) {
            let image = UIImage(contentsOfFile: filePath)
            if image != nil {
                imageCache[url] = image
                return image
            }
        }
        return nil
    }
    
    func filePathFrom(_ url: URL) -> String? {
        let urlString = url.absoluteString
        let md5 = urlString.md5()
        let ext = url.pathExtension
        
        var filePath = URL(string: NSTemporaryDirectory())
        filePath = filePath?.appendingPathComponent(md5)
        filePath?.appendPathExtension(ext)
        
        return filePath?.absoluteString
    }
}

extension UIImageView {
    func setImageUrl(_ url: URL) {
        self.image = nil
        WebImageManager.sharedManager.uiImageView(self, downloadingFromUrl: url)
    }
    
    func setImage(url imageUrl: String?) {
        guard let imageUrl = imageUrl else {
            image = nil
            return
        }
        if imageUrl.hasPrefix("http"), let url = URL(string: imageUrl) {
            setImageUrl(url)
        }
        else {
            image = UIImage(contentsOfFile: imageUrl)
        }
    }
}
