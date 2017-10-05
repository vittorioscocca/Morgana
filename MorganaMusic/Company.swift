//
//  Maerchant.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/09/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class Company {
    
    
    var companyId: String?
    var userId: String?
    var city: String?
    var companyName: String?
    var latitude: String?
    var longitude: String?
    var vat: String?
    var address: String?
    
    init(){
        
    }
    init(userId: String?, city: String?, companyName: String?){
        self.userId = userId
        self.city = city
        self.companyName = companyName
    }
    
}
