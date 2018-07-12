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
                guard let nsUrl = NSURL(string: pictureUrl) else { return }
                let request = NSMutableURLRequest(url: nsUrl as URL)
                let session = URLSession.shared
                let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                    if error == nil {
                        guard let imageData = data else {
                            onCompletion(nil)
                            return
                        }
                        let image = UIImage(data: imageData)
                        self.imageCache[pictureUrl] = image
                        onCompletion(image)
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
