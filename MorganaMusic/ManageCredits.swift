//
//  ManageCredits.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 12/07/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

import UIKit

//update credit data on FireBase improved by FireBaseApi on july
class ManageCredits {
    
    static var credits = 0.0
    static var error: String?

    class func updateCredits (newCredit: String, userId: String, onCompletion: @escaping (String?) -> ()){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/"+userId, onCompletion: { (error,dictionary) in
            guard error == nil else {
                onCompletion(error)
                return
            }
            guard dictionary != nil else {
                onCompletion(error)
                return
            }
            credits = (dictionary?["credits"] as? Double)! + Double(newCredit)!
            FireBaseAPI.updateNode(node: "users/"+userId, value: ["credits":credits])
            onCompletion(error)
        })
    }
}
