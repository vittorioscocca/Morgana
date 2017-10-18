//
//  CashImage.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 18/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class CacheImage {
    
    static var imageCache = [String:UIImage]()
    

    class func getImage(url: String?, onCompletion: @escaping (UIImage?)->()){
        if let pictureUrl = url{
            if let img = imageCache[pictureUrl] {
                onCompletion(img)
            } else {
                // The image isn't cached, download the img data
                // We should perform this in a background thread
                
                //let request: NSURLRequest = NSURLRequest(url: url! as URL)
                //let mainQueue = OperationQueue.main
                
                let request = NSMutableURLRequest(url: NSURL(string: (url)!)! as URL)
                let session = URLSession.shared
                
                //NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: mainQueue, completionHandler: { (response, data, error) -> Void in
                let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                    if error == nil {
                        // Convert the downloaded data in to a UIImage object
                        let image = UIImage(data: data!)
                        // Store the image in to our cache
                        self.imageCache[(url)!] = image
                        // Update the cell
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
