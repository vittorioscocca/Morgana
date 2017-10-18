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
    
    var prodotti: [Product]?
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
    
    var paymentState: String?
    var offerState: String?
    var dataCreazioneOfferta: String?
    var idOfferta: String?
    var totalReadedFromFirebase: String = ""
    var company: Company?
    var viewState: String?
    
    enum offerStates: String {
        case rifiutata = "Offerta rifiutata" //l'utente destinatario dell'offerta rifiuta l'offerta
        case accettata = "Offerta accettata" // l'utente destinatario dell'offerta accetta l'offerta
        case inoltrata = "Offerta inoltrata" // l'utente destinatario dell'offerta ha inoltrato l'offerta
        case offertaTerminata = "Scaduta" // data scadenza raggiunta
        case offertaConsumata = "Offerta consumata" // data scadenza raggiunta
        case pending = "Pending" //stato di default
        case ransom = "Offerta riscattata"
    
    }
    
    enum viewStates: String {
        case active = "active" //l'utente destinatario dell'offerta rifiuta l'offerta
        case deleted = "deleted" // l'utente destinatario dell'offerta accetta l'offerta
        case filed = "filed" // l'utente destinatario dell'offerta ha inoltrato l'offerta
    }
    
    
    
    enum paymentStates: String {
        case offertaValida = "Valid" // pagamento avvenuto con successo l'amico ha consumato l'offerta
        case offertaNonValida = "Not Valid" //in caso di errore di pagamento
        case pending = "Pending" //aspetta l'autorizzazione al pagamento

    }
    
    var costoTotale: Double {
        var tot: Double = 0.0
        for i in prodotti! {
            tot += i.price! * Double(i.quantity!)
        }
        return tot
    }
    
    var prodottiTotali: Int {
        var tot: Int = 0
        for i in prodotti! {
            tot += i.quantity!
        }
        return tot
    }
    
    private init(){
        self.prodotti = []
        self.expirationeDate = ""
        self.consumingDate = ""
        self.userDestination = UserDestination(nil,nil,nil,nil,nil)
        self.paymentState = paymentStates.pending.rawValue
        self.offerState = offerStates.pending.rawValue
        self.userSender = UserDestination(nil,nil,nil,nil,nil)
        self.ordersSentAutoId = ""
        self.company = Company()
        self.viewState = viewStates.active.rawValue
    }
    
    
    init(prodotti: [Product], userDestination: UserDestination, userSender: UserDestination){
        self.prodotti = prodotti
        self.expirationeDate = ""
        self.userDestination = userDestination
        self.userSender = userSender
        self.dataCreazioneOfferta = ""
        self.paymentState = paymentStates.pending.rawValue
        self.offerState = offerStates.pending.rawValue
        self.ordersSentAutoId = ""
        self.orderNotificationIsScheduled = false
        self.orderReaded = false
        self.orderExpirationNotificationIsScheduled = false
        self.company = Company()
        self.viewState = viewStates.active.rawValue
    }
    
    
    
    func validateOffer(){
        self.paymentState = paymentStates.offertaValida.rawValue
    }
    
    
    
    func terminateOffer(){
        self.paymentState = offerStates.offertaTerminata.rawValue
    }
    func notValidateOffer(){
        self.paymentState = paymentStates.offertaNonValida.rawValue
    }
    func pendingOffer(){
        self.paymentState = paymentStates.pending.rawValue
    }
    
    func refuseOffer(){
        self.offerState = offerStates.rifiutata.rawValue
    }
    
    func acceptOffer(){
        self.offerState = offerStates.accettata.rawValue
    }
    
    func forwardOffer(){
        self.offerState = offerStates.inoltrata.rawValue
    }
    
    func consumedOffer(){
        self.offerState = offerStates.offertaConsumata.rawValue
    }
    
    func ransomOffer(){
        self.offerState = offerStates.ransom.rawValue
    }
    
    func addProduct(product: Product) {
        var trovato = false
        for i in self.prodotti! {
            if i.productName == product.productName {
                trovato = true
                i.quantity! += product.quantity!
            }
        }
        guard trovato else {
            self.prodotti?.insert(product, at: 0)
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
