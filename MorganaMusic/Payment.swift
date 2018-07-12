//
//  Payment.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class Payment {
    
    //mapping DB
    static let total = "total"
    static let idPayment = "idPayment"
    static let createTime = "createTime"
    static let paymentType = "paymentType"
    static let platform = "platform"
    static let statePayment = "statePayment"
    static let totalProducts = "totalProducts"
    static let stateCartPayment = "stateCartPayment"
    static let pendingUserIdApp = "pendingUserIdApp"
    
    enum State: String {
        case notValid = "Not Valid"
        case pending = "Pending"
        case valid = "Valid"
    }
    
    var platform: String?
    var paymentType: String? //Apple or Paypal or Credits
    var createTime: String?
    var idPayment: String?
    var statePayment: String? //approved or saled or terminated
    var autoId: String?
    var total : String?
    var relatedOrders: [String]
    var pendingUserIdApp: String
    var company: Company?
    
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
        self.company = Company()
    }
    
}
