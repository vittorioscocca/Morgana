//
//  MyDrinksViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 19/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import UIKit
import FirebaseDatabase
import FirebaseAuth
import Firebase
import FirebaseMessaging
import FirebaseInstanceID
import UserNotifications

class MyOrderViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var drinksList_segmentControl: UISegmentedControl!
    @IBOutlet var successView: UIView!
    @IBOutlet var menuButton: UIBarButtonItem!
    @IBOutlet weak var myActivityIndicator: UIActivityIndicatorView!
    
    private var user: User?
    private var friendsList: [Friend]?
    private var uid: String?
    
    //device memory
    private var fireBaseToken = UserDefaults.standard
    private var productSendBadge = UserDefaults.standard
    private var lastOrderSentReadedTimestamp = UserDefaults.standard
    private var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    private var firebaseObserverKilled = UserDefaults.standard
    
    var ordersSent = [Order]()
    var ordersReceived = [Order]()
    
    //infinitive scroll variable
    private var fetchingMoreOrdersSent = false
    private var fetchingMoreOrdersReceived = false
    
    private var payPalAccessToken = String()
    private var PayPalPaymentDataDictionary: NSDictionary?
    
    //Alert Controller
    private var controller :UIAlertController?
    
    //Activity Indicator
    private var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    private var strLabel = UILabel()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    //forward action var
    public var forwardOrder :Order?
    private var oldFriendDestination: UserDestination?
    private var pendingPaymentId = String()
    private let pageTableView = FirebaseData.DIM_PAGE_SCROLL
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myTable.dataSource = self
        myTable.delegate = self
        
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        
        setSegmentcontrol()
        uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        user = CoreDataController.sharedIstance.findUserForIdApp(self.uid)
        updateSegmentControl()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(FireBaseDataUserReadedNotification),
                                               name: .FireBaseDataUserReadedNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(OrdersListStateDidChange),
                                               name: .OrdersListStateDidChange,
                                               object: nil)
        
        ordersSent = OrdersListManager.instance.readOrdersList().ordersList.ordersSentList
        ordersReceived = OrdersListManager.instance.readOrdersList().ordersList.ordersReceivedList
        beginFetchOrdersSent()
        beginFetchOrdersReceived()
        
        myTable.addSubview(refreshControl1)
        successView.isHidden = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateSegmentControl()
    }
    
    @objc func OrdersListStateDidChange(){
        print("stato attuale Order list", OrdersListManager.instance.state)
        if case .loading = OrdersListManager.instance.state{
            myActivityIndicator.startAnimating()
            myTable.isUserInteractionEnabled = false
        } else {
            myActivityIndicator.stopAnimating()
        }
        
        if case let .fatalError(error) = OrdersListManager.instance.state {
            print("Errore stato fatal error \(error)")
        }
        
        if case .success = OrdersListManager.instance.state{
            refreshControl1.endRefreshing()
            myTable.isUserInteractionEnabled = true
            let orderSentList = OrdersListManager.instance.readOrdersList().ordersList.ordersSentList
            let orderRiceivedList = OrdersListManager.instance.readOrdersList().ordersList.ordersReceivedList
            ordersSent = orderSentList
            ordersReceived = orderRiceivedList
            beginFetchOrdersSent()
            beginFetchOrdersReceived()
            DispatchQueue.main.async(execute: { () -> Void in
                self.myTable.reloadData()
            })
            print(" Order list changed, table reloaded")
        }
    }
    
    @objc private func FireBaseDataUserReadedNotification() {
        //self.myTable.reloadData()
    }
    
    private func setSegmentcontrol() {
        drinksList_segmentControl.selectedSegmentIndex = 0
        //self.drinksList_segmentControl.removeBorders()
        let segAttributes: NSDictionary = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 17)
        ]
        drinksList_segmentControl.setTitleTextAttributes(segAttributes as? [AnyHashable : Any], for: UIControlState.selected)
        drinksList_segmentControl.setTitleTextAttributes(segAttributes as? [AnyHashable : Any], for: UIControlState.normal)
        let underlineWidth = self.view.frame.width / CGFloat(self.drinksList_segmentControl.numberOfSegments)
        drinksList_segmentControl.addUnderlineForSelectedSegment(underlineWidth: underlineWidth)
    }
    
    private func generateStandardAlert(){
        controller = UIAlertController(title: "Attenzione connessione Internet assente",
                                       message: "Accertati che la tua connessione WiFi o cellulare sia attiva",
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    private func updateSegmentControl(){
        let ref = Database.database().reference()
        
        guard let userIdApp = user?.idApp else { return }
        
        ref.child("users/" + userIdApp).observe(.value, with: { (snap) in
            
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let datiUtente = snap.value! as! NSDictionary
            DispatchQueue.main.async(execute: {
                for (chiave,valore) in datiUtente {
                    switch chiave as! String {
                    case "numberOfPendingReceivedProducts":
                        self.productSendBadge.set(valore as! Int, forKey: "productOfferedBadge")
                        break
                    case "numberOfPendingPurchasedProducts":
                        self.productSendBadge.set(valore as! Int, forKey: "paymentOfferedBadge")
                        break
                    default:
                        break
                    }
                }
                //update segment control
                if self.productSendBadge.object(forKey: "productOfferedBadge") as? Int != 0 {
                    let val = self.productSendBadge.object(forKey: "productOfferedBadge") as? Int
                    self.drinksList_segmentControl.setTitle("Ricevuti  " + String(describing: val!), forSegmentAt: 1)
                } else {
                    self.drinksList_segmentControl.setTitle("Ricevuti", forSegmentAt: 1)
                }
                if self.productSendBadge.object(forKey: "paymentOfferedBadge") as? Int != 0 {
                    let val = self.productSendBadge.object(forKey: "paymentOfferedBadge") as? Int
                    self.drinksList_segmentControl.setTitle("Inviati  " + String(describing: val!), forSegmentAt: 0)
                } else {
                    self.drinksList_segmentControl.setTitle("Inviati", forSegmentAt: 0)
                }
            })
        })
    }
    
    private func resetSegmentControl1(){
        guard let userIdApp = user?.idApp else { return }
        FireBaseAPI.updateNode(node: "users/" + userIdApp, value: ["numberOfPendingReceivedProducts" : 0])
        self.drinksList_segmentControl.setTitle("Ricevuti", forSegmentAt: 1)
    }
    
    private func resetSegmentControl0(){
        guard let userIdApp = user?.idApp else { return }
        FireBaseAPI.updateNode(node: "users/" + userIdApp, value: ["numberOfPendingPurchasedProducts" : 0])
        self.drinksList_segmentControl.setTitle("Inviati", forSegmentAt: 0)
    }
    
    private func readAndSolvePendingPayPalPayment(order: Order, paymentId: String,onCompletion: @escaping () -> ()){
        let ref = Database.database().reference()
    
        guard let userIdApp = user?.idApp,
            let companyId = order.company?.companyId
            else { return }
        
        ref.child("pendingPayments/\(userIdApp)/\(companyId)/\(paymentId)").observeSingleEvent(of:.value, with: { (snap) in
            
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let dizionario_pagamenti = snap.value! as! NSDictionary
            
            let payment: Payment = Payment(platform: "", paymentType: "", createTime: "", idPayment: "", statePayment: "", autoId: "",total: "")
            payment.autoId = paymentId
            var count = 0
            for (chiave,valore) in dizionario_pagamenti {
                
                switch chiave as! String {
                case Payment.idPayment:
                    payment.idPayment = valore as? String
                    break
                case Payment.statePayment:
                    payment.statePayment = valore as? String
                    break
                case Payment.total:
                    payment.total = valore as? String
                    break
                case let x where (x.range(of:"offerID") != nil):
                    payment.relatedOrders.append((valore as? String)!)
                    count += 1
                    break
                case Payment.pendingUserIdApp:
                    payment.pendingUserIdApp = (valore as? String)!
                    break
                default:
                    break
                }
            }
            PaymentManager.sharedIstance.resolvePendingPayPalPayment(user: self.user!,payment: payment, onCompleted: { (paymentVerified) in
                guard paymentVerified  else {
                    DispatchQueue.main.async(execute: {
                        // ritorno sul main thread ed aggiorno la view
                        self.stopActivityIndicator()
                    })
                    
                    print("state payement is not approved")
                    self.generateAlert(title: "Pagamento non avvenuto", msg: "Il tuo pagamento di € " + payment.total! + " non è andato a buon fine",indexPath: nil)
                    return
                }
                DispatchQueue.main.async(execute: {
                    // ritorno sul main thread ed aggiorno la view
                    self.stopActivityIndicator()
                    self.generateAlert(title: "Pagamento avvenuto", msg: "Il tuo pagamento di € " + payment.total! + " è avvenuto correttamente",indexPath: nil)
                })
                self.setPaymentCompletedInLocal(payment)
                
            })
            onCompletion()
        })
    }
    
    private func setPaymentCompletedInLocal(_ payment: Payment){
        for i in self.ordersSent{
            for j in payment.relatedOrders{
                if i.idOfferta == j{
                    i.paymentState = .valid
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.drinksList_segmentControl.selectedSegmentIndex == 0 {
            return (ordersSent.count)
        } else {
            return (ordersReceived.count)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        
        if self.drinksList_segmentControl.selectedSegmentIndex == 0 && !self.ordersSent.isEmpty {
            
            cell = tableView.dequeueReusableCell(withIdentifier: "myDrinksPurchasedCell", for: indexPath)
            
            guard !self.ordersSent.isEmpty else {
                cell.textLabel?.text = "Nessun ordine inviato"
                return cell
            }
            
            let orderSent = self.ordersSent[indexPath.row]
            
            guard let offerCreationDate = orderSent.dataCreazioneOfferta else { return cell }
            
            if orderSent.orderReaded != nil {
                if !(orderSent.orderReaded)! {
                    (cell as! OrderSentTableViewCell).cellReaded = false
                } else {
                    (cell as! OrderSentTableViewCell).cellReaded = true
                }
            }
            
            (cell as! OrderSentTableViewCell).friendFullName.text = orderSent.userDestination?.fullName
            
            switch orderSent.paymentState {
            case .notValid:
                (cell as! OrderSentTableViewCell).lastDate.text = "Problema con il pagamento"
                (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                (cell as! OrderSentTableViewCell).createDate.text = ""
                
            case .pending:
                (cell as! OrderSentTableViewCell).lastDate.text = ""
                (cell as! OrderSentTableViewCell).createDate.text = "Clicca per verificare il pagamento"
                (cell as! OrderSentTableViewCell).createDate.textColor = UIColor.red
                
            case .valid:
                (cell as! OrderSentTableViewCell).createDate.textColor = UIColor.gray
                switch orderSent.offerState {
                case .expired:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine scaduto"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .refused:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine rifiutato"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .pending:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine inviato"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
                    (cell as! OrderSentTableViewCell).createDate.textColor = UIColor.gray
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .accepted:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine accettato"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .forward:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine inoltrato"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .scaled:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Ordine scalato"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
                    (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: offerCreationDate)
                    
                case .consumed:
                    (cell as! OrderSentTableViewCell).lastDate.text = ""
                    if orderSent.consumingDate != nil {
                        (cell as! OrderSentTableViewCell).createDate.text = "Ordine consumato il " + stringTodate(dateString: orderSent.consumingDate!)
                        (cell as! OrderSentTableViewCell).createDate.textColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
                    }
                    
                case .ransom:
                    break
                }
            }
            (cell as! OrderSentTableViewCell).productus.text = "Prodotti totali: " + String(orderSent.prodottiTotali)
            (cell as! OrderSentTableViewCell).cost.text = "€ " + String(format:"%.2f",orderSent.costoTotale)
            
            CacheImage.getImage(url: orderSent.userDestination?.pictureUrl, onCompletion: { (image) in
                guard image != nil else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as! OrderSentTableViewCell).friendImageView.image = image
                    }
                })
            })
        } else if (self.drinksList_segmentControl.selectedSegmentIndex == 1 && !self.ordersReceived.isEmpty) {
            
            cell = tableView.dequeueReusableCell(withIdentifier: "myDrinksRiceivedCell", for: indexPath)
            
            guard !self.ordersReceived.isEmpty else {
                cell.textLabel?.text = "Nessun drink ricevuto"
                return cell
            }
            
            let orderReceived = self.ordersReceived[indexPath.row]
            
            if orderReceived.orderReaded != nil {
                if !(orderReceived.orderReaded)! {
                    (cell as! OrderReceivedTableViewCell).cellReaded = false
                } else {
                    (cell as! OrderReceivedTableViewCell).cellReaded = true
                }
            }
            if orderReceived.dataCreazioneOfferta != nil {
                 (cell as! OrderReceivedTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: (orderReceived.dataCreazioneOfferta)!)
            }
            if orderReceived.offerState == .expired {
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Ordine scaduto"
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
            } else if orderReceived.offerState == .refused {
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Ordine rifiutato"
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
            } else if orderReceived.offerState == .consumed{
                (cell as! OrderReceivedTableViewCell).createDate.text = ""
                if orderReceived.consumingDate != nil {
                    (cell as! OrderReceivedTableViewCell).lastDate.text = "Ordine consumato il " + stringTodate(dateString: (orderReceived.consumingDate)!)
                    (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
                }
            } else if orderReceived.offerState == .scaled {
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Ordine scalato"
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
            } else {
                if orderReceived.expirationeDate != nil  {
                    (cell as! OrderReceivedTableViewCell).lastDate.text = "Scade il: " + stringTodate(dateString: (orderReceived.expirationeDate)!)
                    (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
                }
            }
            (cell as! OrderReceivedTableViewCell).productus.text = "Prodotti totali: " + String(orderReceived.prodottiTotali)
            (cell as! OrderReceivedTableViewCell).cost.text = "€ " + String(format:"%.2f",orderReceived.costoTotale)
            (cell as! OrderReceivedTableViewCell).ordersSentAutoId = orderReceived.idOfferta
            (cell as! OrderReceivedTableViewCell).orderReceivedAutoId = orderReceived.orderAutoId
            (cell as! OrderReceivedTableViewCell).friendFullName.text = orderReceived.userSender?.fullName
            
            CacheImage.getImage(url: orderReceived.userSender?.pictureUrl, onCompletion: { (image) in
                guard image != nil else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as? OrderReceivedTableViewCell)?.friendImageView.image = image
                    }
                })
            })
            
            if orderReceived.offerState == .accepted { //"Pending"
                //cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            } else if orderReceived.offerState == .pending {
                cell.accessoryType = UITableViewCellAccessoryType.none
            } else if orderReceived.offerState == .consumed {
                cell.accessoryType = UITableViewCellAccessoryType.none
                (cell as? OrderReceivedTableViewCell)?.cellReaded = true
            } else if orderReceived.offerState == .scaled {
                //cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
                (cell as? OrderReceivedTableViewCell)?.cellReaded = true
            }
        }
        return cell
    }
    
    private func stringTodateObject(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        guard let date = dateFormatter.date(from: date) else { return Date()}
        return  date
    }
    
    private func scheduleExpiryNotification(order: Order){
        //scheduling notification appearing in expirationDate
        guard let notificationIsScheduled = order.orderNotificationIsScheduled,
            let companyId = order.company?.companyId,
            let userIdApp = self.user?.idApp,
            let expirationDate = order.expirationeDate
        else { return }
        
        if !notificationIsScheduled {
            NotificationsCenter.scheduledExpiratedOrderLocalNotification(title: "Ordine scaduto", body: "Il prodotto che ti è stato offerto  è scaduto", identifier:"expirationDate-"+order.idOfferta!, expirationDate: self.stringTodateObject(date: expirationDate))
            print("Notifica scadenza schedulata correttamente")
            order.orderNotificationIsScheduled = true
            FireBaseAPI.updateNode(node: "ordersReceived/\(userIdApp)/\(companyId)/\(order.orderAutoId)", value: ["orderNotificationIsScheduled":true])
            
        }
    }
    
    //    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    //        if self.drinksList_segmentControl.selectedSegmentIndex == 0 {
    //            print("**// indexPath:\(indexPath.row), ordersSent= \(ordersSent.count)")
    //            guard !(indexPath.row == ordersSent.count - Constants.FetchThreshold - 1) else {
    //                return
    //            }
    //            if indexPath.row == ordersSent.count - Constants.FetchThreshold && indexPath.row <= Constants.FetchLimit  {
    //                guard !finishOrdersSent else {
    //                    print("**// array finito")
    //                    return
    //                }
    //                print("**// new ordersSent range request loaded")
    //                FirebaseData.sharedIstance.readOrdersSentOnFireBaseRange(user: self.user!, onCompletion: { (order) in
    //                    guard let orderRange = order else {
    //                        return
    //                    }
    //                    print("**// new order range requested, dimension: \(orderRange.count)")
    ////                    guard self.ordersSent.count < orderRange.count else {
    ////                        self.finishOrdersSent = true
    ////                        print("**// array ugual finished == true")
    ////                        print("**// orderSent dimension: \(self.ordersSent.count) order dimension: \(orderRange.count)")
    ////                        return
    ////                    }
    //                    self.ordersSent = orderRange
    //                    print("order sent dimension: \(self.ordersSent.count)")
    //                    self.myTable.reloadData()
    //                })
    //                finishOrdersSent = false
    //            }
    //        } else {
    //            print("**// indexPath:\(indexPath.row), ordersSent= \(ordersReceived.count)")
    //            guard !(indexPath.row == ordersReceived.count - Constants.FetchThreshold - 1) else {
    //                return
    //            }
    //            if indexPath.row == ordersReceived.count - Constants.FetchThreshold && indexPath.row  <= Constants.FetchLimit {
    //                guard !finishOrdersReceived else {
    //                    print("**// array finito")
    //                    return
    //                }
    //                print("**// new ordersSent range request loaded")
    //                FirebaseData.sharedIstance.readOrdersReceivedOnFireBaseRange(user: self.user!, onCompletion: { (order) in
    //
    //                    guard let orderReceivedRange = order else {
    //                        return
    //                    }
    //                    print("**// letto nuovo array ordini ordersSent= \(orderReceivedRange.count)")
    ////                    guard self.ordersReceived.count < orderReceivedRange.count else {
    ////                        self.finishOrdersReceived = true
    ////                        print("**// array ugual finished == true")
    ////                        print("**// orderSent dimension: \(self.ordersReceived.count) order dimension: \(orderReceivedRange.count)")
    ////                        return
    ////                    }
    //                    print("ordini ricevuti sta per essere aggiornato. Attuale dimension: \(self.ordersReceived.count)")
    //                    self.ordersReceived = orderReceivedRange
    //                    print("ordini ricevuti aggiornato. Attuale dimensione \(self.ordersReceived.count)")
    //                    print("order sent dimension: \(self.ordersReceived.count)")
    //                    self.myTable.reloadData()
    //                })
    //                self.finishOrdersReceived = false
    //            }
    //        }
    //    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        
        guard offsetY > 0 else { return }
        
        if offsetY > contentHeight - scrollView.frame.height {
            if self.drinksList_segmentControl.selectedSegmentIndex == 0 {
                if !fetchingMoreOrdersSent {
                    beginFetchOrdersSent()
                }
            } else if self.drinksList_segmentControl.selectedSegmentIndex == 1 {
                if !fetchingMoreOrdersReceived {
                    beginFetchOrdersReceived()
                }
            }
        }
    }
    
    private func deleteDuplicate(_ orders: inout [Order]){
        for order in orders {
            orders = orders.filter({$0.timeStamp != order.timeStamp})
            orders.append(order)
        }
    }
    
    private func beginFetchOrdersSent() {
        guard let user = self.user else { return }
        fetchingMoreOrdersSent = true
        
        FirebaseData.sharedIstance.readOrdersSentOnFireBaseRange(user: user, onCompletion: { (order) in
            //if orderSent view has the first group of element minor the vie dim page, fetch other data
            if self.ordersSent.count < self.pageTableView && FirebaseData.sharedIstance.totalNumberOrdersSentReaded < FirebaseData.sharedIstance.totalNumberOrdersSent{
                self.beginFetchOrdersSent()
            }
            DispatchQueue.main.async(execute: {
                self.fetchingMoreOrdersSent = false
                guard let orderRange = order else {return}
                
                self.ordersSent = self.ordersSent + orderRange.filter{$0.viewState != .deleted}
                self.deleteDuplicate(&self.ordersSent)
                print("****// order sent dimension from interface: \(self.ordersSent.count)")
                self.myTable.reloadData()
            })
        })
    }
    
    private func beginFetchOrdersReceived() {
        guard let user = self.user else { return }
        fetchingMoreOrdersReceived = true
        
        FirebaseData.sharedIstance.readOrdersReceivedOnFireBaseRange(user: user, onCompletion: { (order) in
            if self.ordersReceived.count < self.pageTableView && FirebaseData.sharedIstance.totalNumberOrdesReceivedReaded < FirebaseData.sharedIstance.totalNumberOrdesReceived{
                self.beginFetchOrdersReceived()
            }
            DispatchQueue.main.async(execute: {
                self.fetchingMoreOrdersReceived = false
                guard let orderRange = order else {return}
                
                self.ordersReceived = self.ordersReceived + orderRange.filter{ $0.viewState != .deleted }
                self.deleteDuplicate(&self.ordersReceived)
                print("order received dimension: \(self.ordersReceived.count)")
                self.myTable.reloadData()
            })
        })
    }
    
    private func scheduleRememberExpiryNotification(order: Order){
        let ref = Database.database().reference()
        
        ref.child("sessions").setValue(ServerValue.timestamp())
        
        ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
            guard let timeStamp = snap.value as? TimeInterval,
                let orderExpirationDate = order.expirationeDate
                else { return }
            
            let date = NSDate(timeIntervalSince1970: timeStamp/1000)
            
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
            
            guard let expirationDate = date1Formatter.date(from: orderExpirationDate) else { return }
            let components = Calendar.current.dateComponents([.day], from: currentDate, to: expirationDate)
        
            guard let notificationIsScheduled = order.orderExpirationNotificationIsScheduled,
                let offerId = order.idOfferta,
                let companyId = order.company?.companyId,
                let userIdApp = self.user?.idApp
                else { return }
            
            if  components.day! <= 2 && !notificationIsScheduled{
                DispatchQueue.main.async {
                    NotificationsCenter.scheduledRememberExpirationLocalNotification(title: "Ordine in scadenza", body: "l'ordine di € \(order.totalReadedFromFirebase) è in scadenza, affrettati a consumare", identifier: "RememberExpiration-"+offerId)
                    order.orderExpirationNotificationIsScheduled = true
                    FireBaseAPI.updateNode(node: "ordersReceived/\(userIdApp)/\(companyId)/\(order.orderAutoId)", value: ["orderExpirationNotificationIsScheduled":true])
                }
            }
        })
    }
    
    /*
     DISABLE FULL SWIPE
     
     @available(iOS 11.0, *)
     func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
     let refuseOrderAction = UIContextualAction(style: .destructive, title: "Rifiuta") { (action, sourceView, completionHandler) in
     completionHandler(true)
     }
     let acceptOrderAction = UIContextualAction(style: .normal, title: "Accetta") { (action, sourceView, completionHandler) in
     completionHandler(true)
     }
     
     let swipeAction = UISwipeActionsConfiguration(actions: [refuseOrderAction,acceptOrderAction])
     swipeAction.performsFirstActionWithFullSwipe = false // This is the line which disables full swipe
     return swipeAction
     }*/
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        
        if self.drinksList_segmentControl.selectedSegmentIndex == 1 {
            switch self.ordersReceived[indexPath.row].offerState {
            case .accepted:
                return nil
            case .pending:
                
                //Action refuse order
                let refuseOrderAction = UITableViewRowAction(style: .destructive, title: "Rifiuta") { (action, index) in
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Rifiuta' rifiuterai il prodotto che ti è stato offerto", indexPath: indexPath )
                    self.resetSegmentControl1()
                }
                refuseOrderAction.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                
                //Action accept order
                let acceptOrderAction = UITableViewRowAction(style: .normal, title: "Accetta") { (action, index) in
                    (thisCell as? OrderReceivedTableViewCell)?.cellReaded = true
                    FirebaseData.sharedIstance.user = self.user
                    
                    guard let userFullName = self.user?.fullName,
                        let userIdApp = self.user?.idApp,
                        let companyId = self.ordersReceived[indexPath.row].company?.companyId,
                        let userSenderIdApp = self.ordersReceived[indexPath.row].userSender?.idApp,
                        let offerId = self.ordersReceived[indexPath.row].idOfferta
                        else { return }
                        
                    FirebaseData.sharedIstance.acceptOrder(state: "Offerta accettata", userFullName: userFullName, userIdApp: userIdApp, comapanyId: companyId, userSenderIdApp: userSenderIdApp, idOrder: offerId, autoIdOrder: self.ordersReceived[indexPath.row].orderAutoId)
                    
                    self.scheduleExpiryNotification(order: self.ordersReceived[indexPath.row])
                    self.scheduleRememberExpiryNotification(order: self.ordersReceived[indexPath.row])
                    self.ordersReceived[indexPath.row].acceptOffer()
                    tableView.setEditing(false, animated: true)
                    self.performSegue(withIdentifier: "segueToOrderDetails", sender: indexPath)
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.resetSegmentControl1()
                    self.myTable.reloadData()
                }
                acceptOrderAction.backgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
                
                //Action forward order
                /*
                 let forwardOrderAction = UITableViewRowAction(style: .default, title: "Inoltra ") { (action, index) in
                 (thisCell as? OrderReceivedTableViewCell)?.cellReaded = true
                 self.updateStateOnFirebase(order: self.ordersReceived[indexPath.row],state: "Offerta inoltrata")
                 self.ordersReceived[indexPath.row].forwardOffer()
                 tableView.setEditing(false, animated: true)
                 tableView.deselectRow(at: indexPath, animated: true)
                 let msg = "Il tuo amico " + (self.user?.fullName)!  + " ha inoltrato il tuo ordine"
                 NotificationsCenter.sendNotification(userIdApp: (self.ordersReceived[indexPath.row].userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                 FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.ordersReceived[indexPath.row].userSender?.idApp)!, recOrPurch: "purchased")
                 self.myTable.reloadData()
                 self.resetSegmentControl1()
                 }
                 forwardOrderAction.backgroundColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)*/
                
                return [refuseOrderAction, acceptOrderAction]
                
            case .expired:
                //Action delete order
                
                let deleteOrderAction = UITableViewRowAction(style: .destructive, title: "Elimina") { (action, index) in
                    guard let userIdApp = self.user?.idApp,
                        let companyId = (self.ordersReceived[indexPath.row].company?.companyId)
                        else { return }
                
                    FirebaseData.sharedIstance.deleteOrderOnFirebase(node: "ordersReceived", userIdApp: userIdApp, comapanyId: companyId, autoIdOrder: self.ordersReceived[indexPath.row].orderAutoId, viewState: Order.ViewStates.deleted.rawValue)
                    
                    tableView.setEditing(false, animated: true)
                    self.ordersReceived.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
                deleteOrderAction.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
                return [deleteOrderAction]
                
            case  .consumed:
                let deleteOrderAction = UITableViewRowAction(style: .destructive, title: "Elimina") { (action, index) in
                    guard let userIdApp = self.user?.idApp,
                        let companyId = (self.ordersReceived[indexPath.row].company?.companyId)
                        else { return }
                    
                    FirebaseData.sharedIstance.deleteOrderOnFirebase(node: "ordersReceived", userIdApp: userIdApp, comapanyId: companyId, autoIdOrder: self.ordersReceived[indexPath.row].orderAutoId, viewState: Order.ViewStates.deleted.rawValue)
                    
                    tableView.setEditing(false, animated: true)
                    self.ordersReceived[indexPath.row].viewState = .deleted
                    self.ordersReceived.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
                deleteOrderAction.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
                return [deleteOrderAction]
                
            default:
                return nil
            }
        }
        else {
            switch self.ordersSent[indexPath.row].offerState {
            case .refused, .expired:
                //Action Add to credits
                let addToYourCredits = UITableViewRowAction(style: .destructive, title: "Aggiungi\nai crediti") { (action, index) in
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Aggiungi' aggiungerai \(((thisCell as? OrderSentTableViewCell)?.cost.text)!) ai tuoi crediti. Utilizza i tuoi crediti per effetuare un acquisto futuro", indexPath: indexPath )
                    self.resetSegmentControl0()
                }
                addToYourCredits.backgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
                
                //Action forward order
                let forwardOrderAction = UITableViewRowAction(style: .default, title: "Inoltra  ") { (action, index) in
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Inoltra' invierai i prodotti dell'ordine ad un altro amico", indexPath: indexPath )
                    self.resetSegmentControl0()
                }
                forwardOrderAction.backgroundColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
                //Action ransom order
                let ransomOrder = UITableViewRowAction(style: .destructive, title: "Riscatta") { (action, index) in
                    //tableView.setEditing(false, animated: true)
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Riscatta' sarai tu stesso ad usufruire dell'ordine", indexPath: indexPath )
                    self.resetSegmentControl0()
                }
                ransomOrder.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                return [ransomOrder,forwardOrderAction, addToYourCredits]
            case  .consumed:
                let deleteOrderAction = UITableViewRowAction(style: .destructive, title: "Elimina") { (action, index) in
                    guard let userIdApp = self.user?.idApp,
                        let companyId = self.ordersSent[indexPath.row].company?.companyId
                        else { return }
                    
                    FirebaseData.sharedIstance.deleteOrderOnFirebase(node: "ordersSent", userIdApp: userIdApp, comapanyId: companyId, autoIdOrder: self.ordersSent[indexPath.row].orderAutoId, viewState: Order.ViewStates.deleted.rawValue)
                    
                    tableView.setEditing(false, animated: true)
                    self.ordersSent[indexPath.row].viewState = .deleted
                    self.ordersSent.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
                deleteOrderAction.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
                return [deleteOrderAction]
                
            default:
                return nil
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if self.drinksList_segmentControl.selectedSegmentIndex == 1 {
            precondition(indexPath.row < ordersReceived.count)
            switch ordersReceived[indexPath.row].offerState {
            case .accepted:
                return false
            default:
                return true
            }
        } else {
            precondition(indexPath.row < ordersSent.count)
            switch ordersSent[indexPath.row].offerState {
            case .accepted:
                return false
            case .pending:
                return false
            default:
                return true
            }
        }
    }
    
    @IBAction func segmentControl_clicked(_ sender: UISegmentedControl) {
        
        if sender.selectedSegmentIndex == 0 {
            print("segment control clicked pari a 0")
            //da impelemtare la notifica per i pagamenti inviati appena vatto il pagamento il quale si trova ancora nello stato pending
            if self.drinksList_segmentControl.titleForSegment(at: 0) != "Inviati" {
                OrdersListManager.instance.refreshOrdersList()
                print("ho aggiornato gli Ordini-Inviati da Firebase")
            }
            self.resetSegmentControl0()
            self.myTable.reloadData()
            print("non ho aggiornato gli Ordini-Inviati da Firebase")
        } else if sender.selectedSegmentIndex == 1{
            print("segment control clicked pari a 1")
            if self.drinksList_segmentControl.titleForSegment(at: 1) != "Ricevuti" {
                OrdersListManager.instance.refreshOrdersList()
                print("ho aggiornato gli Ordini-Ricevuti da Firebase")
            }
            self.resetSegmentControl1()
            self.myTable.reloadData()
            print("non ho aggiornato gli Ordini-Ricevuti da Firebase")
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
        self.drinksList_segmentControl.changeUnderlinePosition()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath)
        if  thisCell is OrderReceivedTableViewCell  {
            let orderReceived = ordersReceived[indexPath.row]
            if  orderReceived.offerState == .accepted ||  orderReceived.offerState == .scaled {
                /*if drinksList_segmentControl.titleForSegment(at: 1) != "Ricevuti" {
                 OrdersListManager.instance.refreshOrdersList()
                 print("ho aggiornato gli Ordini-Ricevuti da Firebase")
                 }*/
                performSegue(withIdentifier: "segueToOrderDetails", sender: indexPath)
                tableView.deselectRow(at: indexPath, animated: true)
            }else if orderReceived.offerState == .pending {
                var msg = "Dettaglio:\n"
                for i in orderReceived.prodotti! {
                    msg += "\(i.quantity!) " + i.productName! + "\n"
                }
                msg += "\nFai swipe sulla riga:\nAccetta o Rifiuta l'offerta"
                if orderReceived.userSender?.fullName != nil {
                    self.generateAlert(title: "Guarda cosa ti ha offerto \((orderReceived.userSender?.fullName)!)", msg: msg, indexPath: indexPath )
                }
            }
            resetSegmentControl1()
            
            
            myTable.reloadData()
            
            guard let userIdApp = self.user?.idApp,
                let companyId = orderReceived.company?.companyId
            else { return }
            if ordersReceived[indexPath.row].offerState != .pending {
                ordersReceived[indexPath.row].orderReaded = true
                FireBaseAPI.updateNode(node: "ordersReceived/\(userIdApp)/\(companyId)/\( orderReceived.orderAutoId)", value: ["orderReaded" : "true"])
            }
            
            
        } else if thisCell is OrderSentTableViewCell {
            let orderSent = self.ordersSent[indexPath.row]
            if (thisCell as! OrderSentTableViewCell).createDate.text == "Clicca per verificare il pagamento" {
                startActivityIndicator("Processing...")
                pendingPaymentId = orderSent.pendingPaymentAutoId
                readAndSolvePendingPayPalPayment(order: orderSent,paymentId: pendingPaymentId){
                    print("Pending payments resolved")
                }
                tableView.deselectRow(at: indexPath, animated: true)
            } else {
                if self.drinksList_segmentControl.titleForSegment(at: 0) != "Inviati" {
                    OrdersListManager.instance.refreshOrdersList()
                    print("ho aggiornato gli Ordini-Inviati da Firebase")
                }
                performSegue(withIdentifier: "segueToOrderOfferedDetails", sender: indexPath)
                tableView.deselectRow(at: indexPath, animated: true)
                resetSegmentControl0()
            }
            //(thisCell as? OrderSentTableViewCell)?.cellReaded = true
            self.ordersSent[indexPath.row].orderReaded = true
            myTable.reloadData()
            
            guard let userIdApp = self.user?.idApp,
                let companyId = orderSent.company?.companyId
                else { return }
            
            FireBaseAPI.updateNode(node: "ordersSent/\(userIdApp)/\(companyId)/\(orderSent.idOfferta!)", value: ["orderReaded" : "true"])
            
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath) as? OrderReceivedTableViewCell
        thisCell?.cellReaded = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToOrderDetails":
            guard let path = sender else {return}
            let offertaRicevuta = self.ordersReceived[(path as! IndexPath).row]
            (segue.destination as! QROrderGenerationViewController).offertaRicevuta = offertaRicevuta
            (segue.destination as! QROrderGenerationViewController).user = user
            (segue.destination as! QROrderGenerationViewController).dataScadenza = offertaRicevuta.expirationeDate
            guard self.ordersReceived[(path as! IndexPath).row].orderReaded == false else {return}
            break
            
        case "segueToOrderOfferedDetails":
            guard let path = sender else {return}
            let orderSent = self.ordersSent[(path as! IndexPath).row]
            (segue.destination as! OrderSentDetailsViewController).offertaInviata = orderSent
            break
            
        case "segueToForwardToFriend":
            (segue.destination as! FriendsListViewController).segueFrom = "myDrinks"
            (segue.destination as! FriendsListViewController).forwardOrder = forwardOrder
            break
            
        default:
            break
        }
    }
    
    func startActivityIndicator(_ title: String) {
        strLabel.removeFromSuperview()
        activityIndicator.removeFromSuperview()
        effectView.removeFromSuperview()
        strLabel = UILabel(frame: CGRect(x: 50, y: 0, width: 170, height: 46))
        strLabel.text = title
        strLabel.font = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.medium)
        strLabel.textColor = UIColor(white: 0.9, alpha: 0.7)
        effectView.frame = CGRect(x: view.frame.midX - strLabel.frame.width/2, y: view.frame.midY - strLabel.frame.height/2 , width: 200, height: 46)
        effectView.layer.cornerRadius = 15
        effectView.layer.masksToBounds = true
        
        //activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.white
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 46, height: 46)
        activityIndicator.startAnimating()
        
        effectView.contentView.addSubview(activityIndicator)
        effectView.contentView.addSubview(strLabel)
        self.view.addSubview(effectView)
        UIApplication.shared.beginIgnoringInteractionEvents()
        
    }
    
    func stopActivityIndicator() {
        strLabel.removeFromSuperview()
        activityIndicator.removeFromSuperview()
        effectView.removeFromSuperview()
        activityIndicator.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }
    
    private func generateAlert(title: String, msg: String, indexPath: IndexPath?){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        let action: UIAlertAction?
        let actionAnnulla: UIAlertAction?
        switch msg {
        case let x where (x.range(of:"'Aggiungi'") != nil):
            action = UIAlertAction(title: "Aggiungi ai tuoi crediti", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Il messaggio di chiusura è stato premuto")
                    if let range = msg.range(of: "€ ") {
                        let credit = msg[range.upperBound...].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first!
                        ManageCredits.updateCredits(newCredit: credit, userId: (self.user?.idApp)!, onCompletion: { (error) in
                            guard error == nil else {
                                self.generateStandardAlert()
                                return
                            }
                            self.showSuccess()
                            
                        })
                    }
                    //Delete Order
                    if indexPath != nil {
                        FirebaseData.sharedIstance.deleteOrderOnFirebase(node: "ordersSent", userIdApp: (self.user?.idApp)!, comapanyId: (self.ordersSent[(indexPath?.row)!].company?.companyId)!, autoIdOrder: self.ordersSent[(indexPath?.row)!].orderAutoId, viewState: Order.ViewStates.deleted.rawValue)
                        //self.myTable.deleteRows(at: [indexPath!], with: .fade)
                        self.ordersSent.remove(at: (indexPath?.row)!)
                    }
                    self.myTable.reloadData()
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Il messaggio di chiusura è stato premuto")
            })
            break
        case let x where (x.range(of:"'Rifiuta'") != nil):
            action = UIAlertAction(title: "Rifiuta", style: UIAlertActionStyle.default, handler: {(paramAction:UIAlertAction!) in
                print("'Rifiuta' è stato cliccato")
                FirebaseData.sharedIstance.user = self.user
                FirebaseData.sharedIstance.refuseOrder(state: "Offerta rifiutata", userFullName: (self.user?.fullName)!, userIdApp: (self.user?.idApp)!, comapanyId: (self.ordersReceived[(indexPath?.row)!].company?.companyId)!, userSenderIdApp: (self.ordersReceived[(indexPath?.row)!].userSender?.idApp)!, idOrder: self.ordersReceived[(indexPath?.row)!].idOfferta!, autoIdOrder: self.ordersReceived[(indexPath?.row)!].orderAutoId)
                self.ordersReceived[(indexPath?.row)!].refuseOffer()
                //FirebaseData.sharedIstance.deleteOrderReceveidOnFirebase(order: self.ordersReceived[(indexPath?.row)!])
                
                self.ordersReceived.remove(at: (indexPath?.row)!)
                self.myTable.deleteRows(at: [indexPath!], with: .fade)
                
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("'Annulla' è stato cliccato")
            })
            break
        case let x where (x.range(of:"'Riscatta'") != nil):
            action = UIAlertAction(title: "Riscatta", style: UIAlertActionStyle.default, handler:{(paramAction:UIAlertAction!) in
                print("Riscatta è stato premuto")
                //update order state
                self.forwardOrder = self.ordersSent[(indexPath?.row)!]
                self.oldFriendDestination = UserDestination(nil, self.forwardOrder?.userDestination?.idFB, nil, self.forwardOrder?.userDestination?.idApp, nil)
                self.forwardOrder?.userDestination?.idApp = self.user?.idApp
                self.forwardOrder?.userDestination?.idFB = self.user?.idFB
                FireBaseAPI.updateNode(node: "ordersSent/\((self.user?.idApp)!)/\((self.forwardOrder?.company?.companyId)!)/\((self.forwardOrder?.idOfferta)!)", value: ["IdAppUserDestination" : (self.user?.idApp)!, "facebookUserDestination":(self.user?.idFB)!,"offerState":"Offerta riscattata"])
                
                FirebaseData.sharedIstance.moveFirebaseRecord(userApp: self.user!,user: self.oldFriendDestination!, company: (self.forwardOrder?.company?.companyId)!, order: self.forwardOrder!, onCompletion: { (error) in
                    guard error == nil else {
                        self.generateAlert(title: "Errore", msg: error!, indexPath: nil)
                        return
                    }
                    self.showSuccess()
                    self.ordersSent.remove(at: (indexPath?.row)!)
                    self.myTable.deleteRows(at: [indexPath!], with: .fade)
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.user?.idApp)!, recOrPurch: "received")
                   
                })
                
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Il messaggio di chiusura è stato premuto")
            })
            break
        case let x where (x.range(of:"'Dettaglio'") != nil):
            action = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Il messaggio di chiusura è stato premuto")
            })
            actionAnnulla = UIAlertAction()
            break
        case let x where (x.range(of:"'Inoltra'") != nil):
            action = UIAlertAction(title: "Inoltra", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Inoltra è stato premuto")
                    self.forwardOrder = self.ordersSent[(indexPath?.row)!]
                    self.oldFriendDestination = UserDestination(nil, self.forwardOrder?.userDestination?.idFB, nil, self.forwardOrder?.userDestination?.idApp, nil)
                    self.performSegue(withIdentifier: "segueToForwardToFriend", sender: nil)
                    
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Annulla è stato premuto")
            })
            break
        case let x where (x.range(of:"non è andato a buon fine") != nil):
            action = UIAlertAction(title: "Riprova", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Riprova è stato premuto")
                    self.startActivityIndicator("Processing...")
                    self.readAndSolvePendingPayPalPayment(order: self.ordersSent[(indexPath?.row)!] , paymentId: self.pendingPaymentId){
                        print("Pending payments resolved")
                    }
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Annulla è stato premuto")
            })
            break
        default:
            action = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("ok è stato premuto")
                    self.myTable.reloadData()
            })
            actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
                {(paramAction:UIAlertAction!) in
                    print("Il messaggio di chiusura è stato premuto")
            })
            break
        }
        controller!.addAction(action!)
        controller!.addAction(actionAnnulla!)
        self.present(controller!, animated: true, completion: nil)
    }
    
    lazy var refreshControl1: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        if CheckConnection.isConnectedToNetwork() == true {
            refreshControl.beginRefreshing()
            myTable.isUserInteractionEnabled = false
            ordersSent.removeAll()
            ordersReceived.removeAll()
            print("**// order sent and received initializated, finish = false, refresh request")
            OrdersListManager.instance.refreshOrdersList()
            productSendBadge.set(0, forKey: "paymentOfferedBadge")
            
            (drinksList_segmentControl.selectedSegmentIndex == 0) ? self.productSendBadge.set(0, forKey: "paymentOfferedBadge") : productSendBadge.set(0, forKey: "productOfferedBadge")
            
            if firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
                firebaseObserverKilled.set(false, forKey: "firebaseObserverKilled")
            }
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    private func showSuccess() {
        
        successView.isHidden = false
        successView.alpha = 1.0
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(0.5)
        UIView.setAnimationDelay(2.0)
        successView.alpha = 0.0
        UIView.commitAnimations()
    }
    
    private func stringTodate(dateString: String) ->String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        dateFormatter.locale = Locale.init(identifier: "it_IT")
        
        guard let dateObj = dateFormatter.date(from: dateString) else { return dateFormatter.string(from: Date()) }
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.string(from: dateObj)
    }
    
    @IBAction func unwindToMyDrinksWitoutValue(_ sender: UIStoryboardSegue) {
        print("unwind eseguito")
    }
    
    @IBAction func unwindToMyDrinks(_ sender: UIStoryboardSegue) {
        guard sender.identifier != nil else {
            return
        }
        
        switch sender.identifier! {
        case "unwindFromFriendsListToMyDrinks":
            guard let forwarOrderUserDestinationId = forwardOrder?.userDestination?.idFB else { return }
            
            FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "idFB", idFB: forwarOrderUserDestinationId, onCompletion: { (error,idApp) in
                guard error == nil, idApp != nil  else {
                    print(error!)
                    return
                }
                
                self.forwardOrder?.userDestination?.idApp = idApp!
                guard let userIdApp  = self.user?.idApp,
                    let forwardCompanyId = self.forwardOrder?.company?.companyId,
                    let forwardOfferId = self.forwardOrder?.idOfferta,
                    let forwardUserDestinationIdApp = self.forwardOrder?.userDestination?.idApp,
                    let forwardUserDestinationIdFB = self.forwardOrder?.userDestination?.idFB,
                    let user = self.user,
                    let olderFriendDestination = self.oldFriendDestination,
                    let orderForwarder = self.forwardOrder,
                    let oldFriendDestinationIdApp = self.oldFriendDestination?.idApp
                    else { return }
                
                FireBaseAPI.updateNode(node: "ordersSent/\(userIdApp)/\(forwardCompanyId)/\(forwardOfferId)", value: ["IdAppUserDestination" : forwardUserDestinationIdApp, "facebookUserDestination":forwardUserDestinationIdFB, "offerState":"Pending"])
                
                FirebaseData.sharedIstance.moveFirebaseRecord(userApp: user,user: olderFriendDestination, company: forwardCompanyId, order: orderForwarder, onCompletion: { (error) in
                    guard error == nil else {
                        self.generateAlert(title: "Errore", msg: error!, indexPath: nil)
                        return
                    }
                    self.showSuccess()
                    
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase(oldFriendDestinationIdApp, recOrPurch: "received")
                    
                })
                
            })
            break
        case "unwindToMyDrinks":
            
            break
        default:
            break
        }
    }
    
}
