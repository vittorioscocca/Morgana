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
    class func topViewController(_ base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        
        if let presented = base?.presentedViewController {
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
    
    var friendList: [Friend]?
    var ordersSent: [Order]
    var ordersReceived: [Order]
    
//    var totalNumberOrdersSent = 0
//    var totalNumberOrdesReceived = 0
//    var totalNumberOrdersSentReaded = 0
//    var totalNumberOrdesReceivedReaded = 0
    
    var companies: [Company]
    var lastOrderSentReadedTimestamp = UserDefaults.standard
    var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    private let ref = Database.database().reference()
    private var paymentAutoId: String?
    
    private let companyID = "mr001"
//    static let DIM_PAGE_SCROLL: UInt = 10
    private var firstKnownKeyOrderSent: String?
    private var firstKnownKeyOrderReceived: String?
    fileprivate var _refHandle: DatabaseHandle!
    private var idOrder: [String]?
    private let notificationCenter: NotificationCenter
    
    private init(){
        ordersSent = [Order]()
        ordersReceived = [Order]()
        idOrder = [String]()
        companies = [Company]()
        friendList = [Friend]()
        firstKnownKeyOrderSent = nil
        firstKnownKeyOrderReceived = nil
        notificationCenter = NotificationCenter.default
    }
    
    deinit {
        FireBaseAPI.removeObservers()
    }
    
    private func updatePendingProducts(order: Order,badgeValue: Int?) {
        guard let userIdApp = user?.idApp else { return }
        
        if order.userDestination?.idApp != userIdApp {
            var badgeValuePass = 0
            if badgeValue != nil {
                badgeValuePass = badgeValue!
            }
            FireBaseAPI.updateNode(node: "users/"+userIdApp, value: ["numberOfPendingPurchasedProducts" : badgeValuePass + 1])
        }
    }
    
    private func updateOfferState(orderDetails: [String:Any])->String{
        guard let userIdApp = user?.idApp else {
            return orderDetails[Order.offerState] as! String
        }
        
        if userIdApp == (orderDetails[Order.idAppUserDestination] as! String) {
            return "Offerta accettata"
        }
        
        return orderDetails[Order.offerState] as! String
    }
    
    private func buildOrderDataDictionary(order: Order)->[String:Any]{
        return[
            Order.expirationDate: order.expirationeDate != nil ? order.expirationeDate! : "",
            Order.paymentStateString: order.paymentState.rawValue,
            Order.offerState: order.offerState.rawValue,
            Order.facebookUserDestination: order.userDestination?.idFB != nil ? order.userDestination!.idFB! : "",
            Order.offerCreationDate: order.dataCreazioneOfferta != nil ? order.dataCreazioneOfferta! : "",
            Order.total: String(format:"%.2f", order.costoTotale),
            Order.idAppUserDestination: order.userDestination?.idApp != nil ? order.userDestination!.idApp! : "",
            Order.timestamp: ServerValue.timestamp(),
            Order.ordersSentAutoId: order.ordersSentAutoId,
            Order.orderNotificationIsScheduled: order.orderNotificationIsScheduled != nil ? order.orderNotificationIsScheduled! : "",
            Order.orderAutoId: order.orderAutoId,
            Order.pendingPaymentAutoId: paymentAutoId != nil ? paymentAutoId! : "",
            Order.userSenderIdApp: user?.idApp != nil ? user!.idApp! : "",
            Order.orderReaded:"false",
            Order.consumingDate: "",
            Order.viewState: order.viewState.rawValue
        ]
    }
    
    private func saveOrdersSentOnFireBase (badgeValue: Int?, order: Order, onCompletion: @escaping ()->()){
        guard let userDestinationIdApp = order.userDestination?.idApp,
            let userIdApp = user?.idApp,
            let companyId = order.company?.companyId
        else {
            onCompletion()
            return
        }
        
        order.orderAutoId = FireBaseAPI.setId(node: "ordersSent/\(userIdApp)/\(companyId)")
        order.ordersSentAutoId = FireBaseAPI.setId(node: "ordersReceived/\(userDestinationIdApp)/\(companyId)")
        
        var orderDetails = buildOrderDataDictionary(order: order)
        orderDetails[Order.offerState] = updateOfferState(orderDetails: orderDetails)
        
        FireBaseAPI.saveNodeOnFirebase(node: "ordersSent/\(userIdApp)/\(companyId)/\(order.orderAutoId)", dictionaryToSave: orderDetails, onCompletion: {(error) in
            guard error == nil else {
                return
            }
            self.updatePendingProducts(order: order, badgeValue: badgeValue)
            self.idOrder?.append(order.orderAutoId)
            onCompletion()
        })
    }
    
    //MARK: SAVE CART ON FIREBASE
    func saveCartOnFirebase(user: User, badgeValue: Int?,  onCompletion: @escaping ()->()){
        self.user = user
        var workItems = [DispatchWorkItem]()
        let queue = DispatchQueue.init(label: "it.morgana.queue")
        
        for order in Cart.sharedIstance.cart {
            guard let userIdapp = user.idApp,
                let companyId = order.company?.companyId
            else {
                    onCompletion()
                    return
            }
            self.paymentAutoId = FireBaseAPI.setId(node: "pendingPayments/\(userIdapp)/\(companyId)")
            let dispatchItem = DispatchWorkItem.init {
                self.saveOrdersSentOnFireBase(badgeValue: badgeValue,order: order, onCompletion: {
                })
            }
            dispatchItem.notify(queue: queue, execute: {
                //qui ci va il begin e complete handler poichè notify non sa quando finisce davvero il workitem
                self.saveProductOnFireBase(order: order)
                self.saveOrderAsReceivedOnFireBase(order: order)
                
                if self.idOrder?.count == Cart.sharedIstance.cart.count {
                    self.savePaymentOnFireBase(companyId: companyId, onCompletion: {
                        OrdersListManager.instance.refreshOrdersList()
                        print("[FIREBASEDATA]: refresh Order List request")
                        onCompletion()
                    })
                }
            })
            workItems.append(dispatchItem)
        }
        
        
        for item in 0...workItems.count-1 {
            queue.async {
                let currentWorkItem = workItems[item]
                currentWorkItem.perform()
            }
        }
    }
    
    //MARK: SAVE PRODUCT ON FIREBASE
    private func buildProductOrderDetailsDictionary(idFBFriend: String?, creationDate: String? )->[String:String]?{
        //costruisco il dictionary di dettaglio delle offerte: i prodotti
        guard idFBFriend != nil , creationDate != nil else { return nil}
        
        var orderDetails: [String:String] = [:]
        for order in Cart.sharedIstance.cart {
            guard let products = order.products else { return orderDetails }
            if (order.userDestination?.idFB == idFBFriend) && (order.dataCreazioneOfferta == creationDate) {
                for product in products {
                    if product.productName != "+    Aggiungi prodotto" {
                        guard let productName = product.productName,
                            let quantity = product.quantity,
                            let price = product.price
                            else { return orderDetails }
                        orderDetails[productName] = String(quantity) + "x" + String(format:"%.2f", price)
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
        let currentDetails = self.buildProductOrderDetailsDictionary(idFBFriend: order.userDestination?.idFB, creationDate: order.dataCreazioneOfferta)
        onCompletion(currentDetails, order.orderAutoId)
    }
    
    private func saveProductOnFireBase(order: Order){
        prepareProductDetails(order: order, onCompletion: {(currentDetails, autoId_ordersSent) in
            guard let details = currentDetails,
                let orderSentAutoId = autoId_ordersSent,
                let orderCompanyID = order.company?.companyId
            else {
                print("[DETTAGLIO ORDINI]: problema di salvataggio")
                return
            }
            self.saveOrderDetails(currentDetails: details, companyId: orderCompanyID, autoId_ordersSent: orderSentAutoId)
        })
    }
    
    //MARK: SAVE ORDER AS RECEIVED ON FIREBASE
    private func buildOrderDetailsReceivedDictionary(order:Order)->[String:Any]{
        var offerDetails: [String:Any] = buildOrderDataDictionary(order: order)
        
        // leggo i dati dell'ordine o offerte
        offerDetails[Order.offerId] = order.orderAutoId
        offerDetails[Order.autoId] = order.ordersSentAutoId
        offerDetails.removeValue(forKey: Order.ordersSentAutoId)
        offerDetails.removeValue(forKey: Order.orderAutoId)
        offerDetails.removeValue(forKey: Order.pendingPaymentAutoId)
        offerDetails[Order.userSenderIdApp] = user?.idApp != nil ? user?.idApp! : ""
        offerDetails[Order.orderReaded] = "false"
        offerDetails[Order.orderExpirationNotificationIsScheduled] = false
        offerDetails[Order.consumingDate] = ""
        offerDetails[Order.senderIdFB] = user?.idFB
        
        return offerDetails
    }
    
    private func saveOrderOnFirebase(orderDetails: [String:Any],companyId: String,onCompletion: @escaping ()->()) {
        FireBaseAPI.saveNodeOnFirebase(node: "ordersReceived/\(orderDetails["IdAppUserDestination"] as! String)/\(companyId)/\(orderDetails["autoId"] as! String)", dictionaryToSave: orderDetails, onCompletion: { (error) in
            guard error == nil else {
                print("read error on Firebase")
                return
            }
            FireBaseAPI.updateNode(node: "ordersReceived/\(orderDetails[Order.idAppUserDestination] as! String)/\(companyId)", value: [Order.scanningQrCode :false])
            
        })
    }
    
    func saveOrderAsReceivedOnFireBase(order: Order) {
        guard let companyId = order.company?.companyId else { return }
        
        var orderDetails = buildOrderDetailsReceivedDictionary(order:order)
        orderDetails[Order.offerState] = updateOfferState(orderDetails: orderDetails)
        saveOrderOnFirebase(orderDetails: orderDetails, companyId: companyId, onCompletion: {
            print("Ordine ricevuto salvato")
        })
    }
    
    //MARK: SAVE PAYMENT ON FIREBAASE
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
        payment.idPayment = paymentDictionaryDetails[Payment.idPayment] as? String
        payment.statePayment = paymentDictionaryDetails[Payment.statePayment] as? String
        payment.total = paymentDictionaryDetails[Payment.total] as? String
        payment.pendingUserIdApp = paymentDictionaryDetails[Payment.pendingUserIdApp] as! String
        payment.company?.companyId = companyId
        payment.createTime = paymentDictionaryDetails[Payment.createTime] as? String
        payment.paymentType = paymentDictionaryDetails[Payment.paymentType] as? String
        
        self.idOrder?.removeAll()
        return payment
        
    }
    
    private func savePaymentOnFireBase (companyId: String, onCompletion: @escaping ()->()){
        var paymentDictionaryDetails = buildPaymentIdOrders()
        
        paymentDictionaryDetails[Payment.idPayment] = Cart.sharedIstance.paymentMethod?.idPayment
        paymentDictionaryDetails[Payment.createTime] = Cart.sharedIstance.paymentMethod?.createTime
        paymentDictionaryDetails[Payment.paymentType] = Cart.sharedIstance.paymentMethod?.paymentType
        paymentDictionaryDetails[Payment.platform] = Cart.sharedIstance.paymentMethod?.platform
        paymentDictionaryDetails[Payment.statePayment] = Cart.sharedIstance.paymentMethod?.statePayment
        paymentDictionaryDetails[Payment.totalProducts] = String(Cart.sharedIstance.totalProducts)
        paymentDictionaryDetails[Payment.total] = String(format:"%.2f", Cart.sharedIstance.costoTotale)
        paymentDictionaryDetails[Payment.stateCartPayment] = Cart.sharedIstance.state
        
        if self.user?.idApp != nil {
            paymentDictionaryDetails[Payment.pendingUserIdApp] = (self.user?.idApp)!
        } else {
            paymentDictionaryDetails[Payment.pendingUserIdApp] = ""
        }
        
        let payment = buildPendingPayment(companyId: companyId, paymentDictionaryDetails: paymentDictionaryDetails)
        
        guard let userIdApp = user?.idApp, let paymentAutoID = paymentAutoId else {
            onCompletion()
            return
        }
        
        FireBaseAPI.saveNodeOnFirebase(node: "pendingPayments/\(userIdApp)/\(companyId)/\(paymentAutoID)", dictionaryToSave: paymentDictionaryDetails, onCompletion: { (error) in
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
        guard let notificationOrderIsScheduled = order.orderNotificationIsScheduled,
            let userIdApp = user?.idApp,
            let userDestinationFullName = order.userDestination?.fullName,
            let orderCompanyId = order.company?.companyId,
            let expirationDate = order.expirationeDate,
            let idOfferta = order.idOfferta,
            let offerId = order.idOfferta
        else { return }
        
        if !notificationOrderIsScheduled {
            DispatchQueue.main.async {
                NotificationsCenter.scheduledExpiratedOrderLocalNotification(title: "Ordine scaduto", body: "Il prodotto che hai offerto a \(userDestinationFullName) è scaduto", identifier: idOfferta, expirationDate: self.stringTodateObject(date: expirationDate))
                print("Notifica scadenza schedulata correttamente")
                order.orderNotificationIsScheduled = true
                FireBaseAPI.updateNode(node: "ordersSent/\(userIdApp)/\(orderCompanyId)/\(offerId)", value: ["orderNotificationIsScheduled":true])
            }
        }
    }
    //MARK: READ ORDERS SENT ON FIREBASE
    func readCompaniesOnFireBase(onCompletion: @escaping ([Company]?)->()){
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
    
    func mangeExpiredOffers(timeStamp:TimeInterval, order: Order, ref: DatabaseReference){
        let date = NSDate(timeIntervalSince1970: timeStamp/1000)
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let dateString = dateFormatter.string(from: date as Date)
        let date1Formatter = DateFormatter()
        
        date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        date1Formatter.locale = Locale.init(identifier: "it_IT")
        
        guard let finalDate = dateFormatter.date(from: dateString),
            let expirationeDate = order.expirationeDate,
            let userDestinationIdApp = order.userDestination?.idApp,
            let fullName = user?.fullName,
            let offerId  = order.idOfferta,
            let userIdApp = user?.idApp,
            let dateObj = date1Formatter.date(from: expirationeDate),
            let companyId = order.company?.companyId
            else { return }
        
        self.lastOrderSentReadedTimestamp.set(finalDate, forKey: "ordersSentReadedTimestamp")
        
        if dateObj < finalDate {
            order.offerState = .expired
            ref.child("ordersSent/\(userIdApp)/\(companyId)/\(offerId)").updateChildValues([Order.offerState : "Scaduta"])
            ref.child("ordersReceived/\(userDestinationIdApp)/\(companyId)/\(order.ordersSentAutoId)").updateChildValues([Order.offerState : "Scaduta"])
        
            if userDestinationIdApp != userIdApp {
                let msg = "Il prodotto che ti è stato offerto da \(fullName) è scaduto"
                NotificationsCenter.sendNotification(userDestinationIdApp: userDestinationIdApp, msg: msg, controlBadgeFrom: "received")
            }
            
            self.updateNumberPendingProductsOnFireBase(userDestinationIdApp, recOrPurch: "received")
        }
    }
    
    private func deleteClimbedOrder(ordersSent: [Order])->[Order]{
        var newProduct = [Product]()
        
        for order in ordersSent {
            guard let products = order.products else { return ordersSent}
            for product in products {
                if product.productName?.range(of:"_climbed") == nil {
                    newProduct.append(product)
                }
            }
            order.products = newProduct
            newProduct.removeAll()
        }
        return ordersSent
    }
    
    private func getClimbedOrders(ordersReceived: [Order])->[Order]{
        var newProduct = [Product]()
        
        for order in ordersReceived {
            guard let products = order.products else { return ordersReceived }
            
            for product in products {
                if product.productName?.range(of:"_climbed") != nil && product.quantity != 0 {
                    product.productName = product.productName?.replacingOccurrences(of: "_climbed", with: "", options: .regularExpression)
                    newProduct.append(product)
                }
            }
            
            if newProduct.count != 0 {
                order.products = newProduct
            }
            
            newProduct.removeAll()
        }
        
        return ordersReceived
    }
    
    private func deleteDuplicate(_ orders: [Order])-> [Order] {
        var ordersResult = [Order]()
        for order in orders {
            ordersResult = ordersResult.filter({$0.timeStamp != order.timeStamp})
            ordersResult.append(order)
        }
        return ordersResult
    }
    
    private func sortArray(_ orders: [Order]) -> [Order]{
        var ordersResult = orders
        ordersResult.sort(by: {self.timestampTodateObject(timestamp: $0.timeStamp) > self.timestampTodateObject(timestamp: $1.timeStamp)})
        return ordersResult
    }
    
    func readOrderSentDictionary(orderDictionary: NSDictionary,onCompletion: @escaping ([Order])->()){
        var orderList = [Order]()
        print("[FIREBASEDATA]: Read orders sent: Dictionary \(orderDictionary.count)")
        
        for (id_offer, orderData) in orderDictionary {
            let order: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
            order.company?.companyId = self.companyID //companyId as? String
            order.idOfferta = id_offer as? String
            
            order.orderAutoId = id_offer as! String
            guard let orderDataDictionary = orderData as? NSDictionary else {
                return
            }
            
            //filtering deleted data
            if orderDataDictionary[Order.viewState] as? String != Order.ViewStates.deleted.rawValue {
                order.expirationeDate = orderDataDictionary[Order.expirationDate] as? String
                order.paymentState = Payment.State(rawValue: (orderDataDictionary[Order.paymentStateString] as? String)!)!
                order.offerState = Order.OfferStates(rawValue: (orderDataDictionary[Order.offerState] as? String)!)!
                order.userDestination?.idFB = orderDataDictionary[Order.facebookUserDestination] as? String
                order.dataCreazioneOfferta = orderDataDictionary[Order.offerCreationDate] as? String
                order.userDestination?.idApp = orderDataDictionary[Order.idAppUserDestination] as? String
                order.timeStamp = orderDataDictionary[Order.timestamp] as! TimeInterval
                order.pendingPaymentAutoId = orderDataDictionary[Order.pendingPaymentAutoId] as! String
                order.ordersSentAutoId = orderDataDictionary[Order.ordersSentAutoId] as! String
                order.userSender?.idApp = orderDataDictionary[Order.userSenderIdApp] as? String
                order.orderNotificationIsScheduled = orderDataDictionary[Order.orderNotificationIsScheduled] as? Bool
                order.consumingDate = orderDataDictionary[Order.consumingDate] as? String
                order.viewState = Order.ViewStates(rawValue: (orderDataDictionary[Order.viewState] as? String)!)!
                
                if  orderDataDictionary[Order.orderReaded] as? String == "true"{
                    order.orderReaded = true
                } else {
                    order.orderReaded = false
                }
                
                if order.userDestination?.idFB == self.user?.idFB {
                    order.userDestination?.fullName = self.user?.fullName
                    order.userDestination?.pictureUrl = self.user?.pictureUrl
                    
                } else if !(self.friendList?.isEmpty)! {
                    for friend in self.friendList! {
                        if friend.idFB == order.userDestination?.idFB {
                            order.userDestination?.fullName = friend.fullName
                            order.userDestination?.pictureUrl = friend.pictureUrl
                            break
                        }
                    }
                }
                //filtering expired data
                
                if order.offerState != .expired {
                    self.scheduleExpiryNotification(order: order)
                    if let timeStamp = ServerValue.timestamp().values.first as? TimeInterval {
                        self.mangeExpiredOffers(timeStamp: timeStamp, order: order, ref: self.ref)
                    }
                }
            
                orderList.append(order)
                //if consumption is before expirationDate, scheduled notification is killed
                //attenzione lo fa ogni volta che legge
                if order.offerState == .consumed {
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: [order.idOfferta!])
                    print("[FIREBASEDATA]: scheduled notification killed")
                }
            }
        }
        self.ordersSent = self.ordersSent + orderList
        self.ordersSent = deleteDuplicate(sortArray(self.ordersSent))
        self.firstKnownKeyOrderSent = self.ordersSent.last?.idOfferta
        self.ordersSent  = self.ordersSent.filter{$0.userDestination?.idApp != self.user?.idApp && $0.paymentState == .valid}
        
        self.readOrderDetails(ordersToRead: deleteDuplicate(sortArray(orderList)), onCompletion: { (orders) in
            self.notificationCenter.post(name: .FireBaseDataUserReadedNotification, object: nil)
            onCompletion(orders)
        })
    }
    
//    //Reload for infinitive scroll
//    func readOrdersSentOnFireBaseRange(user: User, onCompletion: @escaping ([Order]?)->()){
//        guard let checkFirstKnowKey = firstKnownKeyOrderSent else {
//            onCompletion(nil)
//            return
//        }
//
//        self.user = user
//        guard let userIdApp = user.idApp else { return }
//
//        _refHandle = ref.child("ordersSent/" + userIdApp+"/\(companyID)")
//            .queryOrderedByKey()
//            .queryEnding(atValue: checkFirstKnowKey)
//            .queryLimited(toLast: FirebaseData.DIM_PAGE_SCROLL)
//            .observe(.value, with: { (snap) in
//
//                guard snap.exists() else {
//                    onCompletion(nil)
//                    return
//                }
//                guard snap.value != nil else {
//                    onCompletion(nil)
//                    return
//                }
//
//                self.totalNumberOrdersSentReaded += Int(snap.childrenCount)
//
//                guard let orderDictionary = (snap.value! as? NSDictionary) else {
//                    onCompletion(nil)
//                    return
//                }
//                guard orderDictionary.count > 1 else {
//                    onCompletion(nil)
//                    return
//                }
//
//                self.readOrderSentDictionary(orderDictionary: orderDictionary, onCompletion: { (orderSent) in
//                    onCompletion(self.deleteClimbedOrder(ordersSent: orderSent))
//                })
//            })
//    }
    
    
    func readOrdersSentOnFireBase(user: User, friendsList: [Friend]?, onCompletion: @escaping ([Order])->()) {
        print("[FIREBASEDATA]: read orders sent on Firebase")
        self.user = user
        self.friendList = friendsList
        self.ordersSent.removeAll()
        
        guard Auth.auth().currentUser != nil, let userIdApp = user.idApp else {
            onCompletion([])
            return
        }
        
//        ref.child("ordersSent/" + userIdApp + "/\(companyID)").observeSingleEvent(of: .value) { (snap) in
//            self.totalNumberOrdersSent = Int(snap.childrenCount)
//            self.totalNumberOrdersSentReaded = 0
//        }
        
          ref.child("ordersSent/" + userIdApp + "/\(companyID)")
            .queryOrdered(byChild: Order.viewState)
            .queryEqual(toValue: Order.ViewStates.active.rawValue)
//            .queryLimited(toLast: FirebaseData.DIM_PAGE_SCROLL)
            .observeSingleEvent(of: .value, with: { (snap) in  //snap.childrenCount
                guard snap.exists() else {
                    onCompletion([])
                    return
                }
                guard snap.value != nil else {
                    onCompletion([])
                    return
                }
//                self.totalNumberOrdersSentReaded = Int(snap.childrenCount)
                
                self.ordersSent.removeAll()
                guard let orderDictionary = (snap.value! as? NSDictionary) else {
                    return
                }
                
                self.readOrderSentDictionary(orderDictionary: orderDictionary, onCompletion: { (orderSent) in
                    onCompletion(self.deleteClimbedOrder(ordersSent: orderSent))
                })
            })
    }
    
    private func manageExpirationOrder(order: Order){
        if order.offerState != .expired, let timestamp = ServerValue.timestamp().values.first as? TimeInterval {
            
            let date = NSDate(timeIntervalSince1970: timestamp/1000)
            let dateFormatter = DateFormatter()
            
            dateFormatter.amSymbol = "AM"
            dateFormatter.pmSymbol = "PM"
            dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
            let dateString = dateFormatter.string(from: date as Date)
            
            guard let currentDate = dateFormatter.date(from: dateString) else { return }
            
            self.lastOrderReceivedReadedTimestamp.set(currentDate, forKey: "lastOrderReceivedReadedTimestamp")
            
            let date1Formatter = DateFormatter()
            date1Formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
            date1Formatter.locale = Locale.init(identifier: "it_IT")
            
            guard let expDay = order.expirationeDate else { return }
            
            guard let expirationDate = date1Formatter.date(from: expDay) else { return }
            
            if expirationDate < currentDate {
                
                guard let userIdApp = self.user?.idApp,
                    let companyId = order.company?.companyId,
                    let offerId = order.idOfferta,
                    let userFullName = self.user?.fullName,
                    let usersenderIdApp = order.userSender?.idApp
                    else { return }
                
                self.ref.child("ordersReceived/\(userIdApp)/\(companyId)/\(order.orderAutoId)").updateChildValues([Order.offerState : "Scaduta"])
                self.ref.child("ordersSent/\(usersenderIdApp)/\(companyId)/\(offerId)").updateChildValues([Order.offerState : "Scaduta"])
                order.offerState = .expired
                let msg = "Il prodotto che hai offerto a \(userFullName) è scaduto"
                NotificationsCenter.sendNotification(userDestinationIdApp: usersenderIdApp, msg: msg, controlBadgeFrom: "purchased")
                self.updateNumberPendingProductsOnFireBase(usersenderIdApp, recOrPurch: "purchased")
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+offerId, "RememberExpiration-"+offerId])
            }
            
        }
    }
    //MARK: READ ORDERS RECEIVED ON FIREBASE
    private func readOrderData(order: Order,orderDataDictionary: NSDictionary) -> Order {
        for (chiave,valore) in orderDataDictionary {
            switch chiave as! String {
            case Order.expirationDate:
                order.expirationeDate = valore as? String
                break
            case Order.paymentStateString:
                switch valore as! String {
                case "Not Valid":
                   order.paymentState = .notValid
                case "Valid":
                    order.paymentState  = .valid
                case "Pending":
                    order.paymentState  = .pending
                default:
                    order.paymentState = .pending
                    
                }
                break
            case Order.offerState:
                switch valore as! String {
                case Order.OfferStates.accepted.rawValue:
                    order.offerState = .accepted
                case Order.OfferStates.consumed.rawValue:
                    order.offerState = .consumed
                case Order.OfferStates.expired.rawValue:
                    order.offerState = .expired
                case Order.OfferStates.forward.rawValue:
                    order.offerState = .forward
                case Order.OfferStates.refused.rawValue:
                    order.offerState = .refused
                case Order.OfferStates.pending.rawValue:
                    order.offerState = .pending
                case Order.OfferStates.ransom.rawValue:
                    order.offerState = .ransom
                case Order.OfferStates.scaled.rawValue:
                    order.offerState = .scaled
                default:
                    break
                }
                break
            case Order.offerCreationDate:
                order.dataCreazioneOfferta = valore as? String
                break
            case Order.offerId:
                order.idOfferta = valore as? String
                break
            case Order.userSenderIdApp:
                order.userSender?.idApp = valore as? String
                break
            case Order.senderIdFB:
                order.userSender?.idFB = valore as? String
                break
            case Order.timestamp:
                order.timeStamp = (valore as? TimeInterval)!
                break
            case Order.idAppUserDestination:
                order.userDestination?.idApp = valore as? String
                break
            case Order.orderReaded:
                if (valore as? String) == "false" {
                    order.orderReaded = false
                } else {order.orderReaded = true}
                break
            case Order.orderNotificationIsScheduled:
                order.orderNotificationIsScheduled = (valore as? Bool)!
                break
            case Order.orderExpirationNotificationIsScheduled:
                order.orderExpirationNotificationIsScheduled = (valore as? Bool)!
                break
            case Order.total:
                order.totalReadedFromFirebase = (valore as? String)!
                break
            case Order.consumingDate:
                order.consumingDate = valore as? String
                break
            case Order.viewState:
                order.viewState = Order.ViewStates(rawValue: (valore as? String)!)!
                break
            case Order.facebookUserDestination:
                order.userDestination?.idFB = valore as? String
                break
            default:
                break
            }
        }
        
        if order.userSender?.idFB == self.user?.idFB {
            order.userSender?.fullName = self.user?.fullName
            order.userSender?.pictureUrl = self.user?.pictureUrl
        } else if !(self.friendList?.isEmpty)! {
            for friend in self.friendList! {
                if friend.idFB == order.userSender?.idFB {
                    order.userSender?.fullName = friend.fullName
                    order.userSender?.pictureUrl = friend.pictureUrl
                    break
                }
            }
        }
        return order
    }
    
    private func readOrderReceivedDictionary(dataOrder: NSDictionary, onCompletion: @escaping ([Order])->()) {
        var orderList = [Order]()
        var order: Order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
        
        for (orderId, dati_pendingOffers) in dataOrder {
            if orderId as? String != Order.scanningQrCode {
                order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
                order.company?.companyId = self.companyID
                order.orderAutoId = orderId as! String
                
                guard let orderDataDictionary = dati_pendingOffers as? NSDictionary else {
                    return
                }
                order = self.readOrderData(order: order, orderDataDictionary: orderDataDictionary)
               
                self.manageExpirationOrder(order: order)
                orderList.append(order)
                //if consumption is before expirationDate, scheduled notification is killed
                if order.offerState == .consumed {
                    //attenzione killa ogni volta che carica le offeerte, deve farlo una volta
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: ["expirationDate-"+order.idOfferta!,"RememberExpiration-"+order.idOfferta!])
                    print("[FIREBASEDATA]: scheduled notification killed")
                }
            }
        }
        self.ordersReceived = self.ordersReceived + orderList
        self.ordersReceived = self.deleteDuplicate(self.sortArray(self.ordersReceived))
        self.firstKnownKeyOrderReceived = self.ordersReceived.last?.idOfferta
        self.readOrderDetails(ordersToRead: self.sortArray(orderList), onCompletion: { (orders) in
            self.notificationCenter.post(name: .FireBaseDataUserReadedNotification, object: nil)
            onCompletion(self.getClimbedOrders(ordersReceived: orders))
        })
    }
    
//    //Reload for infinitive scroll
//    func readOrdersReceivedOnFireBaseRange(user: User, onCompletion: @escaping ([Order]?)->()){
//        guard let checkFirstKnowKey = firstKnownKeyOrderReceived, let userIdApp = user.idApp else {
//            onCompletion(nil)
//            return
//        }
//        self.user = user
//
//        _refHandle = ref.child("ordersReceived/" + userIdApp + "/\(companyID)")
//            .queryOrderedByKey()
//            .queryEnding(atValue: checkFirstKnowKey)
//            .queryLimited(toLast: FirebaseData.DIM_PAGE_SCROLL)
//            .observe(.value, with: { (snap) in
//
//                guard snap.exists() else {
//                    onCompletion(nil)
//                    return
//                }
//                guard snap.value != nil else {
//                    onCompletion(nil)
//                    return
//                }
//                self.totalNumberOrdesReceivedReaded += Int(snap.childrenCount)
//                guard let ordersDictionary = (snap.value! as? NSDictionary) else {
//                    onCompletion(nil)
//                    return
//                }
//                guard ordersDictionary.count > 1 else {
//                    onCompletion(nil)
//                    return
//                }
//                self.readOrderReceivedDictionary(dataOrder: ordersDictionary, onCompletion: { (orderReceived) in
//                    onCompletion(self.getClimbedOrders(ordersReceived: self.ordersReceived))
//                })
//            })
//    }
    
    func readOrderReceivedOnFireBase(user: User, onCompletion: @escaping ([Order])->()) {
        self.user = user
        self.ordersReceived.removeAll()
        print("[FIREBASEDATA]: Read Order Received")
        
        guard Auth.auth().currentUser != nil, let userIdApp = user.idApp else {
            onCompletion([])
            return
        }
        
        observeOrdersOnFirebase(userIdApp: userIdApp)
        
//        ref.child("ordersReceived/" + userIdApp + "/\(companyID)").observeSingleEvent(of: .value) { (snap) in
//            self.totalNumberOrdesReceived = Int(snap.childrenCount)
//            self.totalNumberOrdesReceivedReaded = 0
//        }
        
         ref.child("ordersReceived/" + userIdApp + "/\(companyID)")
            .queryOrdered(byChild: Order.viewState)
            .queryEqual(toValue: Order.ViewStates.active.rawValue)
//            .queryLimited(toLast: FirebaseData.DIM_PAGE_SCROLL)
            .observeSingleEvent(of: .value, with: { (snap) in
                // controllo che lo snap dei dati non sia vuoto
                guard snap.exists() else {
                    onCompletion([])
                    return}
                
                guard snap.value != nil else {
                    onCompletion([])
                    return
                }
//                self.totalNumberOrdesReceivedReaded = Int(snap.childrenCount)

                self.ordersReceived.removeAll()
                
                // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
                guard let ordersDictionary = snap.value as? NSDictionary else {
                    return
                }
                self.readOrderReceivedDictionary(dataOrder: ordersDictionary, onCompletion: { (orderReceived) in
                    onCompletion(orderReceived)
                })
                
            })
    }
    
    //MARK: OBSERVER ORDERS ON FIREBASE
    private func observeOrdersOnFirebase(userIdApp: String) {
        ref.child("ordersReceived/" + userIdApp + "/\(companyID)").observe(.childChanged, with: { (snap) in
            if snap.key == "scanningQrCode" {
                if (snap.value as? Bool)! == true {
                    let activeViewController = UIApplication.topViewController(UIApplication.shared.keyWindow?.rootViewController?.childViewControllers[1])
                    if activeViewController is QROrderGenerationViewController {
                        (activeViewController as! QROrderGenerationViewController).unwind()
                    }
                    FireBaseAPI.updateNode(node: "ordersReceived/\((self.user?.idApp)!)/\(self.companyID)", value: [Order.scanningQrCode: false])
                    OrdersListManager.instance.refreshOrdersList()
                    print("[FIREBASEDATA]: Order list refreshed from firebase observer, scanningQRCode")
                }
            } else {
                let ordersReceived = OrdersListManager.instance.readOrdersList().ordersList.ordersReceivedList
                if ordersReceived.count < snap.childrenCount - 1 {
                    OrdersListManager.instance.refreshOrdersList()
                    print("[FIREBASEDATA]: Order list refreshed from firebase observer, new child added in order received")
                    return
                } else {
                    ordersReceived.forEach({ (order) in
                        //verifing if is an update
                        if order.orderAutoId == snap.key {
                            guard let orderChanged = snap.value as? NSDictionary, let offerState = orderChanged["offerState"] as? String  else { return }
                            if offerState != order.offerState.rawValue {
                                OrdersListManager.instance.refreshOrdersList()
                                print("[FIREBASEDATA]: Order list refreshed from firebase observer, offerState changed in orders received")
                                return
                            }
                        }
                    })
                }
            }
        })
        ref.child("ordersSent/" + userIdApp + "/\(companyID)").observe(.childChanged, with: { (snap) in
            let ordersSent = OrdersListManager.instance.readOrdersList().ordersList.ordersSentList
            ordersSent.forEach({ (order) in
                if order.orderAutoId == snap.key {
                    guard let orderChanged = snap.value as? NSDictionary, let offerState = orderChanged["offerState"] as? String  else { return }
                    if  offerState != order.offerState.rawValue {
                        OrdersListManager.instance.refreshOrdersList()
                        print("[FIREBASEDATA]: Order list refreshed from firebase observer, offerState changed in orders sent")
                    }
                }
            })
        })
    }
    
    //MARK: READ SINGLE ORDER
    func readSingleOrder (userId: String, companyId: String, orderId: String, onCompletion: @escaping ([Order])->()){
        var orderList: [Order] = []
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "ordersReceived/\(userId)/\(companyId)/\(orderId)", onCompletion: { (error,dictionary) in
            guard error == nil else {
                print("[FIREBASEDATA]: Errore di connessione")
                return
            }
            guard let orderDictionary = dictionary as NSDictionary? else {
                print("[FIREBASEDATA]: Errore di lettura del dell'Ordine richiesto")
                return
            }
            
            var order = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
            order.company?.companyId = companyId
            order.orderAutoId = orderId
            order = self.readOrderData(order: order, orderDataDictionary: orderDictionary)
            
            orderList.append(order)
            self.readUserSender(ordersToRead: orderList, onCompletion: { (order) in
                self.readOrderDetails(ordersToRead: order, onCompletion: { (orders) in
                    onCompletion(orders)
                })
            })
        })
    }
    
    //MARK: READ USER SENDER
    private func readUserSender(ordersToRead: [Order], onCompletion: @escaping ([Order])->()){
        var node = String()
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.morgnaMusic.queueReadUsers", attributes: .concurrent, target: .main)
        
        print("[FIREBASEDATA]: Read user sender, Orders Received contiene \(ordersToRead.count) ordini")
        
        for singleOrder in ordersToRead{
            if let idApp = singleOrder.userSender?.idApp {
                node = "users/" + idApp
                FireBaseAPI.readNodeOnFirebaseWithOutAutoIdHandler(node: node, beginHandler: {
                    dispatchGroup.enter()
                    queue.async(group: dispatchGroup){
                    }
                }, completionHandler: {(error, userData) in
                    guard error == nil else {return}
                    guard userData != nil else {return}
                    singleOrder.userSender?.fullName = userData!["fullName"] as? String
                    singleOrder.userSender?.pictureUrl = userData!["pictureUrl"] as? String
                    dispatchGroup.leave()
                })
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("[FIREBASEDATA]: group operation ended")
            onCompletion(ordersToRead)
        }
    }
    
    //MARK: READ ORDERS DETAILS
    private func readOrderDetails(ordersToRead: [Order], onCompletion: @escaping ([Order])->()) {
        print("[FIREBASEDATA]: Read Orders Details")
        
        
        let dispatchGroup = DispatchGroup.init()
        let queue = DispatchQueue.init(label: "it.xcoding.queueReadOrderDetails", attributes: .concurrent, target: .main)
        
        for singleOrder in ordersToRead{
            guard let orderId = singleOrder.idOfferta, let companyId = singleOrder.company?.companyId else { return }
            
            let node = "productsOffersDetails/\(companyId)/\(orderId)"
            
            
            //readNodeOnFireBase
            FireBaseAPI.readNodeOnFirebaseWithOutAutoIdHandler(node: node, beginHandler: {
                dispatchGroup.enter()
                queue.async(group: dispatchGroup){
                   
                }
            }, completionHandler: { (error, productData) in
                
                guard error == nil else {return}
                guard productData != nil else {return}
                
                var product: Product = Product(productName: nil, price: nil, quantity: nil, points: nil)
                singleOrder.products?.removeAll()
                for (chiave,valore) in productData! {
                    if chiave != Order.autoId {
                        product.productName = chiave
                        let token = (valore as? String)?.components(separatedBy: "x")
                        product.quantity = Int((token?[0])!)
                        product.price = Double((token?[1])!)
                       
                        if (product.price != nil) && (product.productName != nil) && (product.quantity != nil){
                            singleOrder.products?.append(product)
                            
                            product = Product(productName: nil, price: nil, quantity: nil, points: nil)
                        }
                        
                    }
                }
                dispatchGroup.leave()
            })
        }
        
        dispatchGroup.notify(queue: queue) {
            print("[FIREBASEDATA]: lettura prodotti terminata")
            onCompletion(ordersToRead)
        }
    }
    
    func updateNumberPendingProductsOnFireBase(_ idAppUserDestination: String, recOrPurch: String){
        
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
            self.ref.child("users/"+idAppUserDestination).updateChildValues([badgeValueToUpdate : badgeValue + 1])
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
        
        FireBaseAPI.updateNode(node: "ordersReceived/\(userIdApp)/\(comapanyId)/\(autoIdOrder)", value: [Order.orderReaded : "true", Order.offerState : state])
        FireBaseAPI.updateNode(node: "ordersSent/\(userSenderIdApp)/\(comapanyId)/\(idOrder)", value: [Order.offerState: state])
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
    func moveFirebaseRecord(userApp: User, user: UserDestination, company: String, order:Order, onCompletion: @escaping (String?)->()){
        guard let userIdApp = user.idApp,
            let userDestinationIdApp = order.userDestination?.idApp,
            let userDestinationIdFB = order.userDestination?.idFB
        else { return }
        
        let sourceNode = "ordersReceived/" + userIdApp + "/" + company + "/" + order.ordersSentAutoId
        let destinationNode = "ordersReceived/" + userDestinationIdApp + "/" + company + "/" + order.ordersSentAutoId
        var offerState : String {
            if userDestinationIdApp == userApp.idApp {
                return "Offerta accettata"
            } else {
                return "Pending"
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        formatter.locale = Locale.init(identifier: "it_IT")
        let creationDate = formatter.string(from: Date())
        
        //if the user has bought the order for itself expiration date is from 1 year
        var date = Date()
        if userApp.idApp == userDestinationIdApp {
            date = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        }else {
            date = Calendar.current.date(byAdding: .weekday, value: 3, to: Date())!
        }
        
        
        let newValues = [
            Order.offerCreationDate : creationDate,
            Order.timestamp: ServerValue.timestamp(),
            Order.idAppUserDestination: userDestinationIdApp,
            Order.facebookUserDestination: userDestinationIdFB,
            Order.offerState: offerState,
            Order.orderReaded: "false",
            Order.expirationDate : formatter.string(from: date),
            Order.viewState : Order.ViewStates.active.rawValue
            ] as [String : Any]
        
        FireBaseAPI.moveFirebaseRecordApplyingChanges(sourceChild: sourceNode, destinationChild: destinationNode, newValues: newValues, onCompletion: { (error) in
            guard error == nil else {
                onCompletion(error)
                return
            }
            FireBaseAPI.updateNode(node: "ordersReceived/\(userDestinationIdApp)/\(company)", value: [Order.scanningQrCode : false])
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
            print("[FIREBASEDATA]: Offerta crediti accettata e prossima Data di notifica  aggiornata al \(nextScheduledBirthdayNotification)")
        })
    }
}
