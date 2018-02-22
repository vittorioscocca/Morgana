//
//  CashImage.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 18/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

public extension NSNotification.Name {
    static let CacheImageLoadImage = NSNotification.Name("CacheImageLoadImageNotification")
}
class CacheImage {
    
    static var imageCache = [String:UIImage]()
    

    class func getImage(url: String?, onCompletion: @escaping (UIImage?)->()){
        if let pictureUrl = url{
            if let img = imageCache[pictureUrl] {
                onCompletion(img)
                
            } else {
                let request = NSMutableURLRequest(url: NSURL(string: (url)!)! as URL)
                let session = URLSession.shared
                
                let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                    if error == nil {
                        let image = UIImage(data: data!)
                        self.imageCache[(url)!] = image
                        onCompletion(image)
                        //NotificationCenter.default.post(name: .CacheImageLoadImage, object: nil)
                    }
                    else {
                        print("Error: \(error!.localizedDescription)")
                        onCompletion(nil)
                    }
                })
                task.resume()
            }
        }
    }
}
