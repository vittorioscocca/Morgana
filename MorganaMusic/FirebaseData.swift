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

extension UIApplication
{
    class func topViewController(_ base: UIViewController?) -> UIViewController?
    {
        if let nav = base as? UINavigationController
        {
            return topViewController(nav.visibleViewController)
            
        }
        
        if let tab = base as? UITabBarController
        {
            if let selected = tab.selectedViewController
            {
               return topViewController(selected)
            }
        }
        
        if let presented = base?.presentedViewController
        {
            return topViewController(presented)
        }
        return base
    }
}

extension NSNotification.Name {
    public static let FireBaseDataUserReadedNotification = NSNotification.Name("FireBaseDataUserReadedNotification")
}

class FirebaseData {
    
    static let sharedIstance = FirebaseData()
    // Firebase data is organaized as: orderSent, ordereReceived, orderPayment, productsSentDetails
    
    var user: User?
    var serverTime: TimeInterval? = nil
    
    var ordersSent: [Order]
    var ordersReceived: [Order]
    var companies: [Company]
    var lastOrderSentReadedTimestamp = UserDefaults.standard
    var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    
    var paymentAutoId: String?
    
    var idOrder: [String]?
    
    let notificationCenter: NotificationCenter
    
    private init(){
        self.ordersSent = [Order]()
        self.ordersReceived = [Order]()
        
        self.idOrder = [String]()
        self.companies = [Company]()
        self.notificationCenter = NotificationCenter.default
    }
    
    private func updatePendingProducts(order: Order,badgeValue: Int?) {
        if order.userDestination?.idApp != (self.user?.idApp)! {
            var badgeValuePass = 0
            if badgeValue != nil {
                badgeValuePass = badgeValue!
            }
            FireBaseAPI.updateNode(node: "users/"+(self.user?.idApp)!, value: ["numberOfPendingPurchasedProducts" : badgeValuePass + 1])
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
            "orderReaded":"false",
            "consumingDate": "",
            "viewState": (order.viewState)!
        ]
    }
    
    private func saveOrdersSentOnFireBase (badgeValue: Int?, order: Order, onCompletion: @escaping ()->()){
        
        order.orderAutoId = FireBaseAPI.setId(node: "ordersSent/\((self.user?.idApp)!)/\((order.company?.companyId)!)")
        order.ordersSentAutoId = FireBaseAPI.setId(node: "ordersReceived/\((order.userDestination?.idApp)!)/\((order.company?.companyId)!)")
        
        var orderDetails = buildOrderDataDictionary(order: order)
        orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
        
        
        
        FireBaseAPI.saveNodeOnFirebase(node: "ordersSent/\((self.user?.idApp)!)/\((order.company?.companyId)!)/\(order.orderAutoId)", dictionaryToSave: orderDetails, onCompletion: {(error) in
            guard error == nil else {
                return
            }
            self.updatePendingProducts(order: order, badgeValue: badgeValue)
            self.idOrder?.append(order.orderAutoId)
            onCompletion()
        })
    }

    func saveCartOnFirebase(user: User, badgeValue: Int?,  onCompletion: @escaping ()->()){
        self.user = user
        var workItems = [DispatchWorkItem]()
        
        
        for order in Cart.sharedIstance.carrello{
            self.paymentAutoId = FireBaseAPI.setId(node: "pendingPayments/\((self.user?.idApp)!)/\((order.company?.companyId)!)")
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
                    self.savePaymentOnFireBase(companyId:(order.company?.companyId)!,onCompletion: {
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
    
    private func saveOrderDetails(currentDetails: [String:String],companyId: String, autoId_ordersSent: String){
        FireBaseAPI.saveNodeOnFirebase(node: "productsOffersDetails/\(companyId)/\(autoId_ordersSent)", dictionaryToSave: currentDetails, onCompletion: { (error) in
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

            self.saveOrderDetails(currentDetails: currentDetails!, companyId: (order.company?.companyId)!, autoId_ordersSent: autoId_ordersSent!)
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
        offerDetails["consumingDate"] = ""
        
        
        return offerDetails
    }
    
    private func saveOrderOnFirebase(orderDetails: [String:Any],companyId: String,onCompletion: @escaping ()->()) {
        
        FireBaseAPI.saveNodeOnFirebase(node: "ordersReceived/\(orderDetails["IdAppUserDestination"]! as! String)/\(companyId)/\(orderDetails["autoId"] as! String)", dictionaryToSave: orderDetails, onCompletion: { (error) in
            guard error == nil else {
                print("read error on Firebase")
                return
            }
            FireBaseAPI.updateNode(node: "ordersReceived/\(orderDetails["IdAppUserDestination"]! as! String)/\(companyId)", value: ["scanningQrCode":false])
            
        })
    }
    
    func saveOrderAsReceivedOnFireBase(order: Order) {
        var orderDetails = buildOrderDetailsReceivedDictionary(order:order)
    
        orderDetails["offerState"] = updateOfferState(orderDetails: orderDetails)
        saveOrderOnFirebase(orderDetails: orderDetails, companyId: (order.company?.companyId)!, onCompletion: {
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
    
    private func buildPendingPayment(companyId: String,paymentDictionaryDetails: [String:Any])->Payment {
        
        let payment = Payment(platform: "", paymentType: "", createTime: "", idPayment: "", statePayment: "", autoId: "",total: "")
       
        payment.autoId = self.paymentAutoId!
        for orderID in self.idOrder! {
            payment.relatedOrders.append(orderID)
        }
        payment.idPayment = paymentDictionaryDetails["idPayment"] as? String
        payment.statePayment = paymentDictionaryDetails["statePayment"] as? String
        payment.total = paymentDictionaryDetails["total"] as? String
        payment.pendingUserIdApp = paymentDictionaryDetails["pendingUserIdApp"] as! String
        payment.company?.companyId = companyId
        
        self.idOrder?.removeAll()
        return payment
        
    }
    
    private func savePaymentOnFireBase (companyId: String, onCompletion: @escaping ()->()){
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
        
        let payment = buildPendingPayment(companyId: companyId, paymentDictionaryDetails: paymentDictionaryDetails)
        
        FireBaseAPI.saveNodeOnFirebase(node: "pendingPayments/\((self.user?.idApp)!)/\(companyId)/\((self.paymentAutoId)!)", dictionaryToSave: paymentDictionaryDetails, onCompletion: { (error) in
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
                NotificationsCenter.scheduledExpiratedOrderLocalNotification(title: "Ordine scaduto", body: "Il prodotto che hai offerto a \((order.userDestination?.fullName)!) è scaduto", identifier: order.idOfferta!, expirationDate: self.stringTodateObject(date: order.expirationeDate!))
                print("Notifica scadenza schedulata correttamente")
                order.orderNotificationIsScheduled = true
                FireBaseAPI.updateNode(node: "ordersSent/\((self.user?.idApp)!)/\((order.company?.companyId)!)/\(order.idOfferta!)", value: ["orderNotificationIsScheduled":true])
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
    
    func mangeExiredOffers(timeStamp:TimeInterval, order: Order, ref: DatabaseReference){
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
            ref.child("ordersSent/\((self.user?.idApp)!)/\((order.company?.companyId)!)/\(order.idOfferta!)").updateChildValues(["offerState" : "Scaduta"])
            ref.child("ordersReceived/\((order.userDestination?.idApp)!)/\((order.company?.companyId)!)/\(order.ordersSentAutoId)").updateChildValues(["offerState" : "Scaduta"])
            
            let msg = "Il prodotto che ti è stato offerto da \((self.user?.fullName)!) è scaduto"
            NotificationsCenter.sendNotification(userDestinationIdApp: (order.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
            self.updateNumberPendingProductsOnFireBase((order.userDestination?.idApp)!, recOrPurch: "received")
        }
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
            
            let orderDictionary = snap.value! as? NSDictionary
            for (companyId,dataOrder) in orderDictionary! {
                
                for (id_offer, orderData) in dataOrder as! NSDictionary{
                    let order: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                    order.company?.companyId = companyId as? String
                    order.idOfferta = id_offer as? String
                    order.orderAutoId = (id_offer as? String)!
                    let orderDataDictionary = orderData as? NSDictionary
                    
                    //filtering deleted data
                    if orderDataDictionary?["viewState"] as? String != "deleted" {
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
                        order.consumingDate = orderDataDictionary?["consumingDate"] as? String
                        order.viewState = orderDataDictionary?["viewState"] as? String
                        
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
                        //filtering expired data
                        if order.offerState != "Scaduta" {
                            self.scheduleExpiryNotification(order: order)
                            if self.serverTime == nil {
                                ref.child("sessions").setValue(ServerValue.timestamp())
                                ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
                                    let timeStamp = snap.value! as! TimeInterval
                                    self.serverTime = timeStamp
                                    self.mangeExiredOffers(timeStamp: self.serverTime!, order: order, ref: ref)
                                    
                                })
                            }else {
                                self.mangeExiredOffers(timeStamp: self.serverTime!, order: order, ref: ref)
                            }
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
                }
            }
            self.ordersSent.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})
            
            self.readProductsSentDetails(ordersToRead: self.ordersSent,onCompletion: {
                self.notificationCenter.post(name: .FireBaseDataUserReadedNotification, object: nil)
                onCompletion(self.ordersSent)
            })
        })
    }
    
    private func manageExpirationOrder(order: Order){
        let ref = Database.database().reference()
        if order.offerState != "Scaduta" {
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
                
                let expirationDate = date1Formatter.date(from: order.expirationeDate!)
                if expirationDate! < currentDate! {
                    ref.child("ordersReceived/\((self.user?.idApp)!)/\((order.company?.companyId)!)/\(order.orderAutoId)").updateChildValues(["offerState" : "Scaduta"])
                    ref.child("ordersSent/\((order.userSender?.idApp)!)/\((order.company?.companyId)!)/\(order.idOfferta!)").updateChildValues(["offerState" : "Scaduta"])
                    order.offerState = "Scaduta"
                    let msg = "Il prodotto che hai offerto a \((self.user?.fullName)!) è scaduto"
                    NotificationsCenter.sendNotification(userDestinationIdApp: (order.userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                    self.updateNumberPendingProductsOnFireBase((order.userSender?.idApp)!, recOrPurch: "purchased")
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+order.idOfferta!, "RememberExpiration-"+order.idOfferta!])
                }
            })
        }
    }
    
    private func readOrder(order:Order,controlExpirationDate: Bool, dataOrder: NSDictionary) {
        
        for (chiave,valore) in dataOrder {
            switch chiave as! String {
            case "expirationDate":
                order.expirationeDate = valore as? String
                break
            case "paymentState":
                order.paymentState = valore as? String
                break
            case "offerState":
                order.offerState = valore as? String
                break
            case "offerCreationDate":
                order.dataCreazioneOfferta = valore as? String
                break
            case "offerId":
                order.idOfferta = valore as? String
                break
            case "userSender":
                order.userSender?.idApp = valore as? String
                break
            case "timestamp":
                order.timeStamp = (valore as? TimeInterval)!
                break
            case "IdAppUserDestination":
                order.userDestination?.idApp = valore as? String
                break
            case "orderReaded":
                if (valore as? String) == "false" {
                    order.orderReaded = false
                } else {order.orderReaded = true}
                break
            case "orderNotificationIsScheduled":
                order.orderNotificationIsScheduled = (valore as? Bool)!
                break
            case "orderExpirationNotificationIsScheduled":
                order.orderExpirationNotificationIsScheduled = (valore as? Bool)!
                break
            case "total":
                order.totalReadedFromFirebase = (valore as? String)!
                break
            case "consumingDate":
                order.consumingDate = valore as? String
                break
            case "viewState" :
                order.viewState = valore as? String
                break
            default:
                break
            }
        }
        if controlExpirationDate {
            self.manageExpirationOrder(order: order)
        }
       
    }
    
    func readOrderReceivedOnFireBase(user: User, onCompletion: @escaping ([Order])->()) {
        let ref = Database.database().reference()
        self.user = user
        ref.child("ordersReceived/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            self.ordersReceived.removeAll()
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let dizionario_offerte = snap.value! as! NSDictionary
            
            for (companyId,dataOrder) in dizionario_offerte {
                
                // leggo i dati dell'ordine o offerte
                var order: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                
                for (orderId, dati_pendingOffers) in dataOrder as! NSDictionary {
                    if orderId as? String != "scanningQrCode" {
                        order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                        order.company?.companyId = companyId as? String
                        order.orderAutoId = orderId as! String
                        self.readOrder(order: order,controlExpirationDate: true, dataOrder: dati_pendingOffers as! NSDictionary)
                        if order.viewState != "deleted" {
                            if order.paymentState == "Valid" && order.offerState != "Offerta rifiutata" && order.offerState != "Offerta inoltrata" {
                                self.ordersReceived.append(order)
                            }
                            //if consumption is before expirationDate, scheduled notification is killed
                            if order.offerState == "Offerta consumata" {
                                //attenzione killa ogni volta che carica le offeerte, deve farlo una volta
                                let center = UNUserNotificationCenter.current()
                                center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+order.idOfferta!,"RememberExpiration-"+order.idOfferta!])
                                print("scheduled notification killed")
                            }
                        }
                        
                    } else if (dati_pendingOffers as? Bool)! == true {
                        
                        let activeViewController = UIApplication.topViewController(UIApplication.shared.keyWindow?.rootViewController?.childViewControllers[1])
                        if activeViewController is QROrderGenerationViewController {
                            (activeViewController as! QROrderGenerationViewController).unwind()
                        }
                        FireBaseAPI.updateNode(node: "ordersReceived/\((self.user?.idApp)!)/\(companyId)", value: ["scanningQrCode":false])
                    }
                }
            }
            self.ordersReceived.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})

            self.readUserSender(ordersToRead: self.ordersReceived, onCompletion: {
                self.readProductsSentDetails(ordersToRead: self.ordersReceived, onCompletion: {
                    self.notificationCenter.post(name: .FireBaseDataUserReadedNotification, object: nil)
                    onCompletion(self.ordersReceived)
                })
            })
        })
    }
    
    func readSingleOrder (userId: String, companyId: String, orderId: String, onCompletion: @escaping ([Order])->()){
        var orders: [Order] = []
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "ordersReceived/\(userId)/\(companyId)/\(orderId)", onCompletion: { (error,dictionary) in
            guard error == nil else {
                print("Errore di connessione")
                return
            }
            guard dictionary != nil else {
                print("Errore di lettura del dell'Ordine richiesto")
                return
            }
            let order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
            order.company?.companyId = companyId
            order.orderAutoId = orderId
            self.readOrder(order: order, controlExpirationDate: false, dataOrder: dictionary! as NSDictionary)
            orders.append(order)
            self.readUserSender(ordersToRead: orders, onCompletion: {
                self.readProductsSentDetails(ordersToRead: orders, onCompletion: {
                    onCompletion(orders)
                })
            })
        })
    }
    
    private func readUserSender(ordersToRead: [Order], onCompletion: @escaping ()->()){
        var node = String()
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.xcoding.queueReadUsers", attributes: .concurrent, target: .main)
        
        print("Orders Received contiene \(self.ordersReceived.count) ordini")
        for singleOrder in ordersToRead{
            node = "users/" + (singleOrder.userSender?.idApp)!
            print("user sender letto", (singleOrder.userSender?.idApp)! )
            
            //dispatchGroup.enter()
            //queue.async(group: dispatchGroup){
                FireBaseAPI.readNodeOnFirebaseWithOutAutoIdHandler(node: node, beginHandler: {
                    dispatchGroup.enter()
                    queue.async(group: dispatchGroup){
                        print("user letto", node)
                    }
                }, completionHandler: {(error, userData) in
                        guard error == nil else {return}
                        guard userData != nil else {return}
                        singleOrder.userSender?.fullName = userData!["fullName"] as? String
                        singleOrder.userSender?.pictureUrl = userData!["pictureUrl"] as? String
                        dispatchGroup.leave()
                })
            //}
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("group operation ended")
            onCompletion()
        }
    }
    
    private func readProductsSentDetails(ordersToRead: [Order], onCompletion: @escaping ()->()) {
        
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.xcoding.queueReadProductsSentDetails", attributes: .concurrent, target: .main)
        
        for singleOrder in ordersToRead{
            let node = "productsOffersDetails/\((singleOrder.company?.companyId)!)/\(singleOrder.idOfferta!)"
            
            
            //readNodeOnFireBase con Autoid
                FireBaseAPI.readNodeOnFirebaseWithOutAutoIdHandler(node: node, beginHandler: {
                    dispatchGroup.enter()
                    queue.async(group: dispatchGroup){
                        print("eseguo lettura Dettaglio Ordini")
                    }
                }, completionHandler: { (error, productData) in
                    
                    guard error == nil else {return}
                    guard productData != nil else {return}
                    
                    var product: Product = Product(productName: nil, price: nil, quantity: nil)
                    singleOrder.prodotti?.removeAll()
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
                                print("numero prodotti \((singleOrder.prodotti?.count)!)")
                                product = Product(productName: nil, price: nil, quantity: nil)
                            }
                            
                        }
                    }
                    dispatchGroup.leave()
                })
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("lettura prodotti terminata")
            onCompletion()
        }
    }
    
    func updateNumberPendingProductsOnFireBase(_ idAppUserDestination: String, recOrPurch: String){
        let ref = Database.database().reference()
        ref.child("users/" + idAppUserDestination).observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            var badgeValueToUpdate = ""
            if recOrPurch == "received" {
                badgeValueToUpdate = "numberOfPendingReceivedProducts"
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
    func updateStateOnFirebase (userIdApp: String, userSenderIdApp: String, comapanyId: String, idOrder: String, autoIdOrder: String, state: String){
        
        FireBaseAPI.updateNode(node: "ordersReceived/\(userIdApp)/\(comapanyId)/\(autoIdOrder)", value: ["orderReaded" : "true", "offerState":state])
        FireBaseAPI.updateNode(node: "ordersSent/\(userSenderIdApp)/\(comapanyId)/\(idOrder)", value: ["offerState":state])
    }
    
    func deleteOrderOnFirebase(node: String,userIdApp: String, comapanyId: String, autoIdOrder: String, viewState: String){
        
        //ref.child("ordersReceived/" + (order.userDestination?.idApp)! + "/" + order.orderAutoId).removeValue()
        FireBaseAPI.updateNode(node: "\(node)/\(userIdApp)/\(comapanyId)/\(autoIdOrder)", value: ["viewState":viewState])
    }
    
    /*
    func deleteOrderPurchasedOnFireBase(order: Order){
        //remove ordersSent
        FireBaseAPI.removeNode(node: "ordersSent/\((self.user?.idApp)!)/\((order.company?.companyId)!)", autoId: order.orderAutoId)
        //remove Payement
        FireBaseAPI.removeNode(node: "pendingPayments/\((self.user?.idApp)!)/\((order.company?.companyId)!)", autoId: order.orderAutoId)
        //remove products Details
        FireBaseAPI.removeNode(node: "productsOffersDetails/\((order.company?.companyId)!)", autoId: order.orderAutoId)
    }*/
    
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
    
    //function  return node from his Facebook iD
    func readNodeFromIdFB(node:String, child: String, idFB:String?, onCompletion: @escaping (String?,[String:Any]?)->()){
        FireBaseAPI.readNodeForValueEqualTo(node: node, child: child, value: idFB, onCompletion: { (error,dictionary) in
            guard error == nil else {
                onCompletion(error,nil)
                return
            }
            onCompletion(error,dictionary)
        })
    }
    
    
    func readUserCityOfRecidenceFromIdFB(node:String,  onCompletion: @escaping (String?,String?)->()){
        
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: node, onCompletion: { (error,dictionary) in
            guard error == nil else {
                onCompletion(error,dictionary?["cityOfRecidence"] as? String)
                return
            }
            onCompletion(error,dictionary?["cityOfRecidence"] as? String)
        })
    }
    
    func acceptOrder(state: String, userFullName: String, userIdApp: String, comapanyId: String,userSenderIdApp: String,idOrder: String, autoIdOrder: String){
        FirebaseData.sharedIstance.updateStateOnFirebase(userIdApp: userIdApp, userSenderIdApp: userSenderIdApp,comapanyId: comapanyId, idOrder: idOrder, autoIdOrder: autoIdOrder, state: state)
        let msg = "Il tuo amico " + userFullName  + " ha accettato il tuo ordine"
        NotificationsCenter.sendOrderAcionNotification(userDestinationIdApp:userSenderIdApp, msg: msg, controlBadgeFrom: "purchased")
        FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase(userSenderIdApp, recOrPurch: "purchased")
    }
    
    func refuseOrder(state: String, userFullName: String, userIdApp: String, comapanyId: String, userSenderIdApp: String,idOrder: String, autoIdOrder: String) {
        FirebaseData.sharedIstance.updateStateOnFirebase(userIdApp: userIdApp, userSenderIdApp: userSenderIdApp,comapanyId:comapanyId, idOrder: idOrder, autoIdOrder: autoIdOrder, state: state)
        let msg = "Il tuo amico " + userFullName  + " ha rifiutato il tuo ordine"
        NotificationsCenter.sendOrderAcionNotification(userDestinationIdApp: userSenderIdApp, msg: msg, controlBadgeFrom: "purchased")
        FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase(userSenderIdApp, recOrPurch: "purchased")
    }
    
    func changeSchedulationBirthday(scheduledBirthdayNotification: Date, idApp:String,notificationIdentifier:String ){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
        dateFormatter.locale = Locale(identifier: "it_IT")
        
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(abbreviation: "GMT+0:00")!
        var components = gregorian.dateComponents([.year, .month, .day], from: scheduledBirthdayNotification)
        
        components.year = components.year! + 1
        
        let nextScheduledBirthdayNotification = dateFormatter.string(from: gregorian.date(from: components)!)
        
        FireBaseAPI.saveNodeOnFirebase(node: "merchantOrder/mr001/\(idApp)/birthday/\(notificationIdentifier)", dictionaryToSave: ["birthdayScheduledNotification":nextScheduledBirthdayNotification,"schedulationType":"acceptSettings"], onCompletion:{_ in
            print("Offerta crediti accettata e prossima Data di notifica  aggiornata al \(nextScheduledBirthdayNotification)")
        })
    }

}
