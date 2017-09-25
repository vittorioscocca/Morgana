//
//  Maerchant.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/09/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class Merchant {
    static let sharedInstance = Merchant()
    
    var userId: String?
    var city: String?
    var businessName: String?
    var latitude: String?
    var longitude: String?
    var vat: String?
    var address: String?
    
    private init(userId: String?, city: String?, businessName: String?) {
        self.userId: userId
        self.city: city
        self.businessName: String?
        var latitude: String?
        var longitude: String?
        var vat: String?
        var address: String?
    }
    
}
