//
//  Offerta.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 26/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import FirebaseDatabase
import Firebase


class Order {
    static let sharedIstance = Order()
    
    var products: [Product]?
    var expirationeDate: String?
    var userDestination: UserDestination?
    var userSender: UserDestination?
    var orderReaded :Bool?
    var orderAutoId = ""
    var ordersSentAutoId = ""
    var pendingPaymentAutoId = ""
    var timeStamp : TimeInterval = 0
    var orderNotificationIsScheduled :Bool?
    var orderExpirationNotificationIsScheduled :Bool?
    var consumingDate: String?
    var paymentState: Payment.State
    var offerState: OfferStates
    var dataCreazioneOfferta: String?
    var idOfferta: String?
    var totalReadedFromFirebase: String = ""
    var company: Company?
    var viewState: ViewStates
    
    var points: Int {
        var innerPoints = 0
        products?.forEach({ (product) in
            if let point = product.points {
               innerPoints += point
            }
        })
        return innerPoints
    }
    
    enum OfferStates: String {
        case refused = "Offerta rifiutata" //l'utente destinatario dell'offerta rifiuta l'offerta
        case accepted = "Offerta accettata" // l'utente destinatario dell'offerta accetta l'offerta
        case forward = "Offerta inoltrata" // l'utente destinatario dell'offerta ha inoltrato l'offerta
        case expired = "Scaduta" // data scadenza raggiunta
        case consumed = "Offerta consumata" // data scadenza raggiunta
        case pending = "Pending" //stato di default
        case ransom = "Offerta riscattata"
        case scaled = "Offerta scalata"  
    }
    
    enum ViewStates: String {
        case active = "active" //l'utente destinatario dell'offerta rifiuta l'offerta
        case deleted = "deleted" // l'utente destinatario dell'offerta accetta l'offerta
        case filed = "filed" // l'utente destinatario dell'offerta ha inoltrato l'offerta
    }
    var costoTotale: Double {
        var tot: Double = 0.0
        for i in products! {
            tot += i.price! * Double(i.quantity!)
        }
        return tot
    }
    
    var prodottiTotali: Int {
        var tot: Int = 0
        for i in products! {
            tot += i.quantity!
        }
        return tot
    }
    
    private init(){
        self.products = []
        self.expirationeDate = ""
        self.consumingDate = ""
        self.userDestination = UserDestination(nil,nil,nil,nil,nil)
        self.paymentState = .pending
        self.offerState = OfferStates.pending
        self.userSender = UserDestination(nil,nil,nil,nil,nil)
        self.ordersSentAutoId = ""
        self.company = Company()
        self.viewState = ViewStates.active
    }
    
    
    init(prodotti: [Product], userDestination: UserDestination, userSender: UserDestination){
        self.products = prodotti
        self.expirationeDate = ""
        self.userDestination = userDestination
        self.userSender = userSender
        self.dataCreazioneOfferta = ""
        self.paymentState = .pending
        self.offerState = OfferStates.pending
        self.ordersSentAutoId = ""
        self.orderNotificationIsScheduled = false
        self.orderReaded = false
        self.orderExpirationNotificationIsScheduled = false
        self.company = Company()
        self.viewState = ViewStates.active
    }
    
    func validateOffer(){
        self.paymentState = .valid
    }
    
    func notValidateOffer(){
        self.paymentState = .notValid
    }
    func pendingOffer(){
        self.paymentState = .pending
    }
    
    func refuseOffer(){
        self.offerState = .refused
    }
    
    func acceptOffer(){
        self.offerState = .accepted
    }
    
    func forwardOffer(){
        self.offerState = .forward
    }
    
    func consumedOffer(){
        self.offerState = .consumed
    }
    
    func ransomOffer(){
        self.offerState = OfferStates.ransom
    }
    
    func addProduct(product: Product) {
        var trovato = false
        for i in self.products! {
            if i.productName == product.productName {
                trovato = true
                i.quantity! += product.quantity!
            }
        }
        guard trovato else {
            self.products?.insert(product, at: 0)
            return
        }
    }
    
    func calcolaDataScadenzaOfferta (selfOrder: Bool) {
        if self.dataCreazioneOfferta != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
            formatter.locale = Locale.init(identifier: "it_IT")
            let dateOfferta: Date = formatter.date(from: self.dataCreazioneOfferta!)!
            //if the user has bought the order for itself expiration date is from 1 year
            var date = Date()
            if selfOrder {
                date = Calendar.current.date(byAdding: .year, value: 1, to: dateOfferta)!
            }else {
                //let date = Calendar.current.date(byAdding: .weekOfMonth, value: 1, to: dateOfferta)
                date = Calendar.current.date(byAdding: .weekday, value: 3, to: dateOfferta)!
            }
            
            self.expirationeDate = formatter.string(from: date)
        }
    }
}

extension Order {
    static let expirationDate = "expirationDate"
    static let paymentStateString = "paymentState"
    static let offerState = "offerState"
    static let facebookUserDestination = "facebookUserDestination"
    static let offerCreationDate = "offerCreationDate"
    static let total = "total"
    static let IdAppUserDestination = "IdAppUserDestination"
    static let timestamp = "timestamp"
    static let ordersSentAutoId = "ordersSentAutoId"
    static let orderNotificationIsScheduled = "orderNotificationIsScheduled"
    static let orderAutoId = "orderAutoId"
    static let pendingPaymentAutoId = "pendingPaymentAutoId"
    static let userSender = "userSender"
    static let orderReaded = "orderReaded"
    static let consumingDate = "consumingDate"
    static let viewState = "viewState"
    static let autoId = "autoId"
    static let offerId = "offerId"
    static let orderExpirationNotificationIsScheduled = "orderExpirationNotificationIsScheduled"
    static let scanningQrCode = "scanningQrCode"
}
