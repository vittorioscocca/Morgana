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
import UserNotifications

class FirebaseData {
    
    static let sharedIstance = FirebaseData()
    // Firebase data is organaized as: orderSent, ordereReceived, orderPayment, productsSentDetails
    
    var user: User?
    //var userDestination: UserDestination?
    //var order: Order?
    
    var ordersSent: [Order]
    var ordersReceived: [Order]
    var companies: [Company]
    var lastOrderSentReadedTimestamp = UserDefaults.standard
    var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    
    var paymentDetails: [String:String]?
    
    var idOrder: [String]?

    private init(){
        self.ordersSent = [Order]()
        self.ordersReceived = [Order]()
        self.paymentDetails = [String:String]()
        self.idOrder = [String]()
        self.companies = [Company]()
    }
    
    
    private func updatePendingProducts(order: Order,badgeValue: Int ) {
        if order.userDestination?.idApp != (self.user?.idApp)! {
            FireBaseAPI.updateNode(node: "users/"+(self.user?.idApp)!, value: ["number of pending purchased products" : badgeValue + 1])
        }
    }
    
    private func updateOfferState(orderDetails: [String:Any])->String{
        if (self.user?.idApp)! == (orderDetails["IdAppUserDestination"] as! String) {
            return "Offerta accettata"
        }
        
        return orderDetails["offerState"] as! String
    }
    
    private func buildOrderDataDictionary(order: Order)->[String:Any]{
        return[
            "expirationDate": order.expirationeDate!,
            "paymentState": order.paymentState!,
            "offerState": order.offerState!,
            "facebookUserDestination": (order.userDestination?.idFB)!,
            "offerCreationDate": order.dataCreazioneOfferta!,
            "total": String(format:"%.2f", order.costoTotale),
            "IdAppUserDestination": (order.userDestination?.idApp)!,
            "timestamp" : ServerValue.timestamp(),
            "orderOfferedAutoId" : order.orderOfferedAutoId,
            "orderNotificationIsScheduled": order.orderNotificationIsScheduled!,
            "orderAutoId": "",
            "pendingPaymentAutoId": "",
            "orderReaded":"false"
        ]

    }
    
    private func saveOrdersSentOnFireBase (badgeValue: Int, order: Order, onCompletion: @escaping ()->()){
      
            var orderDetails = buildOrderDataDictionary(order: order)
            orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
            FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "orderOffered", child: (self.user?.idApp)!, dictionaryToSave: orderDetails, onCompletion: {(error) in
                guard error == nil else {
                    return
                }
                self.updatePendingProducts(order: order, badgeValue: badgeValue)
                onCompletion()
            })
    }
    
    private func saveOrderDictionaryStoredOnFirebase(onCompletion: @escaping ([String:Any])->()) {
        FireBaseAPI.readNodeOnFirebaseQueryLimited(node: "orderOffered/"+(self.user?.idApp)!, queryLimit: Cart.sharedIstance.carrello.count, onCompletion: { (error, dictionary) in
            guard error == nil else {return}
            guard dictionary != nil else {return}
            self.idOrder?.append(dictionary?["autoId"] as! String)
            onCompletion(dictionary!)
        })
        
    }

    func saveCartOnFirebase(user: User, badgeValue: Int,  onCompletion: @escaping ()->()){
        self.user = user
        
        var workItems = [DispatchWorkItem]()
        
        for order in Cart.sharedIstance.carrello{
            let dispatchItem = DispatchWorkItem.init {
                self.saveOrdersSentOnFireBase(badgeValue: badgeValue,order: order, onCompletion: {
                    print("OFFERTA SALVATA")
                })
            }
            dispatchItem.notify(queue: DispatchQueue.main, execute: {
                print("FINE")
            })
            workItems.append(dispatchItem)
        }
        
        let queue = DispatchQueue.init(label: "it.morgana.queue", attributes: .concurrent)
        for i in 0...workItems.count-1 {
            queue.async {
                let currentWorkItem = workItems[i]
                currentWorkItem.perform()
            }
        }
        
        
        self.saveOrderDictionaryStoredOnFirebase(onCompletion: { (dictionary) in
            self.saveProductOnFireBase(dictionary: dictionary)
            self.saveOrderAsReceivedOnFireBase(dictionary: dictionary)
            if self.idOrder?.count == Cart.sharedIstance.carrello.count {
                self.savePaymentOnFireBase(onCompletion: {
                    onCompletion()
                })
            }
            
        })
    }
    
    //SAVE PRODUCT ON FIREBASE
    private func buildProductOrderDetailsDictionary(idFBFriend: String?, creationDate: String? )->[String:String]?{
        //costruisco il dictionary di dettaglio delle offerte: i prodotti
        guard idFBFriend != nil else {return nil}
        guard creationDate != nil else { return nil}
        
        var orderDetails: [String:String] = [:]
        for order in Cart.sharedIstance.carrello {
            if (order.userDestination?.idFB == idFBFriend) && (order.dataCreazioneOfferta == creationDate) {
                for product in order.prodotti! {
                    if product.productName != "+    Aggiungi prodotto" {
                        orderDetails[product.productName!] = String(product.quantity!) + "x" + String(format:"%.2f", product.price!)
                    }
                }
            }
        }
        return orderDetails
    }
    
    private func saveOrderDetails(currentDetails: [String:String], autoId_orderOffered: String){
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "productsOffersDetails", child: autoId_orderOffered, dictionaryToSave: currentDetails, onCompletion: { (error) in
            guard error == nil else {
                return
            }
            //orderDetails.removeAll()
            print("offer Details saved")
        })
    }
    
    private func prepareProductDetails(orderDetailsSent: [String:Any]?, onCompletion: @escaping ([String:String]?, String?)->()) {
        
        var idFBFriend: String?
        var creationDate: String?
        var autoId_orderOffered: String?
        
        idFBFriend = orderDetailsSent?["facebookUserDestination"] as? String
        creationDate = orderDetailsSent?["offerCreationDate"] as? String
        autoId_orderOffered = orderDetailsSent?["autoId"] as? String
        let currentDetails = self.buildProductOrderDetailsDictionary(idFBFriend: idFBFriend, creationDate: creationDate)
        onCompletion(currentDetails, autoId_orderOffered)
    
        
    }
    
    private func saveProductOnFireBase(dictionary: [String:Any]?){
        prepareProductDetails(orderDetailsSent: dictionary, onCompletion: {(currentDetails, autoId_orderOffered) in
            guard currentDetails != nil else {
                print("[DETTAGLIO ORDINI]: problema di salvataggio")
                return
            }
            guard autoId_orderOffered != nil else {
                print("[DETTAGLIO ORDINI]: problema di salvataggio")
                return
            }
            
            self.saveOrderDetails(currentDetails: currentDetails!, autoId_orderOffered: autoId_orderOffered!)
        })
        
    }
    

    //SAVE ORDER AS RECEIVED ON FIREBASE
    private func buildOrderDetailsReceivedDictionary(dictionary:[String:Any] )->[String:Any]{
        
        var offerDetails: [String:Any] = dictionary
        
        // leggo i dati dell'ordine o offerte
        offerDetails["offerId"] = offerDetails["autoId"]
        offerDetails.removeValue(forKey: "autoId")
        offerDetails.removeValue(forKey: "orderOfferedAutoId")
        offerDetails["userSender"] = (self.user?.idApp)!
        offerDetails["orderReaded"] = "false"
        offerDetails["orderExpirationNotificationIsScheduled"] = false
        return offerDetails
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
    
    private func updateOrderSentAndReceivedAutoId (orderDetails: [String:Any]) {
        
        FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + (orderDetails["offerId"] as! String), value: ["orderAutoId":orderDetails["offerId"]!])
        self.updateOrderOfferedWithOrderReceivedAutoId(iDAppUserDestination: orderDetails["IdAppUserDestination"]! as! String, offerId: orderDetails["offerId"] as! String)
        
        //orderDetails.removeAll()
        print("Order as Received saved")
    }
    
    private func saveOrderOnFirebase(orderDetails: [String:Any],onCompletion: @escaping ()->()) {
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "orderReceived", child: orderDetails["IdAppUserDestination"]! as! String, dictionaryToSave: orderDetails, onCompletion: { (error) in
            guard error == nil else {
                print("read error on Firebase")
                return
            }
            onCompletion()
        })
    }
    
    func saveOrderAsReceivedOnFireBase(dictionary: [String:Any]?) {
        
        
        var orderDetails = buildOrderDetailsReceivedDictionary(dictionary: dictionary!)
    
        orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
        saveOrderOnFirebase(orderDetails: orderDetails, onCompletion: {
            self.updateOrderSentAndReceivedAutoId(orderDetails: orderDetails)
        })
        
    }
    
    
    private func buildPaymentIdOrders(){
        for numberOfpaymentIdOrders in 0...(idOrder?.count)! - 1 {
            self.paymentDetails?["offerID"+String(numberOfpaymentIdOrders)] = idOrder?[numberOfpaymentIdOrders]
        }
        self.idOrder?.removeAll()
    }
    
    //SAVE PAYMENT ON FIREBAASE
    private func savePaymentOnFireBase (onCompletion: @escaping ()->()){
        
        buildPaymentIdOrders()
        paymentDetails?["idPayment"] = Cart.sharedIstance.paymentMethod?.idPayment
        paymentDetails?["createTime"] = Cart.sharedIstance.paymentMethod?.createTime
        paymentDetails?["paymentType"] = Cart.sharedIstance.paymentMethod?.paymentType
        paymentDetails?["platform"] = Cart.sharedIstance.paymentMethod?.platform
        paymentDetails?["statePayment"] = Cart.sharedIstance.paymentMethod?.statePayment
        paymentDetails?["totalProducts"] = String(Cart.sharedIstance.prodottiTotali)
        paymentDetails?["total"] = String(format:"%.2f", Cart.sharedIstance.costoTotale)
        paymentDetails?["stateCartPayment"] = Cart.sharedIstance.state
        paymentDetails?["pendingUserIdApp"] = (self.user?.idApp)!
            
        //ref.child("pendingPayments").child((self.user?.idApp)!).childByAutoId().setValue(paymentDetails)
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "pendingPayments", child: (self.user?.idApp)!, dictionaryToSave: paymentDetails!, onCompletion: { (error) in
            guard error == nil else {
                return
            }
            
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
    
    private func scheduleExpiryNotification(order: Order){
        //scheduling notification appearing in expirationDate
        if !order.orderNotificationIsScheduled! {
            DispatchQueue.main.async {
                NotitificationsCenter.scheduledExpiratedOrderLocalNotification(title: "Ordine scaduto", body: "Il prodotto che hai offerto a \((order.userDestination?.fullName)!) è scaduto", identifier: order.idOfferta!, expirationDate: self.stringTodateObject(date: order.expirationeDate!))
                print("Notifica scadenza schedulata correttamente")
                order.orderNotificationIsScheduled = true
                FireBaseAPI.updateNode(node: "orderOffered/"+(self.user?.idApp)!+"/"+order.idOfferta!, value: ["orderNotificationIsScheduled":true])
            }
            
        }
    }
    
    func readCompaniesOnFireBase(onCompletion: @escaping ([Company]?)->()){
        let ref = Database.database().reference()
        self.ordersSent.removeAll()
        
        ref.child("merchant").observeSingleEvent(of:.value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.companies.removeAll()
        
            let companiesDictionary = snap.value! as! NSDictionary
            
            for (companyId, companiesData) in companiesDictionary{
                
                let company: Company = Company(userId: nil, city: nil, companyName: nil)
                company.companyId = companyId as? String
                
                for (chiave,valore) in (companiesData as! NSDictionary) {
                    switch chiave as! String {
                    case "denominazione":
                        company.companyName = valore as? String
                        break
                    case "via":
                        company.address = valore as? String
                        break
                    default:
                        break
                    }
                }
                self.companies.append(company)
            }
            onCompletion(self.companies)
        })
    }

    func readOrdersSentOnFireBase(user: User, friendsList: [Friend]?,onCompletion: @escaping ([Order])->()){
        self.user = user
        let ref = Database.database().reference()
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
                    case "orderNotificationIsScheduled":
                        offerta.orderNotificationIsScheduled = (valore as? Bool)!
                        break
                    default:
                        break
                    }
                }
                if offerta.offerState != "Scaduta" {
                    self.scheduleExpiryNotification(order: offerta)
                    ref.child("sessions").setValue(ServerValue.timestamp())
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
                            NotitificationsCenter.sendNotification(userDestinationIdApp: (offerta.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
                            self.updateNumberPendingProductsOnFireBase((offerta.userDestination?.idApp)!, recOrPurch: "received")
                        }
                    })
                }
                if offerta.paymentState != "Valid"  {
                    self.ordersSent.append(offerta)
                }else if self.user?.idApp != offerta.userDestination?.idApp   {
                    self.ordersSent.append(offerta)
                }
                //if consumption is before expirationDate, scheduled notification is killed
                //attenzione lo fa ogni volta che legge
                if offerta.offerState == "Offerta consumata" {
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: [offerta.idOfferta!])
                    print("scheduled notification killed")
                }
            }
            self.ordersSent.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})
            self.readProductsSentDetails(ordersToRead:self.ordersSent, onCompletion: {
                onCompletion(self.ordersSent)
            })
            
        })
    }
    
    func readOrderReceivedOnFireBase(user: User, onCompletion: @escaping ([Order])->()) {
        let ref = Database.database().reference()
        
        self.ordersReceived.removeAll()
        self.user = user
        ref.child("orderReceived/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.ordersReceived.removeAll()
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let dizionario_offerte = snap.value! as! NSDictionary
            
            // leggo i dati dell'ordine o offerte
            for (orderId, dati_pendingOffers) in dizionario_offerte {
                
                let offerta: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                offerta.orderAutoId = orderId as! String
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
                    case "orderNotificationIsScheduled":
                        offerta.orderNotificationIsScheduled = (valore as? Bool)!
                        break
                    case "orderExpirationNotificationIsScheduled":
                        offerta.orderExpirationNotificationIsScheduled = (valore as? Bool)!
                        break
                    case "total":
                        offerta.totalReadedFromFirebase = (valore as? String)!
                        break
                    default:
                        break
                    }
                }
                
                if offerta.offerState != "Scaduta" {
                    ref.child("sessions").setValue(ServerValue.timestamp())
                    ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
                        let timeStamp = snap.value! as! TimeInterval
                        
                        let date = NSDate(timeIntervalSince1970: timeStamp/1000)
                        
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.amSymbol = "AM"
                        dateFormatter.pmSymbol = "PM"
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        let dateString = dateFormatter.string(from: date as Date)
                        let currentDate = dateFormatter.date(from: dateString)
                        self.lastOrderReceivedReadedTimestamp.set(currentDate!, forKey: "lastOrderReceivedReadedTimestamp")
                        
                        let date1Formatter = DateFormatter()
                        date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        date1Formatter.locale = Locale.init(identifier: "it_IT")
                        
                        let expirationDate = date1Formatter.date(from: offerta.expirationeDate!)
                        if expirationDate! < currentDate! {
                            ref.child("orderReceived/" + (self.user?.idApp)! + "/" + offerta.orderAutoId).updateChildValues(["offerState" : "Scaduta"])
                            ref.child("orderOffered/" + (offerta.userSender?.idApp)! + "/" + offerta.idOfferta!).updateChildValues(["offerState" : "Scaduta"])
                            offerta.offerState = "Scaduta"
                            let msg = "Il prodotto che hai offerto a \((self.user?.fullName)!) è scaduto"
                            NotitificationsCenter.sendNotification(userDestinationIdApp: (offerta.userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                            self.updateNumberPendingProductsOnFireBase((offerta.userSender?.idApp)!, recOrPurch: "purchased")
                            let center = UNUserNotificationCenter.current()
                            center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+offerta.idOfferta!, "RememberExpiration-"+offerta.idOfferta!])
                        }
                    })
                }
                if offerta.paymentState == "Valid" && offerta.offerState != "Offerta rifiutata" && offerta.offerState != "Offerta inoltrata" {
                    self.ordersReceived.append(offerta)
                }
                
                //if consumption is before expirationDate, scheduled notification is killed
                if offerta.offerState == "Offerta consumata" {
                    //attenzione killa ogni volta che carica le offeerte, deve farlo una volta
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+offerta.idOfferta!,"RememberExpiration-"+offerta.idOfferta!])
                    print("scheduled notification killed")
                }
            }
            self.ordersReceived.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})
           
            self.readUserSender(onCompletion: {
                self.readProductsSentDetails(ordersToRead: self.ordersReceived ,onCompletion: {
                    onCompletion(self.ordersReceived)
                })
            })
        })
    }
    
    private func readUserSender(onCompletion: @escaping ()->()){
        let ref = Database.database().reference()
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
        let ref = Database.database().reference()
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
        let ref = Database.database().reference()
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

    private func timestampTodateObject(timestamp: TimeInterval)->Date {
        
        let date = NSDate(timeIntervalSince1970: timestamp/1000)
        
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let dateString = dateFormatter.string(from: date as Date)
        return dateFormatter.date(from: dateString)!
    }
    
    private func stringTodateObject(date: String)->Date {
        
        
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        //let dateString = dateFormatter.string(from: date as Date)
        
        return dateFormatter.date(from: date)!
        
    }
    
    //func updateStateOnFirebase (order: Order, state: String){
    func updateStateOnFirebase (userIdApp: String, userSenderIdApp: String, idOrder: String, autoIdOrder: String, state: String){
        
        FireBaseAPI.updateNode(node: "orderReceived/" + userIdApp + "/" + autoIdOrder, value: ["orderReaded" : "true", "offerState":state])
        FireBaseAPI.updateNode(node: "orderOffered/" + userSenderIdApp + "/" + idOrder, value: ["offerState":state])
        
        /*
        FireBaseAPI.updateNode(node: "orderReceived/" + (self.user?.idApp)! + "/" + order.orderAutoId, value: ["orderReaded" : "true", "offerState":state])
        FireBaseAPI.updateNode(node: "orderOffered/" + (order.userSender?.idApp)! + "/" + order.idOfferta!, value: ["offerState":state])*/
        
    }
    
    func deleteOrderReceveidOnFirebase(order: Order){
        let ref = Database.database().reference()
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
    func readUserIdAppFromIdFB(node:String, child: String, idFB:String?, onCompletion: @escaping (String?,String?)->()){
        FireBaseAPI.readKeyForValueEqualTo(node: node, child: child, value: idFB, onCompletion: { (error,idApp) in
            guard error == nil else {
                onCompletion(error,idApp)
                return
            }
            onCompletion(error,idApp)
        })
    }
    
    func acceptOrder(state: String, userFullName: String, userIdApp: String, userSenderIdApp: String,idOrder: String, autoIdOrder: String){
        
        FirebaseData.sharedIstance.updateStateOnFirebase(userIdApp: userIdApp, userSenderIdApp: userSenderIdApp, idOrder: idOrder, autoIdOrder: autoIdOrder, state: state)
        
        let msg = "Il tuo amico " + userFullName  + " ha accettato il tuo ordine"
        
        NotitificationsCenter.sendNotification(userDestinationIdApp:userSenderIdApp, msg: msg, controlBadgeFrom: "purchased")
        
        FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase(userSenderIdApp, recOrPurch: "purchased")
    }
    
    func refuseOrder(state: String, userFullName: String, userIdApp: String, userSenderIdApp: String,idOrder: String, autoIdOrder: String) {
       
        FirebaseData.sharedIstance.updateStateOnFirebase(userIdApp: userIdApp, userSenderIdApp: userSenderIdApp, idOrder: idOrder, autoIdOrder: autoIdOrder, state: state)
        
        let msg = "Il tuo amico " + userFullName  + " ha rifiutato il tuo ordine"
        NotitificationsCenter.sendNotification(userDestinationIdApp: userSenderIdApp, msg: msg, controlBadgeFrom: "purchased")

        FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase(userSenderIdApp, recOrPurch: "purchased")
    }

}
