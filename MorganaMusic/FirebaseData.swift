//
//  FirebaseData.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 25/08/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import FirebaseDatabase
import Firebase

class FirebaseData {
    
    static let sharedIstance = FirebaseData()
    // Firebase data is organaized as: orderSent, ordereReceived, orderPayment, productsSentDetails
    
    var user: User?
    var userDestination: UserDestination?
    var order: Order?
    var badgeValue: Int?
    var ordersSent: [Order]
    var ordersReceived: [Order]
    var lastOrderSentReadedTimestamp = UserDefaults.standard
    var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    
    
    private init(){
        self.ordersSent = [Order]()
        self.ordersReceived = [Order]()
    }
    
    func saveOrderSentOnFirebase(user: User, userDestination: UserDestination,badgeValue: Int, order: Order, onCompletion: @escaping ()->()){
        self.user = user
        self.userDestination = userDestination
        self.order = order
        self.badgeValue = badgeValue
        
        var offerDetails: [String:Any] = [
            "expirationDate": order.expirationeDate!,
            "paymentState": order.paymentState!,
            "offerState": order.offerState!,
            "facebookUserDestination": (order.userDestination?.idFB)!,
            "offerCreationDate": order.dataCreazioneOfferta!,
            "total": String(format:"%.2f", order.costoTotale),
            "IdAppUserDestination": (order.userDestination?.idApp)!,
            "timestamp" : FIRServerValue.timestamp(),
            "orderOfferedAutoId" : order.orderOfferedAutoId,
            "orderAutoId": "",
            "pendingPaymentAutoId": "",
            "orderReaded":"false"
        ]
        if (self.user?.idApp)! == (offerDetails["IdAppUserDestination"] as! String) {
            offerDetails["offerState"] = "Offerta accettata"
        }
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "orderOffered", child: (user.idApp)!, dictionaryToSave: offerDetails, onCompletion: {(error) in
            guard error == nil else {
                return
            }
            if userDestination.idApp != user.idApp {
                FireBaseAPI.updateNode(node: "users/"+(user.idApp)!, value: ["number of pending purchased products" : badgeValue + 1])
            }
            
        })
        
        self.saveProductOnFireBase()
        self.saveOrderAsReceivedOnFireBase()
        self.savePaymentOnFireBase(onCompletion: {
            onCompletion()
        })
    }
    
    
    private func saveProductOnFireBase(){
        var idFBFriend: String?
        var creationDate: String?
        var autoId_orderOffered: String?
        
        FireBaseAPI.readNodeOnFirebaseQueryLimited(node: "orderOffered/"+(self.user?.idApp)!, queryLimit: Cart.sharedIstance.carrello.count, onCompletion: { (error, dictionary) in
            
            guard error == nil else {
                return
            }
            guard dictionary != nil else {
                return
            }
            
            for (chiave,valore) in dictionary! {
                switch chiave  {
                case "facebookUserDestination":
                    idFBFriend = valore as? String
                    break
                case "offerCreationDate":
                    creationDate = valore as? String
                    break
                case "autoId":
                    autoId_orderOffered = valore as? String
                    break
                default:
                    break
                }
            }
            //costruisco il dictionary di dettaglio delle offerte: i prodotti
            var offerDetails: [String:String] = [:]
            for j in Cart.sharedIstance.carrello {
                if (j.userDestination?.idFB == idFBFriend) && (j.dataCreazioneOfferta == creationDate) {
                    for i in j.prodotti! {
                        if i.productName != "+    Aggiungi altro drink" {
                            offerDetails[i.productName!] = String(i.quantity!) + "x" + String(format:"%.2f", i.price!)
                        }
                    }
                }
            }
            let currentDetails = offerDetails
            FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "productsOffersDetails", child: autoId_orderOffered!, dictionaryToSave: currentDetails, onCompletion: { (error) in
                guard error == nil else {
                    return
                }
                offerDetails.removeAll()
            })
        })
    }

    func saveOrderAsReceivedOnFireBase() {
        
        FireBaseAPI.readNodeOnFirebaseQueryLimited(node: "orderOffered/"+(self.user?.idApp)!, queryLimit: Cart.sharedIstance.carrello.count, onCompletion: { (error,dictionary) in
            guard error == nil else {

                return
            }
            guard dictionary != nil else {
                return
            }
            
            //for dictionary in dictionaries! {
            var offerDetails: [String:Any] = dictionary!
            // leggo i dati dell'ordine o offerte
            
            offerDetails["offerId"] = offerDetails["autoId"]
            offerDetails.removeValue(forKey: "autoId")
            offerDetails.removeValue(forKey: "orderOfferedAutoId")
            offerDetails["userSender"] = (self.user?.idApp)!
            offerDetails["orderReaded"] = "false"
            if (self.user?.idApp)! == (offerDetails["IdAppUserDestination"] as! String) {
                offerDetails["offerState"] = "Offerta accettata"
            }
            
            
            //offerDetails["timestamp"] = FIRServerValue.timestamp()
            FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "orderReceived", child: offerDetails["IdAppUserDestination"]! as! String, dictionaryToSave: offerDetails, onCompletion: { (error) in
                guard error == nil else {
                    print("read error on Firebase")
                    return
                }
                FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + (offerDetails["offerId"] as! String), value: ["orderAutoId":offerDetails["offerId"]!])
                self.updateOrderOfferedWithOrderReceivedAutoId(iDAppUserDestination: offerDetails["IdAppUserDestination"]! as! String, offerId: offerDetails["offerId"] as! String)
                offerDetails.removeAll()
                
            })
        })
        
    }
    
    private func updateOrderOfferedWithOrderReceivedAutoId(iDAppUserDestination: String, offerId: String){
        FireBaseAPI.readNodeOnFirebase(node: "orderReceived/"+iDAppUserDestination, onCompletion: { (error,dictionary) in
            guard error == nil else {
                return
            }
            guard dictionary != nil else {
                return
            }
            //for dictionary in dictionaries! {
            if (dictionary?["offerId"] as! String) == (offerId) {
                FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + offerId, value: ["orderOfferedAutoId": (dictionary?["autoId"])!])
                FireBaseAPI.updateNode(node: "orderReceived/" + iDAppUserDestination + "/" + (dictionary?["autoId"] as! String), value: ["orderAutoId":(dictionary?["autoId"] as! String)])
            }
        })
    }

    
    private func savePaymentOnFireBase (onCompletion: @escaping ()->()){
        let ref = FIRDatabase.database().reference()
        var idFBFriend: String?
        var paymentDetails: [String:String] = [:]
        
        
        let query = ref.child("orderOffered/"+(self.user?.idApp)!).queryLimited(toLast: UInt(Cart.sharedIstance.carrello.count))
        query.observeSingleEvent(of: .value, with: { (snap) in
            
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let dizionario_offerte = snap.value! as! NSDictionary
            
            // leggo i dati dell'ordine o offerte
            var count = 0
            for (id_offers,dati_offers) in dizionario_offerte {
                for (chiave,valore) in (dati_offers as! NSDictionary) {
                    if (chiave as! String) == "facebookUserDestination" {
                        idFBFriend = valore as? String
                    }
                }
                for j in Cart.sharedIstance.carrello {
                    if j.userDestination?.idFB == idFBFriend {
                        paymentDetails["offerID"+String(count)] = id_offers as? String
                        count += 1
                    }
                    
                }
            }
            //costruisco il dictionary dei pagamenti
            paymentDetails["idPayment"] = Cart.sharedIstance.paymentMethod?.idPayment
            paymentDetails["createTime"] = Cart.sharedIstance.paymentMethod?.createTime
            paymentDetails["paymentType"] = Cart.sharedIstance.paymentMethod?.paymentType
            paymentDetails["platform"] = Cart.sharedIstance.paymentMethod?.platform
            paymentDetails["statePayment"] = Cart.sharedIstance.paymentMethod?.statePayment
            paymentDetails["totalProducts"] = String(Cart.sharedIstance.prodottiTotali)
            paymentDetails["total"] = String(format:"%.2f", Cart.sharedIstance.costoTotale)
            paymentDetails["stateCartPayment"] = Cart.sharedIstance.state
            paymentDetails["pendingUserIdApp"] = (self.user?.idApp)!
            ref.child("pendingPayments").child((self.user?.idApp)!).childByAutoId().setValue(paymentDetails)
            self.setPaymentAutoIDIntoOfferReceived(onCompletion: { (payment) in
                guard payment != nil else {
                    return
                }
                //solve pending payments
                PaymentManager.sharedIstance.resolvePendingPayPalPayment(user: self.user!, payment: payment!, onCompleted: { (verifiedPayment) in
                    guard verifiedPayment else {
                        print("pagamento non valido")
                        Cart.sharedIstance.pendingPaymentNotResolved()
                        onCompletion()
                        return
                    }
                    print("pagamento valido")
                    Cart.sharedIstance.pendingPaymentResolved()
                    onCompletion()
                })
            })
        })
    }
    
    private func setPaymentAutoIDIntoOfferReceived(onCompletion: @escaping (Payment?)->()){
        
        FireBaseAPI.readNodeOnFirebaseQueryLimited(node: "pendingPayments/" + (self.user?.idApp)!, queryLimit: 1, onCompletion: {
            (error,dictionary) in
            var payment: Payment?
            
            guard error == nil else {
                onCompletion(payment)
                return
            }
            guard dictionary != nil else {
                onCompletion(payment)
                return
            }
            payment = Payment(platform: "", paymentType: "", createTime: "", idPayment: "", statePayment: "", autoId: "",total: "")
            var count = 0
            payment?.autoId = dictionary?["autoId"] as? String
            
            for (chiave,valore) in dictionary! {
                switch chiave {
                case let x where (x.range(of:"offerID") != nil):
                    payment?.relatedOrders.append((valore as? String)!)
                    count += 1
                    break
                case "idPayment":
                    payment?.idPayment = valore as? String
                    break
                case "statePayment":
                    payment?.statePayment = valore as? String
                    break
                case "total":
                    payment?.total = valore as? String
                    break
                    
                case "pendingUserIdApp":
                    payment?.pendingUserIdApp = (valore as? String)!
                    break
                default:
                    break
                }
            }
            
            for i in  payment!.relatedOrders {
                FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + i, value: ["pendingPaymentAutoId" : dictionary?["autoId"] as! String])
            }
            
            onCompletion(payment)
        })
    }

    func readOrdersSentOnFireBase(user: User, friendsList: [Friend]?,onCompletion: @escaping ([Order])->()){
        self.user = user
        let ref = FIRDatabase.database().reference()
        self.ordersSent.removeAll()
        
        ref.child("orderOffered/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.ordersSent.removeAll()
            
            let dizionario_offerte = snap.value! as! NSDictionary
            
            for (id_offer, dati_pendingOffers) in dizionario_offerte{
                
                let offerta: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                offerta.idOfferta = id_offer as? String
                
                for (chiave,valore) in (dati_pendingOffers as! NSDictionary) {
                    switch chiave as! String {
                    case "expirationDate":
                        offerta.expirationeDate = valore as? String
                        break
                    case "paymentState":
                        offerta.paymentState = valore as? String
                        break
                    case "offerState":
                        offerta.offerState = valore as? String
                        break
                    case "facebookUserDestination":
                        offerta.userDestination?.idFB = valore as? String
                        if offerta.userDestination?.idFB == self.user?.idFB {
                            offerta.userDestination?.fullName = self.user?.fullName
                            offerta.userDestination?.pictureUrl = self.user?.pictureUrl
                        } else if !(friendsList?.isEmpty)! {
                            for i in friendsList! {
                                if i.idFB == valore as? String {
                                    offerta.userDestination?.fullName = i.fullName
                                    offerta.userDestination?.pictureUrl = i.pictureUrl
                                    break
                                }
                            }
                        }
                        break
                    case "offerCreationDate":
                        offerta.dataCreazioneOfferta = valore as? String
                        break
                    case "IdAppUserDestination":
                        offerta.userDestination?.idApp = valore as? String
                        break
                    case "timestamp":
                        offerta.timeStamp = (valore as? TimeInterval)!
                        break
                    case "pendingPaymentAutoId":
                        offerta.pendingPaymentAutoId = (valore as? String)!
                        break
                    case "orderOfferedAutoId":
                        offerta.orderOfferedAutoId = (valore as? String)!
                        break
                    case "userSender":
                        offerta.userSender?.idApp = (valore as? String)!
                        break
                    case "orderReaded":
                        if (valore as? String) == "false" {
                            offerta.orderReaded = false
                        } else {offerta.orderReaded = true}
                        break
                    default:
                        break
                    }
                }
                if offerta.offerState != "Scaduta" {
                    
                    ref.child("sessions").setValue(FIRServerValue.timestamp())
                    ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
                        let timeStamp = snap.value! as! TimeInterval
                        let date = NSDate(timeIntervalSince1970: timeStamp/1000)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.amSymbol = "AM"
                        dateFormatter.pmSymbol = "PM"
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        let dateString = dateFormatter.string(from: date as Date)
                        let finalDate = dateFormatter.date(from: dateString)
                        self.lastOrderSentReadedTimestamp.set(finalDate!, forKey: "orderOfferedReadedTimestamp")
                        
                        let date1Formatter = DateFormatter()
                        date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        date1Formatter.locale = Locale.init(identifier: "it_IT")
                        
                        let dateObj = date1Formatter.date(from: offerta.expirationeDate!)
                        if dateObj! < finalDate! {
                            offerta.offerState = "Scaduta"
                            ref.child("orderOffered/" + (self.user?.idApp)! + "/" + offerta.idOfferta!).updateChildValues(["offerState" : "Scaduta"])
                            ref.child("orderReceived/" + (offerta.userDestination?.idApp)! + "/" + offerta.orderOfferedAutoId).updateChildValues(["offerState" : "Scaduta"])
                            
                            let msg = "Il prodotto che ti è stato offerto da \((self.user?.fullName)!) è scaduto"
                            NotitificationsCenter.sendNotification(userIdApp: (offerta.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
                            self.updateNumberPendingProductsOnFireBase((offerta.userDestination?.idApp)!, recOrPurch: "received")
                        }
                    })
                }
                if offerta.paymentState != "Valid"  {
                    self.ordersSent.append(offerta)
                }else if self.user?.idApp != offerta.userDestination?.idApp   {
                    self.ordersSent.append(offerta)
                }
            }
            self.ordersSent.sort(by: {self.stringTodateObject(timestamp: $0.timeStamp) > self.stringTodateObject(timestamp: $1.timeStamp)})
            self.readProductsSentDetails(ordersToRead:self.ordersSent, onCompletion: {
                onCompletion(self.ordersSent)
            })
            
        })
    }
    
    func readOrderReceivedOnFireBase(onCompletion: @escaping ([Order])->()) {
        let ref = FIRDatabase.database().reference()
        let query = ref.child("orderReceived/"+(self.user?.idApp)!).queryOrdered(byChild: "timestamp")
        
        self.ordersReceived.removeAll()
        
        query.observe(.value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.ordersReceived.removeAll()
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let dizionario_offerte = snap.value! as! NSDictionary
            
            // leggo i dati dell'ordine o offerte
            for (orderId, dati_pendingOffers) in dizionario_offerte {
                
                let offerta: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                for (chiave,valore) in (dati_pendingOffers as! NSDictionary) {
                    
                    switch chiave as! String {
                    case "expirationDate":
                        offerta.expirationeDate = valore as? String
                        break
                    case "paymentState":
                        offerta.paymentState = valore as? String
                        break
                    case "offerState":
                        offerta.offerState = valore as? String
                        break
                    case "offerCreationDate":
                        offerta.dataCreazioneOfferta = valore as? String
                        break
                    case "offerId":
                        offerta.idOfferta = valore as? String
                        break
                    case "userSender":
                        offerta.userSender?.idApp = valore as? String
                        break
                    case "timestamp":
                        offerta.timeStamp = (valore as? TimeInterval)!
                        break
                    case "IdAppUserDestination":
                        offerta.userDestination?.idApp = valore as? String
                        break
                    case "orderReaded":
                        if (valore as? String) == "false" {
                            offerta.orderReaded = false
                        } else {offerta.orderReaded = true}
                        break
                    default:
                        break
                    }
                }
                
                if offerta.offerState != "Scaduta" {
                    ref.child("sessions").setValue(FIRServerValue.timestamp())
                    ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
                        let timeStamp = snap.value! as! TimeInterval
                        
                        let date = NSDate(timeIntervalSince1970: timeStamp/1000)
                        
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.amSymbol = "AM"
                        dateFormatter.pmSymbol = "PM"
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        let dateString = dateFormatter.string(from: date as Date)
                        let finalDate = dateFormatter.date(from: dateString)
                        self.lastOrderReceivedReadedTimestamp.set(finalDate!, forKey: "lastOrderReceivedReadedTimestamp")
                        
                        let date1Formatter = DateFormatter()
                        date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        date1Formatter.locale = Locale.init(identifier: "it_IT")
                        
                        let dateObj = date1Formatter.date(from: offerta.expirationeDate!)
                        if dateObj! < finalDate! {
                            ref.child("orderReceived/" + (self.user?.idApp)! + "/" + offerta.orderAutoId).updateChildValues(["offerState" : "Scaduta"])
                            ref.child("orderOffered/" + (offerta.userSender?.idApp)! + "/" + offerta.idOfferta!).updateChildValues(["offerState" : "Scaduta"])
                            offerta.offerState = "Scaduta"
                            let msg = "Il prodotto che hai offerto a \((self.user?.fullName)!) è scaduto"
                            NotitificationsCenter.sendNotification(userIdApp: (offerta.userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                            self.updateNumberPendingProductsOnFireBase((offerta.userSender?.idApp)!, recOrPurch: "purchased")
                        }
                    })
                }
                if offerta.paymentState == "Valid" && offerta.offerState != "Offerta rifiutata" && offerta.offerState != "Offerta inoltrata" {
                    offerta.orderAutoId = orderId as! String
                    self.ordersReceived.append(offerta)
                }
            }
            self.ordersReceived.sort(by: {self.stringTodateObject(timestamp: $0.timeStamp) > self.stringTodateObject(timestamp: $1.timeStamp)})
           
            self.readUserSender(onCompletion: {
                self.readProductsSentDetails(ordersToRead: self.ordersReceived ,onCompletion: {
                    onCompletion(self.ordersReceived)
                })
            })
        })
    }
    
    private func readUserSender(onCompletion: @escaping ()->()){
        let ref = FIRDatabase.database().reference()
        for j in self.ordersReceived{
            ref.child("users/" + (j.userSender?.idApp)!).observeSingleEvent(of: .value, with: { (snap) in
                
                guard snap.exists() else {return}
                guard snap.value != nil else {return}
                
                let dati_user = snap.value! as! NSDictionary
                
                for (chiave,valore) in dati_user{
                    switch chiave as! String {
                    case "nome completo" :
                        j.userSender?.fullName = valore as? String
                        break
                    case "picture url":
                        j.userSender?.pictureUrl = valore as? String
                        break
                    default:
                        break
                    }
                }
            })
        }
        onCompletion()
    }
    
    private func readProductsSentDetails(ordersToRead: [Order], onCompletion: @escaping ()->()) {
        let ref = FIRDatabase.database().reference()
        ref.child("productsOffersDetails").observeSingleEvent(of: .value, with: { (snap) in
            
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let dati_products = snap.value! as! NSDictionary
            
            for (id_offerF, dizionario_products) in dati_products {
                for j in ordersToRead {
                    if (id_offerF as! String) == j.idOfferta {
                        for (_, dati_products) in (dizionario_products as! NSDictionary){
                            var prodotto: Product = Product(productName: nil, price: nil, quantity: nil)
                            for (chiave,valore) in (dati_products as! NSDictionary) {
                                prodotto.productName = chiave as? String
                                let token = (valore as? String)?.components(separatedBy: "x")
                                prodotto.quantity = Int((token?[0])!)
                                prodotto.price = Double((token?[1])!)
                                if (prodotto.price != nil) && (prodotto.productName != nil) && (prodotto.quantity != nil){
                                    j.prodotti?.append(prodotto)
                                    prodotto = Product(productName: nil, price: nil, quantity: nil)
                                    
                                }
                            }
                        }
                    }
                }
            }
            onCompletion()
        })
        
    }
    
    func updateNumberPendingProductsOnFireBase(_ idAppUserDestination: String, recOrPurch: String){
        let ref = FIRDatabase.database().reference()
        ref.child("users/" + idAppUserDestination).observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            var badgeValueToUpdate = ""
            if recOrPurch == "received" {
                badgeValueToUpdate = "number of pending received products"
            } else if recOrPurch == "purchased" {
                badgeValueToUpdate = "number of pending purchased products"
            }
            let dizionario_users = snap.value! as! NSDictionary
            var badgeValue = 0
            
            for (chiave,valore) in dizionario_users {
                switch chiave as! String {
                    
                case badgeValueToUpdate:
                    badgeValue = (valore as? Int)!
                    break
                default:
                    break
                }
            }
            ref.child("users/"+idAppUserDestination).updateChildValues([badgeValueToUpdate : badgeValue + 1])
        })
    }

    private func stringTodateObject(timestamp: TimeInterval)->Date {
        
        let date = NSDate(timeIntervalSince1970: timestamp/1000)
        
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let dateString = dateFormatter.string(from: date as Date)
        return dateFormatter.date(from: dateString)!
    }
    
    func updateStateOnFirebase (order: Order, state: String){
        FireBaseAPI.updateNode(node: "orderReceived/" + (self.user?.idApp)! + "/" + order.orderAutoId, value: ["orderReaded" : "true", "offerState":state])
        FireBaseAPI.updateNode(node: "orderOffered/" + (order.userSender?.idApp)! + "/" + order.idOfferta!, value: ["offerState":state])
        
    }
    
    func deleteOrderReceveidOnFirebase(order: Order){
        let ref = FIRDatabase.database().reference()
        ref.child("orderReceived/" + (order.userDestination?.idApp)! + "/" + order.orderAutoId).removeValue()
    }
    
    func deleteOrderPurchasedOnFireBase(order: Order){
        //remove orderOffered
        FireBaseAPI.removeNode(node: "orderOffered/"+(self.user?.idApp)!, autoId: order.orderAutoId)
        
        //remove Payement
        FireBaseAPI.removeNode(node: "pendingPayments", autoId: order.orderAutoId)
        
        //remove products Details
        FireBaseAPI.removeNode(node: "productsOffersDetails", autoId: order.orderAutoId)
    }
    
    //migrates an order under another user
    func moveFirebaseRecord(userApp: User, user: UserDestination, order:Order, onCompletion: @escaping (String?)->()){
        let sourceNode = "orderReceived/" + (user.idApp)!+"/"+order.orderOfferedAutoId
        let destinationNode = "orderReceived/" + (order.userDestination?.idApp)!+"/"+order.orderOfferedAutoId
        var offerState : String {
            if order.userDestination?.idApp == userApp.idApp {
                return "Offerta accettata"
            } else {
                return "Pending"
            }
        }
        let newValues = [
            "IdAppUserDestination": (order.userDestination?.idApp)!,
            "facebookUserDestination":(order.userDestination?.idFB)!,
            "offerState":  offerState,
            "orderReaded": "false"
        ]
    
        FireBaseAPI.moveFirebaseRecordApplyingChanges(sourceChild: sourceNode, destinationChild: destinationNode, newValues: newValues, onCompletion: { (error) in
            guard error == nil else {
                onCompletion(error)
                return
            }
            onCompletion(error)
        })
        
    }
    
    //function  return user idApp from his Facebook iD
    func readUserIdAppFromIdFB(node:String, idFB:String, onCompletion: @escaping (String?,String?)->()){
        FireBaseAPI.readKeyForValueEqualTo(node: node, value: idFB, onCompletion: { (error,idApp) in
            guard error == nil else {
                onCompletion(error,idApp)
                return
            }
            onCompletion(error,idApp)
        })
    }

    
    
}
