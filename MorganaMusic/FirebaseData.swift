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
    
    var paymentAutoId: String?
    
    var idOrder: [String]?
    
    private init(){
        self.ordersSent = [Order]()
        self.ordersReceived = [Order]()
        
        self.idOrder = [String]()
        self.companies = [Company]()
    }
    
    private func updatePendingProducts(order: Order,badgeValue: Int ) {
        if order.userDestination?.idApp != (self.user?.idApp)! {
            FireBaseAPI.updateNode(node: "users/"+(self.user?.idApp)!, value: ["numberOfPendingPurchasedProducts" : badgeValue + 1])
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
            "ordersSentAutoId" : order.ordersSentAutoId,
            "orderNotificationIsScheduled": order.orderNotificationIsScheduled!,
            "orderAutoId": order.orderAutoId,
            "pendingPaymentAutoId": self.paymentAutoId!,
            "userSender": (self.user?.idApp)!,
            "orderReaded":"false"
        ]
    }
    
    private func saveOrdersSentOnFireBase (badgeValue: Int, order: Order, onCompletion: @escaping ()->()){
        
        order.orderAutoId = FireBaseAPI.setId(node: "ordersSent/\((self.user?.idApp)!)")
        order.ordersSentAutoId = FireBaseAPI.setId(node: "ordersReceived/\((order.userDestination?.idApp)!)")
        
        var orderDetails = buildOrderDataDictionary(order: order)
        orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
        
        
        
        FireBaseAPI.saveNodeOnFirebaseWithPassedAutoId(node: "ordersSent", child: (self.user?.idApp)!, passedAutoId: order.orderAutoId, dictionaryToSave: orderDetails, onCompletion: {(error) in
            guard error == nil else {
                return
            }
            self.updatePendingProducts(order: order, badgeValue: badgeValue)
            self.idOrder?.append(order.orderAutoId)
            onCompletion()
        })
    }
    
    private func saveOrderDictionaryStoredOnFirebase(onCompletion: @escaping ([String:Any])->()) {
        FireBaseAPI.readNodeOnFirebaseQueryLimited(node: "ordersSent/"+(self.user?.idApp)!, queryLimit: Cart.sharedIstance.carrello.count, onCompletion: { (error, dictionary) in
            guard error == nil else {return}
            guard dictionary != nil else {return}
            //self.idOrder?.append(dictionary?["autoId"] as! String)
            onCompletion(dictionary!)
        })
    }

    func saveCartOnFirebase(user: User, badgeValue: Int,  onCompletion: @escaping ()->()){
        self.user = user
        var workItems = [DispatchWorkItem]()
        self.paymentAutoId = FireBaseAPI.setId(node: "pendingPayments/\((self.user?.idApp)!)")
        
        for order in Cart.sharedIstance.carrello{
            let dispatchItem = DispatchWorkItem.init {
                self.saveOrdersSentOnFireBase(badgeValue: badgeValue,order: order, onCompletion: {
                    print("OFFERTA SALVATA")
                })
            }
            dispatchItem.notify(queue: DispatchQueue.main, execute: {
                //qui ci va il begin e complete handler poichè notify non sa quando finisce davvero il workitem
                print("FINE")
                self.saveProductOnFireBase(order: order)
                self.saveOrderAsReceivedOnFireBase(order: order)
                if self.idOrder?.count == Cart.sharedIstance.carrello.count {
                    self.savePaymentOnFireBase(onCompletion: {
                        onCompletion()
                        print("Payment Saved on Firebase")
                        //return
                    })
                }
            })
            workItems.append(dispatchItem)
        }
        
        let queue = DispatchQueue.init(label: "it.morgana.queue")
        for i in 0...workItems.count-1 {
            queue.async {
                let currentWorkItem = workItems[i]
                currentWorkItem.perform()
            }
        }
        
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
    
    private func saveOrderDetails(currentDetails: [String:String], autoId_ordersSent: String){
        FireBaseAPI.saveNodeOnFirebaseWithAutoId(node: "productsOffersDetails", child: autoId_ordersSent, dictionaryToSave: currentDetails, onCompletion: { (error) in
            guard error == nil else {
                return
            }
            print("offer Details saved")
        })
    }
    
    private func prepareProductDetails(order: Order, onCompletion: @escaping ([String:String]?, String?)->()) {
        var idFBFriend: String?
        var creationDate: String?
        var autoId_ordersSent: String?
        
         idFBFriend = (order.userDestination?.idFB)!
         creationDate = order.dataCreazioneOfferta!
         autoId_ordersSent = order.orderAutoId
        
        let currentDetails = self.buildProductOrderDetailsDictionary(idFBFriend: idFBFriend, creationDate: creationDate)
        onCompletion(currentDetails, autoId_ordersSent)
    }
    
    private func saveProductOnFireBase(order: Order){
        prepareProductDetails(order: order, onCompletion: {(currentDetails, autoId_ordersSent) in
            guard currentDetails != nil, autoId_ordersSent != nil else {
                print("[DETTAGLIO ORDINI]: problema di salvataggio")
                return
            }

            self.saveOrderDetails(currentDetails: currentDetails!, autoId_ordersSent: autoId_ordersSent!)
        })
    }
    
    //SAVE ORDER AS RECEIVED ON FIREBASE
    private func buildOrderDetailsReceivedDictionary(order:Order)->[String:Any]{
        var offerDetails: [String:Any] = buildOrderDataDictionary(order: order)
        
        // leggo i dati dell'ordine o offerte
        offerDetails["offerId"] = order.orderAutoId
        offerDetails["autoId"] = order.ordersSentAutoId
        offerDetails.removeValue(forKey: "ordersSentAutoId")
        offerDetails.removeValue(forKey: "orderAutoId")
        offerDetails.removeValue(forKey: "pendingPaymentAutoId")
        offerDetails["userSender"] = (self.user?.idApp)!
        offerDetails["orderReaded"] = "false"
        offerDetails["orderExpirationNotificationIsScheduled"] = false
        
        return offerDetails
    }
    
    private func saveOrderOnFirebase(orderDetails: [String:Any],onCompletion: @escaping ()->()) {
        FireBaseAPI.saveNodeOnFirebaseWithPassedAutoId(node: "ordersReceived", child: orderDetails["IdAppUserDestination"]! as! String, passedAutoId: orderDetails["autoId"] as! String, dictionaryToSave: orderDetails, onCompletion: { (error) in
            guard error == nil else {
                print("read error on Firebase")
                return
            }
            onCompletion()
        })
    }
    
    func saveOrderAsReceivedOnFireBase(order: Order) {
        var orderDetails = buildOrderDetailsReceivedDictionary(order:order)
    
        orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
        saveOrderOnFirebase(orderDetails: orderDetails, onCompletion: {
            print("Ordine ricevuto salvato")
        })
    }
    
    //SAVE PAYMENT ON FIREBAASE
    private func buildPaymentIdOrders()->[String:Any]{
        var paymentDictionaryDetails = [String:Any]()
        for numberOfpaymentIdOrders in 0...(idOrder?.count)! - 1 {
            paymentDictionaryDetails["offerID"+String(numberOfpaymentIdOrders)] = idOrder?[numberOfpaymentIdOrders]
        }
        return paymentDictionaryDetails
    }
    
    private func buildPendingPayment(paymentDictionaryDetails: [String:Any])->Payment {
        
        let payment = Payment(platform: "", paymentType: "", createTime: "", idPayment: "", statePayment: "", autoId: "",total: "")
       
        payment.autoId = self.paymentAutoId!
        for orderID in self.idOrder! {
            payment.relatedOrders.append(orderID)
        }
        payment.idPayment = paymentDictionaryDetails["idPayment"] as? String
        payment.statePayment = paymentDictionaryDetails["statePayment"] as? String
        payment.total = paymentDictionaryDetails["total"] as? String
        payment.pendingUserIdApp = paymentDictionaryDetails["pendingUserIdApp"] as! String
        
        self.idOrder?.removeAll()
        return payment
        
    }
    
    private func savePaymentOnFireBase (onCompletion: @escaping ()->()){
        var paymentDictionaryDetails = buildPaymentIdOrders()
        
        
        paymentDictionaryDetails["idPayment"] = Cart.sharedIstance.paymentMethod?.idPayment
        paymentDictionaryDetails["createTime"] = Cart.sharedIstance.paymentMethod?.createTime
        paymentDictionaryDetails["paymentType"] = Cart.sharedIstance.paymentMethod?.paymentType
        paymentDictionaryDetails["platform"] = Cart.sharedIstance.paymentMethod?.platform
        paymentDictionaryDetails["statePayment"] = Cart.sharedIstance.paymentMethod?.statePayment
        paymentDictionaryDetails["totalProducts"] = String(Cart.sharedIstance.prodottiTotali)
        paymentDictionaryDetails["total"] = String(format:"%.2f", Cart.sharedIstance.costoTotale)
        paymentDictionaryDetails["stateCartPayment"] = Cart.sharedIstance.state
        paymentDictionaryDetails["pendingUserIdApp"] = (self.user?.idApp)!
        
        let payment = buildPendingPayment(paymentDictionaryDetails: paymentDictionaryDetails)
        
        FireBaseAPI.saveNodeOnFirebaseWithPassedAutoId(node: "pendingPayments", child: (self.user?.idApp)!, passedAutoId: self.paymentAutoId!, dictionaryToSave: paymentDictionaryDetails, onCompletion: { (error) in
            guard error == nil else {return}
            
            //solve pending payments
            PaymentManager.sharedIstance.resolvePendingPayPalPayment(user: self.user!, payment: payment, onCompleted: { (verifiedPayment) in
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
        
    }
    
    private func scheduleExpiryNotification(order: Order){
        //scheduling notification appearing in expirationDate
        if !order.orderNotificationIsScheduled! {
            DispatchQueue.main.async {
                NotitificationsCenter.scheduledExpiratedOrderLocalNotification(title: "Ordine scaduto", body: "Il prodotto che hai offerto a \((order.userDestination?.fullName)!) è scaduto", identifier: order.idOfferta!, expirationDate: self.stringTodateObject(date: order.expirationeDate!))
                print("Notifica scadenza schedulata correttamente")
                order.orderNotificationIsScheduled = true
                FireBaseAPI.updateNode(node: "ordersSent/"+(self.user?.idApp)!+"/"+order.idOfferta!, value: ["orderNotificationIsScheduled":true])
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

    //READ ORDERS ON FIREBASE
    func readOrdersSentOnFireBase(user: User, friendsList: [Friend]?,onCompletion: @escaping ([Order])->()){
        self.user = user
        let ref = Database.database().reference()
        self.ordersSent.removeAll()
        
        ref.child("ordersSent/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.ordersSent.removeAll()
            
            let orderDictionary = snap.value! as! NSDictionary
            
            for (id_offer, orderData) in orderDictionary{
                
                let order: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                
                order.idOfferta = id_offer as? String
                
                let orderDataDictionary = orderData as? NSDictionary
                
                order.expirationeDate = orderDataDictionary?["expirationDate"] as? String
                order.paymentState = orderDataDictionary?["paymentState"] as? String
                order.offerState = orderDataDictionary?["offerState"] as? String
                order.userDestination?.idFB = orderDataDictionary?["facebookUserDestination"] as? String
                order.dataCreazioneOfferta = orderDataDictionary?["offerCreationDate"] as? String
                order.userDestination?.idApp = orderDataDictionary?["IdAppUserDestination"] as? String
                order.timeStamp = orderDataDictionary?["timestamp"] as! TimeInterval
                order.pendingPaymentAutoId = orderDataDictionary?["pendingPaymentAutoId"] as! String
                order.ordersSentAutoId = orderDataDictionary?["ordersSentAutoId"] as! String
                order.userSender?.idApp = orderDataDictionary?["userSender"] as? String
                order.orderNotificationIsScheduled = orderDataDictionary?["orderNotificationIsScheduled"] as? Bool
                
                if  orderDataDictionary?["orderReaded"] as? String == "true"{
                    order.orderReaded = true
                } else {
                    order.orderReaded = false
                }
                
                if order.userDestination?.idFB == self.user?.idFB {
                    order.userDestination?.fullName = self.user?.fullName
                    order.userDestination?.pictureUrl = self.user?.pictureUrl
                    
                } else if !(friendsList?.isEmpty)! {
                        for friend in friendsList! {
                            if friend.idFB == order.userDestination?.idFB {
                                    order.userDestination?.fullName = friend.fullName
                                    order.userDestination?.pictureUrl = friend.pictureUrl
                                    break
                            }
                        }
                }
                
                if order.offerState != "Scaduta" {
                    self.scheduleExpiryNotification(order: order)
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
                        self.lastOrderSentReadedTimestamp.set(finalDate!, forKey: "ordersSentReadedTimestamp")
                        
                        let date1Formatter = DateFormatter()
                        date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
                        date1Formatter.locale = Locale.init(identifier: "it_IT")
                        
                        let dateObj = date1Formatter.date(from: order.expirationeDate!)
                        if dateObj! < finalDate! {
                            order.offerState = "Scaduta"
                            ref.child("ordersSent/" + (self.user?.idApp)! + "/" + order.idOfferta!).updateChildValues(["offerState" : "Scaduta"])
                            ref.child("ordersReceived/" + (order.userDestination?.idApp)! + "/" + order.ordersSentAutoId).updateChildValues(["offerState" : "Scaduta"])
                            
                            let msg = "Il prodotto che ti è stato offerto da \((self.user?.fullName)!) è scaduto"
                            NotitificationsCenter.sendNotification(userDestinationIdApp: (order.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
                            self.updateNumberPendingProductsOnFireBase((order.userDestination?.idApp)!, recOrPurch: "received")
                        }
                    })
                }
                if order.paymentState != "Valid"  {
                    self.ordersSent.append(order)
                }else if self.user?.idApp != order.userDestination?.idApp   {
                    self.ordersSent.append(order)
                }
                //if consumption is before expirationDate, scheduled notification is killed
                //attenzione lo fa ogni volta che legge
                if order.offerState == "Offerta consumata" {
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: [order.idOfferta!])
                    print("scheduled notification killed")
                }
            }
            self.ordersSent.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})
            
            self.readProductsSentDetails(ordersToRead: self.ordersSent,onCompletion: {(ordersSentElaborated) in
                onCompletion(ordersSentElaborated)
            })
        })
    }
    
    func readOrderReceivedOnFireBase(user: User, onCompletion: @escaping ([Order])->()) {
        let ref = Database.database().reference()
        self.ordersReceived.removeAll()
        self.user = user
        ref.child("ordersReceived/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            self.ordersReceived.removeAll()
            print()
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
                            ref.child("ordersReceived/" + (self.user?.idApp)! + "/" + offerta.orderAutoId).updateChildValues(["offerState" : "Scaduta"])
                            ref.child("ordersSent/" + (offerta.userSender?.idApp)! + "/" + offerta.idOfferta!).updateChildValues(["offerState" : "Scaduta"])
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
                self.readProductsSentDetails(ordersToRead: self.ordersReceived, onCompletion: { (ordersReceivedElaborated) in
                    onCompletion(ordersReceivedElaborated)
                })
            })
        })
    }
    
    private func readUserSender(onCompletion: @escaping ()->()){
        var node = String()
        
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.xcoding.queueReadUsers", attributes: .concurrent, target: .main)
        print("Orders Received contiene \(self.ordersReceived.count) ordini")
        for singleOrder in self.ordersReceived{
            
            node = "users/" + (singleOrder.userSender?.idApp)!
            
            FireBaseAPI.readNodeOnFirebaseWithOutAutoIdHandler(node: node, beginHandler: {
                dispatchGroup.enter()
                queue.async(group: dispatchGroup){
                    print("user letto")
                }
            }, completionHandler: {(error, userData) in
                    
                    guard error == nil else {return}
                    guard userData != nil else {return}
                
                    singleOrder.userSender?.fullName = userData!["fullName"] as? String
                    print("full name letto")
                    singleOrder.userSender?.pictureUrl = userData!["pictureUrl"] as? String
                    print("picturUrl letta")
                
                    print("letto uno user")
                    dispatchGroup.leave()
            })
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("group operation ended")
            onCompletion()
        }
        
    }
    
    private func readProductsSentDetails(ordersToRead: [Order], onCompletion: @escaping ([Order])->()) {
        var node = String()
        
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.xcoding.queueReadProductsSentDetails", attributes: .concurrent, target: .main)
        
        for singleOrder in ordersToRead{
            node = "productsOffersDetails/" + singleOrder.idOfferta!
            //readNodeOnFireBase con Autoid
            FireBaseAPI.readNodeOnFirebaseHandler(node: node, beginHandler: {
                dispatchGroup.enter()
                queue.async(group: dispatchGroup){
                    print("eseguo lettura")
                }
            }, onCompletion: { (error, productData) in
                
                guard error == nil else {return}
                guard productData != nil else {return}
                
                var product: Product = Product(productName: nil, price: nil, quantity: nil)
                
                for (chiave,valore) in productData! {
                    if chiave != "autoId" {
                        product.productName = chiave
                        print("nome prodotto letto")
                        let token = (valore as? String)?.components(separatedBy: "x")
                        product.quantity = Int((token?[0])!)
                        print("quantità letta")
                        product.price = Double((token?[1])!)
                        print("prezzo letto")
                        if (product.price != nil) && (product.productName != nil) && (product.quantity != nil){
                            singleOrder.prodotti?.append(product)
                            product = Product(productName: nil, price: nil, quantity: nil)
                        }
                        
                    }
                }
                dispatchGroup.leave()
                
            })
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("lettura prodotti terminata")
            onCompletion(ordersToRead)
        }
    }
    
    func updateNumberPendingProductsOnFireBase(_ idAppUserDestination: String, recOrPurch: String){
        let ref = Database.database().reference()
        ref.child("users/" + idAppUserDestination).observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            var badgeValueToUpdate = ""
            if recOrPurch == "received" {
                badgeValueToUpdate = "numberOf PendingReceivedProducts"
            } else if recOrPurch == "purchased" {
                badgeValueToUpdate = "numberOfPendingPurchasedProducts"
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

    //Date method
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
        
        FireBaseAPI.updateNode(node: "ordersReceived/" + userIdApp + "/" + autoIdOrder, value: ["orderReaded" : "true", "offerState":state])
        FireBaseAPI.updateNode(node: "ordersSent/" + userSenderIdApp + "/" + idOrder, value: ["offerState":state])
    }
    
    func deleteOrderReceveidOnFirebase(order: Order){
        let ref = Database.database().reference()
        ref.child("ordersReceived/" + (order.userDestination?.idApp)! + "/" + order.orderAutoId).removeValue()
    }
    
    func deleteOrderPurchasedOnFireBase(order: Order){
        //remove ordersSent
        FireBaseAPI.removeNode(node: "ordersSent/"+(self.user?.idApp)!, autoId: order.orderAutoId)
        
        //remove Payement
        FireBaseAPI.removeNode(node: "pendingPayments", autoId: order.orderAutoId)
        
        //remove products Details
        FireBaseAPI.removeNode(node: "productsOffersDetails", autoId: order.orderAutoId)
    }
    
    //migrates an order under another user
    func moveFirebaseRecord(userApp: User, user: UserDestination, order:Order, onCompletion: @escaping (String?)->()){
        let sourceNode = "ordersReceived/" + (user.idApp)!+"/"+order.ordersSentAutoId
        let destinationNode = "ordersReceived/" + (order.userDestination?.idApp)!+"/"+order.ordersSentAutoId
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
