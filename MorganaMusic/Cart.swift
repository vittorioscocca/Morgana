//
//  Carousel.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 09/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

class Cart {

    static let sharedIstance = Cart()
    
    var paymentMethod: Payment?
    var payPalEnvironment: PayPalEnvironment?
    var cart: [Order]
    
    var state: String?
    
    var costoTotale: Double {
        var tot: Double = 0.0
        for i in cart {
            tot += i.costoTotale
        }
        return tot
    }
    
    var company: Company?
    
    var totalProducts:Int {
        var tot: Int = 0
        for i in cart {
            tot += i.prodottiTotali
        }
        return tot
    }
    
    var totalPoints: Int {
        var innerPoints = 0
        
        cart.forEach({ (order) in
            innerPoints += order.points
        })
        
        return innerPoints
    }
    
    enum offerState: String {
        case pendingPaypal = "Pending PayPal Approval"
        case pendingApple = "PendingApple"
        case paymentResolved = "Valid"
        case initialized = "Carrello Vuoto"
        case paymentNorResolved = "Not Valid"
        
    }
    
    
    private init(){
        self.cart = []
        self.paymentMethod = nil
        self.state = offerState.initialized.rawValue
        
    }
    
    func initializeCart() {
        self.cart = []
        self.paymentMethod = nil
        self.payPalEnvironment = nil
        self.state = offerState.initialized.rawValue
        self.company = nil
    }
    
    func pendingPayPalOffer(){
        self.state = offerState.pendingPaypal.rawValue
    }
    
    func pendingAppleOffer(){
        self.state = offerState.pendingApple.rawValue
    }
    func pendingPaymentResolved(){
        self.state = offerState.paymentResolved.rawValue
    }
    
    func pendingPaymentNotResolved(){
        self.state = offerState.paymentNorResolved.rawValue
    }
    
}
