//
//  Payment.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class Payment {
    
    var platform: String?
    var paymentType: String? //Apple or Paypal
    var createTime: String?
    var idPayment: String?
    var statePayment: String? //approved or saled
    var autoId: String?
    var total : String?
    var relatedOrders: [String]
    var pendingUserIdApp: String
    
    
    init( platform: String, paymentType: String, createTime: String, idPayment: String, statePayment: String, autoId: String, total: String) {
        
        self.platform = platform
        self.paymentType = paymentType
        self.createTime = createTime
        self.idPayment = idPayment
        self.statePayment = statePayment
        self.autoId = autoId
        self.total = total
        self.relatedOrders = []
        self.pendingUserIdApp = ""
    }
    
}
