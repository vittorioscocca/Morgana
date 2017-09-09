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



class MyDrinksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var drinksList_segmentControl: UISegmentedControl!
    @IBOutlet var successView: UIView!
    
    var user: User?
    var friendsList: [Friend]?
    var uid: String?
    var nowReadingOrdersAndOffersOnFirebase: Bool?
    
    //device memory
    var fireBaseToken = UserDefaults.standard
    var productSendBadge = UserDefaults.standard
    var lastOrderSentReadedTimestamp = UserDefaults.standard
    var lastOrderReceivedReadedTimestamp = UserDefaults.standard
    var firebaseObserverKilled = UserDefaults.standard
    
    var imageCache = [String:UIImage]()
    var ordersSent = [Order]()
    var ordersReceived = [Order]()
    //var pendingPayments = [Payment]()
    
    var payPalAccessToken = String()
    var PayPalPaymentDataDictionary: NSDictionary?
    
   //Alert Controller
    var controller :UIAlertController?
    
    //Activity Indicator
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    //forward action var
    var forwardOrder :Order?
    var oldFriendDestination: UserDestination?
    
    
    var pendingPaymentId = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.myTable.dataSource = self
        self.myTable.delegate = self
        
        self.nowReadingOrdersAndOffersOnFirebase = false
        
        self.drinksList_segmentControl.selectedSegmentIndex = 0
        self.drinksList_segmentControl.removeBorders()
        
        self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(self.uid)
        self.updateSegmentControl()
        
        self.friendsList = CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: self.uid!)
        
        self.readOrdersSent()
        self.readOrderReceived()
        self.firebaseObserverKilled.set(false, forKey: "firebaseObserverKilled")
 
        self.myTable.addSubview(refreshControl1)
        successView.isHidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updateSegmentControl()
        self.myTable.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Daily control for order expiration date
        let itsTimeToUpdate = shouldUpdateDrinksTable(SegmentControlBadge: 0, timeReaded: self.lastOrderReceivedReadedTimestamp.object(forKey: "lastOrderReceivedReadedTimestamp") as? Date)
        
        if (itsTimeToUpdate && !self.nowReadingOrdersAndOffersOnFirebase!) ||  self.firebaseObserverKilled.bool(forKey: "firebaseObserverKilled"){
            self.readOrdersSent()
            self.readOrderReceived()
            var currentDate = Date()
            currentDate = Calendar.current.date(byAdding:.hour,value: 2,to: currentDate)!
            self.lastOrderSentReadedTimestamp.set(currentDate, forKey: "lastOrderReceivedReadedTimestamp")
            if self.firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
                self.firebaseObserverKilled.set(false, forKey: "firebaseObserverKilled")
            }
            print("aggiornamento giornaliero effettuato")
        }
        
    }
    
    //remove all observers utilized into controller
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        /*
        FireBaseAPI.removeObserver(node: "users/" + (self.user?.idApp)!)
        FireBaseAPI.removeObserver(node: "orderOffered/" + (self.user?.idApp)!)
        FireBaseAPI.removeObserver(node: "orderReceived/" + (self.user?.idApp)!)*/
        self.firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
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
        let ref = FIRDatabase.database().reference()
        
        ref.child("users/" + (self.user?.idApp)!).observe(.value, with: { (snap) in
            
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let datiUtente = snap.value! as! NSDictionary
            
            for (chiave,valore) in datiUtente {
                switch chiave as! String {
                case "number of pending received products":
                    self.productSendBadge.set(valore as! Int, forKey: "productOfferedBadge")
                    break
                case "number of pending purchased products":
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
    }
    
    private func resetSegmentControl1(){
        FireBaseAPI.updateNode(node: "users/" + (self.user?.idApp)!, value: ["number of pending received products" : 0])
        self.drinksList_segmentControl.setTitle("Ricevuti", forSegmentAt: 1)
    }
    
    private func resetSegmentControl0(){
        FireBaseAPI.updateNode(node: "users/" + (self.user?.idApp)!, value: ["number of pending purchased products" : 0])
        self.drinksList_segmentControl.setTitle("Inviati", forSegmentAt: 0)
    }
    
    private func readOrdersSent(){
        self.nowReadingOrdersAndOffersOnFirebase = true

        FirebaseData.sharedIstance.readOrdersSentOnFireBase(user: self.user!, friendsList: friendsList, onCompletion: { (ordersSent) in
            guard !ordersSent.isEmpty else {
                print("errore di lettura su ordini inviati: array orderSent vuoto")
                return
            }
            self.nowReadingOrdersAndOffersOnFirebase = false
            self.ordersSent = ordersSent
            self.myTable.reloadData()
        })
    }
    
    private func readOrderReceived() {
        self.nowReadingOrdersAndOffersOnFirebase = true
        
        FirebaseData.sharedIstance.readOrderReceivedOnFireBase(user: self.user!, onCompletion: { (ordersReceived) in
            guard !ordersReceived.isEmpty else {
                print("errore di lettura su ordini inviati")
                return
            }
            self.nowReadingOrdersAndOffersOnFirebase = false
            self.ordersReceived = ordersReceived
            self.myTable.reloadData()
        })
    }

    private func readAndSolvePendingPayPalPayment(paymentId: String,onCompletion: @escaping () -> ()){
        let ref = FIRDatabase.database().reference()
        //self.pendingPayments.removeAll()

        ref.child("pendingPayments/" + (self.user?.idApp)! + "/" + paymentId).observeSingleEvent(of:.value, with: { (snap) in
            
            guard snap.exists() else {return}
            guard snap.value != nil else {return}
            
            let dizionario_pagamenti = snap.value! as! NSDictionary
            
            let payment: Payment = Payment(platform: "", paymentType: "", createTime: "", idPayment: "", statePayment: "", autoId: "",total: "")
            payment.autoId = paymentId
            var count = 0
            for (chiave,valore) in dizionario_pagamenti {
                
                switch chiave as! String {
                case "idPayment":
                    payment.idPayment = valore as? String
                    break
                case "statePayment":
                    payment.statePayment = valore as? String
                    break
                case "total":
                    payment.total = valore as? String
                    break
                case let x where (x.range(of:"offerID") != nil):
                    payment.relatedOrders.append((valore as? String)!)
                    count += 1
                    break
                case "pendingUserIdApp":
                    payment.pendingUserIdApp = (valore as? String)!
                    break
                default:
                    break
                }
            }
            PaymentManager.sharedIstance.resolvePendingPayPalPayment(user: self.user!,payment: payment, onCompleted: { (paymentVerified) in
                guard paymentVerified  else {
                    DispatchQueue.main.async {
                        // ritorno sul main thread ed aggiorno la view
                        self.stopActivityIndicator()
                    }
                    
                    print("state payement is not approved")
                    self.generateAlert(title: "Pagamento non avvenuto", msg: "Il tuo pagamento di € " + payment.total! + " non è andato a buon fine",indexPath: nil)
                    return
                }
                DispatchQueue.main.async {
                    // ritorno sul main thread ed aggiorno la view
                    self.stopActivityIndicator()
                }
                self.setPaymentCompletedInLocal(payment)
                self.generateAlert(title: "Pagamento avvenuto", msg: "Il tuo pagamento di € " + payment.total! + " è avvenuto correttamente",indexPath: nil)
            })
         onCompletion()
        })
    }
    
    private func setPaymentCompletedInLocal(_ payment: Payment){
        for i in self.ordersSent{
            for j in payment.relatedOrders{
                if i.idOfferta == j{
                    i.paymentState = "Valid"
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.drinksList_segmentControl.selectedSegmentIndex == 0 {
            return (self.ordersSent.count)
        } else {
            return (self.ordersReceived.count)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        if self.drinksList_segmentControl.selectedSegmentIndex == 0 && !self.ordersSent.isEmpty {
            var orderSent: Order?
            
            cell = tableView.dequeueReusableCell(withIdentifier: "myDrinksPurchasedCell", for: indexPath)
            guard !self.ordersSent.isEmpty else {
                cell?.textLabel?.text = "Nessun drink inviato"
                return cell!
            }
            orderSent = self.ordersSent[indexPath.row]
            if !(orderSent?.orderReaded)! {
                (cell as! OrderSentTableViewCell).cellReaded = false
            } else {
                (cell as! OrderSentTableViewCell).cellReaded = true
            }
            
            (cell as! OrderSentTableViewCell).friendFullName.text = orderSent?.userDestination?.fullName
            (cell as! OrderSentTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: (orderSent?.dataCreazioneOfferta)!)
            
            
            switch orderSent!.paymentState! {
            case "Not Valid":
                (cell as! OrderSentTableViewCell).lastDate.text = "Problema con il pagamento"
                (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                break
            case "Pending":
                (cell as! OrderSentTableViewCell).lastDate.text = ""
                (cell as! OrderSentTableViewCell).createDate.text = "Clicca per verificare il pagamento"
                (cell as! OrderSentTableViewCell).createDate.textColor = UIColor.red
                break
            case "Valid":
                switch orderSent!.offerState! {
                case "Scaduta":
                    (cell as! OrderSentTableViewCell).lastDate.text = "Offerta scaduta"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                    break
                case "Offerta rifiutata":
                    (cell as! OrderSentTableViewCell).lastDate.text = "Offerta rifiutata"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = UIColor.red
                    break
                case "Pending":
                    (cell as! OrderSentTableViewCell).lastDate.text = "Offerta inviata"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
                     (cell as! OrderSentTableViewCell).createDate.textColor = UIColor.gray
                    break
                case "Offerta accettata":
                    (cell as! OrderSentTableViewCell).lastDate.text = "Offerta accettata"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                    break
                case "Offerta inoltrata":
                    (cell as! OrderSentTableViewCell).lastDate.text = "Offerta inoltrata"
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
                    break
                default:
                    (cell as! OrderSentTableViewCell).lastDate.text = "Scade il: " + stringTodate(dateString: (orderSent?.expirationeDate)!)
                    (cell as! OrderSentTableViewCell).lastDate.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                    break
                }
            default:
                break
            }
            (cell as! OrderSentTableViewCell).productus.text = "Prodotti totali: " + String(orderSent!.prodottiTotali)
            (cell as! OrderSentTableViewCell).cost.text = "€ " + String(format:"%.2f",(orderSent?.costoTotale)!)
            
            // Start by setting the cell's image to a static file
            // Without this, we will end up without an image view!
            // If this image is already cached, don't re-download
            if let pictureUrl = orderSent?.userDestination?.pictureUrl {
                if let img = imageCache[pictureUrl] {
                    (cell as! OrderSentTableViewCell).friendImageView.image = img
                }else {
                    // The image isn't cached, download the img data
                    // We should perform this in a background thread
                    
                    //let request: NSURLRequest = NSURLRequest(url: url! as URL)
                    //let mainQueue = OperationQueue.main
                    
                    let request = NSMutableURLRequest(url: NSURL(string: (orderSent?.userDestination?.pictureUrl)!)! as URL)
                    let session = URLSession.shared
                    
                    //NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: mainQueue, completionHandler: { (response, data, error) -> Void in
                    let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                        if error == nil {
                            // Convert the downloaded data in to a UIImage object
                            let image = UIImage(data: data!)
                            // Store the image in to our cache
                            self.imageCache[(orderSent?.userDestination?.pictureUrl)!] = image
                            // Update the cell
                            DispatchQueue.main.async(execute: {
                                if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                                    (cellToUpdate as! OrderSentTableViewCell).friendImageView.image = image
                                }
                            })
                        }
                        else {
                            print("Error: \(error!.localizedDescription)")
                        }
                    })
                    task.resume()
                }

            }else {
                print("Attenzione URL immagine User non presente")
            }
            if (orderSent!.paymentState!) == "Valid" {
                cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            }else {
                cell?.accessoryType = UITableViewCellAccessoryType.checkmark
            }
        }else if (self.drinksList_segmentControl.selectedSegmentIndex == 1 && !self.ordersReceived.isEmpty) {
            var offertaRicevuta: Order?
            cell = tableView.dequeueReusableCell(withIdentifier: "myDrinksRiceivedCell", for: indexPath)
            
            guard !self.ordersReceived.isEmpty else {
                cell?.textLabel?.text = "Nessun drink ricevuto"
                return cell!
            }
            
            offertaRicevuta = self.ordersReceived[indexPath.row]
            if !(offertaRicevuta?.orderReaded)! {
                (cell as! OrderReceivedTableViewCell).cellReaded = false
            } else {
                (cell as! OrderReceivedTableViewCell).cellReaded = true
            }
            (cell as! OrderReceivedTableViewCell).friendFullName.text = offertaRicevuta?.userSender?.fullName
            (cell as! OrderReceivedTableViewCell).createDate.text = "Invio: " + stringTodate(dateString: (offertaRicevuta?.dataCreazioneOfferta)!)
            
            if offertaRicevuta?.offerState == "Scaduta" {
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Offerta scaduta"
                
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
            } else if offertaRicevuta?.offerState == "Offerta rifiutata"{
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Offerta rifiutata"
                
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1)
            } else {
                (cell as! OrderReceivedTableViewCell).lastDate.text = "Scade il: " + stringTodate(dateString: (offertaRicevuta?.expirationeDate)!)
                (cell as! OrderReceivedTableViewCell).lastDate.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            }
            (cell as! OrderReceivedTableViewCell).productus.text = "Prodotti totali: " + String(offertaRicevuta!.prodottiTotali)
            (cell as! OrderReceivedTableViewCell).cost.text = "€ " + String(format:"%.2f",(offertaRicevuta?.costoTotale)!)
            (cell as! OrderReceivedTableViewCell).orderOfferedAutoId = offertaRicevuta?.idOfferta
            (cell as! OrderReceivedTableViewCell).orderReceivedAutoId = offertaRicevuta?.orderAutoId
            
            if let pictureUrl = offertaRicevuta?.userSender?.pictureUrl{
                if let img = imageCache[pictureUrl] {
                    (cell as! OrderReceivedTableViewCell).friendImageView.image = img
                }
                else {
                    let request = NSMutableURLRequest(url: NSURL(string: (offertaRicevuta?.userSender?.pictureUrl)!)! as URL)
                    let session = URLSession.shared
                    let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                        if error == nil {
                            // Convert the downloaded data in to a UIImage object
                            let image = UIImage(data: data!)
                            // Store the image in to our cache
                            self.imageCache[(offertaRicevuta?.userSender?.pictureUrl)!] = image
                            // Update the cell
                            DispatchQueue.main.async(execute: {
                                if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                                    (cellToUpdate as! OrderReceivedTableViewCell).friendImageView.image = image
                                }
                            })
                        }
                        else {
                            print("Error: \(error!.localizedDescription)")
                        }
                    })
                    task.resume()
                }
            }else {
                print("Attenzione URL immagine User non presente")
            }
            if (offertaRicevuta!.offerState!) == "Offerta accettata" { //"Pending"
                cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            }else if (offertaRicevuta!.offerState!) == "Pending" {
                cell?.accessoryType = UITableViewCellAccessoryType.none
            }else if (offertaRicevuta!.offerState!) == "Offerta inoltrata"{
                cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
                (cell as? OrderReceivedTableViewCell)?.cellReaded = true
            }else {
                cell?.accessoryType = UITableViewCellAccessoryType.checkmark
            }
            
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        
        if self.drinksList_segmentControl.selectedSegmentIndex == 1 {
            switch self.ordersReceived[indexPath.row].offerState! {
            case "Offerta accettata":
                return nil
            case "Pending":
                
                //Action refuse order
                let refuseOrderAction = UITableViewRowAction(style: .destructive, title: "Rifiuta") { (action, index) in
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Rifiuta' rifiuterai il prodotto che ti è stato offerto", indexPath: indexPath )
                    self.resetSegmentControl1()
                }
                refuseOrderAction.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                
                //Action accept order
                let acceptOrderAction = UITableViewRowAction(style: .default, title: "Accetta") { (action, index) in
                    (thisCell as? OrderReceivedTableViewCell)?.cellReaded = true 
                    FirebaseData.sharedIstance.user = self.user
                    FirebaseData.sharedIstance.updateStateOnFirebase(order: self.ordersReceived[indexPath.row],state: "Offerta accettata")
                    self.ordersReceived[indexPath.row].acceptOffer()
                    tableView.setEditing(false, animated: true)
                    self.performSegue(withIdentifier: "segueToOrderDetails", sender: indexPath)
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.resetSegmentControl1()
                    let msg = "Il tuo amico " + (self.user?.fullName)!  + " ha accettato il tuo ordine"
                    NotitificationsCenter.sendNotification(userIdApp: (self.ordersReceived[indexPath.row].userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.ordersReceived[indexPath.row].userSender?.idApp)!, recOrPurch: "purchased")
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
                    NotitificationsCenter.sendNotification(userIdApp: (self.ordersReceived[indexPath.row].userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.ordersReceived[indexPath.row].userSender?.idApp)!, recOrPurch: "purchased")
                    self.myTable.reloadData()
                    self.resetSegmentControl1()
                }
                forwardOrderAction.backgroundColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)*/
                
                return [refuseOrderAction, acceptOrderAction]
            case "Scaduta":
                //Action delete order
                let deleteOrderAction = UITableViewRowAction(style: .destructive, title: "Elimina") { (action, index) in
                    FirebaseData.sharedIstance.deleteOrderReceveidOnFirebase(order: self.ordersReceived[indexPath.row])
                    tableView.setEditing(false, animated: true)
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
            switch self.ordersSent[indexPath.row].offerState! {
            case let x where (x == "Offerta rifiutata" || x == "Scaduta") :
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
                let ransomOrder = UITableViewRowAction(style: .default, title: "Riscatta") { (action, index) in
                    //tableView.setEditing(false, animated: true)
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.generateAlert(title: "Attenzione", msg: "Cliccando su 'Riscatta' sarai tu stesso ad usufruire dell'ordine", indexPath: indexPath )
                    self.resetSegmentControl0()
                }
                ransomOrder.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                return [ransomOrder,forwardOrderAction, addToYourCredits]
            default:
                return nil
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if self.drinksList_segmentControl.selectedSegmentIndex == 1 {
            switch self.ordersReceived[indexPath.row].offerState! {
            case "Offerta accettata":
                return false
            default:
                return true
            }
        }else{
            switch self.ordersSent[indexPath.row].offerState! {
            case "Offerta accettata":
                return false
            case "Pending":
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
                self.readOrdersSent()
                print("ho aggiornato gli Ordini-Inviati da Firebase")
            }
            self.resetSegmentControl0()
            self.myTable.reloadData()
            print("non ho aggiornato gli Ordini-Inviati da Firebase")
        } else if sender.selectedSegmentIndex == 1{
            print("segment control clicked pari a 1")
            if self.drinksList_segmentControl.titleForSegment(at: 1) != "Ricevuti" {
                self.readOrderReceived()
                print("ho aggiornato gli Ordini-Ricevuti da Firebase")
            }
            self.resetSegmentControl1()
            self.myTable.reloadData()
            print("non ho aggiornato gli Ordini-Ricevuti da Firebase")
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        if  thisCell is OrderReceivedTableViewCell  {
            let orderReceived = self.ordersReceived[indexPath.row]
            if  orderReceived.offerState == "Offerta accettata" {
                if self.drinksList_segmentControl.titleForSegment(at: 1) != "Ricevuti" {
                    self.readOrderReceived()
                    print("ho aggiornato gli Ordini-Ricevuti da Firebase")
                }
                self.performSegue(withIdentifier: "segueToOrderDetails", sender: indexPath)
                tableView.deselectRow(at: indexPath, animated: true)
                self.resetSegmentControl1()
                
            }else if orderReceived.offerState == "Pending" {
                var msg = "Dettaglio:\n"
                for i in orderReceived.prodotti! {
                    msg += "\(i.quantity!) " + i.productName! + "\n"
                }
                msg += "\nFai swipe sulla riga:\nAccetta o Rifiuta l'offerta"
                self.generateAlert(title: "Guarda cosa ti ha offerto \((orderReceived.userSender?.fullName)!)", msg: msg, indexPath: indexPath )
            }
            (thisCell as? OrderReceivedTableViewCell)?.cellReaded = true
            FireBaseAPI.updateNode(node: "orderReceived/" + (self.user?.idApp)! + "/" + orderReceived.orderAutoId, value: ["orderReaded" : "true"])
        }else if thisCell is OrderSentTableViewCell {
            let orderSent = self.ordersSent[indexPath.row]
            if (thisCell as! OrderSentTableViewCell).createDate.text == "Clicca per verificare il pagamento" {
                self.startActivityIndicator("Processing...")
                self.pendingPaymentId = orderSent.pendingPaymentAutoId
                self.readAndSolvePendingPayPalPayment(paymentId: pendingPaymentId){
                    print("Pending payments resolved")
                }
                tableView.deselectRow(at: indexPath, animated: true)
            }else {
                if self.drinksList_segmentControl.titleForSegment(at: 0) != "Inviati" {
                    self.readOrdersSent()
                    print("ho aggiornato gli Ordini-Inviati da Firebase")
                }
                self.performSegue(withIdentifier: "segueToOrderOfferedDetails", sender: indexPath)
                tableView.deselectRow(at: indexPath, animated: true)
                self.resetSegmentControl0()
            }
            (thisCell as? OrderSentTableViewCell)?.cellReaded = true
            FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + orderSent.idOfferta!, value: ["orderReaded" : "true"])
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
            guard let path = sender else {
                return
            }
            let offertaRicevuta = self.ordersReceived[(path as! IndexPath).row]
            (segue.destination as! QROrderGenerationViewController).offertaRicevuta = offertaRicevuta
            (segue.destination as! QROrderGenerationViewController).user = self.user
            (segue.destination as! QROrderGenerationViewController).dataScadenza = offertaRicevuta.expirationeDate
            
            
            guard self.ordersReceived[(path as! IndexPath).row].orderReaded == false else {
                return
            }
            break
        case "segueToOrderOfferedDetails":
            guard let path = sender else {
                return
            }
            let orderSent = self.ordersSent[(path as! IndexPath).row]
            (segue.destination as! OrderSentDetailsViewController).offertaInviata = orderSent
            break
            
        case "segueToForwardToFriend":
            (segue.destination as! ListaAmiciViewController).segueFrom = "myDrinks"
            (segue.destination as! ListaAmiciViewController).order = self.forwardOrder
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
        strLabel.font = UIFont.systemFont(ofSize: 14, weight: UIFontWeightMedium)
        strLabel.textColor = UIColor(white: 0.9, alpha: 0.7)
        
        effectView.frame = CGRect(x: view.frame.midX - strLabel.frame.width/2, y: view.frame.midY - strLabel.frame.height/2 , width: 200, height: 46)
        effectView.layer.cornerRadius = 15
        effectView.layer.masksToBounds = true
        
        //activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.white
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 46, height: 46)
        activityIndicator.startAnimating()
        
        effectView.addSubview(activityIndicator)
        effectView.addSubview(strLabel)
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
                        let credit = msg.substring(from: range.upperBound).trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first!
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
                        FirebaseData.sharedIstance.deleteOrderPurchasedOnFireBase(order: self.ordersSent[(indexPath?.row)!])
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
                    FirebaseData.sharedIstance.updateStateOnFirebase(order: self.ordersReceived[(indexPath?.row)!],state: "Offerta rifiutata")
                    self.ordersReceived[(indexPath?.row)!].refuseOffer()
                    //FirebaseData.sharedIstance.deleteOrderReceveidOnFirebase(order: self.ordersReceived[(indexPath?.row)!])
                    let msg = "Il tuo amico " + (self.user?.fullName)!  + " ha rifiutato il tuo ordine"
                    NotitificationsCenter.sendNotification(userIdApp: (self.ordersReceived[(indexPath?.row)!].userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.ordersReceived[(indexPath?.row)!].userSender?.idApp)!, recOrPurch: "purchased")
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
                    FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + (self.forwardOrder?.idOfferta)!, value: ["IdAppUserDestination" : (self.user?.idApp)!, "facebookUserDestination":(self.user?.idFB)!,"offerState":"Offerta riscattata"])
                    
                    FirebaseData.sharedIstance.moveFirebaseRecord(userApp: self.user!,user: self.oldFriendDestination!, order: self.forwardOrder!, onCompletion: { (error) in
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
                    self.readAndSolvePendingPayPalPayment(paymentId: self.pendingPaymentId){
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
        refreshControl.addTarget(self, action: #selector(ListaAmiciViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        
        return refreshControl
    }()
    
    //The view is updated only when there is a notification or another day is past
    private func shouldUpdateDrinksTable(SegmentControlBadge: Int?, timeReaded: Date?)->Bool{
        guard SegmentControlBadge != nil else {
            return false
        }
        guard timeReaded != nil else {
            return false
        }
        
        var dayLimit = Calendar.current.date(byAdding:.day,value: 1,to: timeReaded!)
        dayLimit = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: dayLimit!)
        var currentDate = Date()
        currentDate = Calendar.current.date(byAdding:.hour,value: 2,to: currentDate)!
        
        print("dayLimit:  \(dayLimit!)")
        print("current Date: \(currentDate)")

        return SegmentControlBadge != 0 || (currentDate >= dayLimit!)
        
    }

    func handleRefresh(_ refreshControl: UIRefreshControl) {
        if drinksList_segmentControl.selectedSegmentIndex == 0 {
            print("segment control clicked pari a 0")
            if shouldUpdateDrinksTable(SegmentControlBadge: self.productSendBadge.object(forKey: "paymentOfferedBadge") as? Int, timeReaded: self.lastOrderSentReadedTimestamp.object(forKey: "orderOfferedReadedTimestamp") as? Date){
                self.readOrdersSent()
                print("refresh effettuato")
                self.productSendBadge.set(0, forKey: "paymentOfferedBadge")
            } else {print("refresh non effettuato")}
            
        } else if drinksList_segmentControl.selectedSegmentIndex == 1{
            print("segment control clicked pari a 1")
            if shouldUpdateDrinksTable(SegmentControlBadge: self.productSendBadge.object(forKey: "productOfferedBadge") as? Int, timeReaded: self.lastOrderReceivedReadedTimestamp.object(forKey: "lastOrderReceivedReadedTimestamp") as? Date){
                self.readOrderReceived()
                print("refresh effettuato")
                self.productSendBadge.set(0, forKey: "productOfferedBadge")
            } else {print("refresh non effettuato")}
        }
        refreshControl.endRefreshing()
        
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
        
        let dateObj = dateFormatter.date(from: dateString)
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.string(from: dateObj!)
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
            
            FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "id FB", idFB: (self.forwardOrder?.userDestination?.idFB)!, onCompletion: { (error,idApp) in
                guard error == nil else {
                    print(error!)
                    return
                }
                self.forwardOrder?.userDestination?.idApp = idApp!
                FireBaseAPI.updateNode(node: "orderOffered/" + (self.user?.idApp)! + "/" + (self.forwardOrder?.idOfferta)!, value: ["IdAppUserDestination" : (self.forwardOrder?.userDestination?.idApp)!, "facebookUserDestination":(self.forwardOrder?.userDestination?.idFB)!,"offerState":"Pending"])
                FirebaseData.sharedIstance.moveFirebaseRecord(userApp: self.user!,user: self.oldFriendDestination!, order: self.forwardOrder!, onCompletion: { (error) in
                    guard error == nil else {
                        self.generateAlert(title: "Errore", msg: error!, indexPath: nil)
                        return
                    }
                    self.showSuccess()
                    FirebaseData.sharedIstance.updateNumberPendingProductsOnFireBase((self.oldFriendDestination?.idApp)!, recOrPurch: "received")
                })
            })
            
            break
        default:
            break
        }
    }
    
    
    
    
    
    
    
    
    
    
    
}
