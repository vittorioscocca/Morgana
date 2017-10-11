//
//  AuthOrderViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 05/10/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import FirebaseDatabase


class AuthOrderViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var userImageView: UIImageView!
    @IBOutlet var userFullName_label: UILabel!
    @IBOutlet var expirationOrderDate_label: UILabel!
    @IBOutlet var orderState_label: UILabel!
    @IBOutlet var myTable: UITableView!
    @IBOutlet var authButton: UIButton!
    
    var userDestinationID: String?
    var orderId: String?
    var expirationDate: String?
    var sectionTitle = ["Locale","Prodotti"]
    var comapanyId: String?
    var orderReaded: Order?
    var imageCache = [String:UIImage]()
    var myIndexPath = [IndexPath]()
    var productQuantity = [Int]()
    var alert = UIAlertController()
    var orderScanned = false
    var actualDate: Date?
    var actualDateString: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.myTable.dataSource = self
        self.myTable.delegate = self
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        self.orderReaded = Order(prodotti: [], userDestination: UserDestination(nil,nil,nil,nil,nil), userSender: UserDestination(nil,nil,nil,nil,nil))
        
        guard userDestinationID != nil, orderId != nil else {
            
            self.alert = UIAlertController(title: "Errore lettura Ordine", message: "assicurati che il codice sia valido", preferredStyle: .alert)
            present(self.alert, animated: true, completion: nil)
            return
        }
        let ref = Database.database().reference()
        ref.child("sessions").setValue(ServerValue.timestamp())
        ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
            self.actualDate = self.timeIntervalToDate(timeInterval: snap.value! as! TimeInterval)
        })
        setCustomImage()
        self.readAndValidateOrder()
    }
    
    private func readAndValidateOrder() {
        
        FirebaseData.sharedIstance.readSingleOrder(userId: userDestinationID!, companyId: comapanyId!, orderId: orderId!, onCompletion: { (order) in
            guard !order.isEmpty else {
                print("errore di lettura su Ordine")
                return
            }
            
            var newProduct = [Product]()
            for product in order[0].prodotti! {
                if product.productName?.range(of:"_climbed") != nil && product.quantity != 0 {
                    product.productName = product.productName?.replacingOccurrences(of: "_climbed", with: "", options: .regularExpression)
                    newProduct.append(product)
                }
            }
            if newProduct.count != 0 {
                order[0].prodotti = newProduct
            }
            self.orderReaded = order[0]
            self.readUserDetails()
            self.validateOrder()
            self.myTable.reloadData()
            
        })
    }
    
    private func readUserDetails(){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + (self.userDestinationID!), onCompletion: { (error,dictionary) in
            guard error == nil else {
                print("Errore di connessione")
                return
            }
            guard dictionary != nil else {
                print("Errore di lettura del dell'Ordine richiesto")
                return
            }
            self.orderReaded?.userDestination?.idApp = self.userDestinationID!
            self.orderReaded?.userDestination?.fullName = dictionary!["fullName"] as? String
            self.orderReaded?.userDestination?.pictureUrl = dictionary!["pictureUrl"] as? String
            self.userFullName_label.text = dictionary!["fullName"] as? String
            
            self.readImage()
            
        })
    }
  
    
    private func readImage (){
        if let pictureUrl = self.orderReaded?.userDestination?.pictureUrl{
            if let img = imageCache[pictureUrl] {
                self.userImageView.image = img
            }
            else {
                let request = NSMutableURLRequest(url: NSURL(string: (self.orderReaded?.userDestination?.pictureUrl)!)! as URL)
                let session = URLSession.shared
                let task = session.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
                    if error == nil {
                        // Convert the downloaded data in to a UIImage object
                        let image = UIImage(data: data!)
                        // Store the image in to our cache
                        self.imageCache[(self.orderReaded?.userDestination?.pictureUrl)!] = image
                        // Update the cell
                        DispatchQueue.main.async(execute: {
                            self.userImageView.image = image
                        })
                    }
                    else {
                        print("Error: \(error!.localizedDescription)")
                    }
                })
                task.resume()
            }
        }else {
            print("Attenzione URL immagine Mittente non presente")
        }
    }
    
    private func timeIntervalToDate(timeInterval: TimeInterval)->Date{
        
        let date = NSDate(timeIntervalSince1970: timeInterval/1000)
        
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let dateString = dateFormatter.string(from: date as Date)
        self.actualDateString = dateString
        return dateFormatter.date(from: dateString)!
    }
    
    private func validateOrder(){
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        dateFormatter.locale = Locale.init(identifier: "it_IT")
        
        let dateObj = dateFormatter.date(from: self.expirationDate!)
        if dateObj! < self.actualDate! {
            self.orderState_label.text = "ORDINE SCADUTO"
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            self.alert = UIAlertController(title: "Ordine scaduto!", message: "Ordine scaduto il " + dateFormatter.string(from: dateObj!), preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            self.alert.addAction(defaultAction)
            self.present(self.alert, animated: true, completion: nil)
        } else if (self.orderReaded?.offerState == "Offerta accettata" || self.orderReaded?.offerState == "Offerta scalata") && self.orderReaded?.paymentState == "Valid" {
            self.myTable.isHidden = false
            self.authButton.isHidden = false
            self.orderState_label.text = "ORDINE VALIDO"
        } else if self.orderReaded?.offerState != "Offerta accettata" && self.orderReaded?.offerState != "Offerta scalata"  {
            self.orderState_label.text = "ORDINE NON VALIDO"
            self.alert = UIAlertController(title: "Ordine non valido!", message: "Stato ordine non compatibile", preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            self.alert.addAction(defaultAction)
            self.present(self.alert, animated: true, completion: nil)
        } else if self.orderReaded?.paymentState != "Valid" {
            self.orderState_label.text = "ORDINE NON VALIDO"
            
            self.alert = UIAlertController(title: "Ordine non valido!", message: "Problemi con lo stato di pagamento", preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            self.alert.addAction(defaultAction)
            self.present(self.alert, animated: true, completion: nil)
        }
        dateFormatter.dateFormat = "dd/MM/yyyy"
        self.expirationOrderDate_label.text = "Scade: " + dateFormatter.string(from: dateObj!)
        
    }
    
    
    private func setCustomImage(){
        self.userImageView.layer.borderWidth = 2.5
        self.userImageView.layer.borderColor = #colorLiteral(red: 0.9951923077, green: 0.9903846154, blue: 1, alpha: 1)
        self.userImageView.layer.masksToBounds = false
        self.userImageView.layer.cornerRadius = userImageView.frame.height/2
        self.userImageView.clipsToBounds = true
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.sectionTitle.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else {
            return (self.orderReaded?.prodotti?.count)!
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            cell = tableView.dequeueReusableCell(withIdentifier: "companyCell", for: indexPath)
            cell?.textLabel?.text = "Morgana Music Club"
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
            let product = self.orderReaded?.prodotti![indexPath.row]
            
            if !self.orderScanned {
                (cell as! AutOrderTableViewCell).productName_label.text = product?.productName
                (cell as! AutOrderTableViewCell).productQuantity_label.text = String((product?.quantity)!)
                self.myIndexPath.append(indexPath)
                self.productQuantity.append((product?.quantity)!)
                (cell as! AutOrderTableViewCell).myStepper.tag = indexPath.row
                (cell as! AutOrderTableViewCell).myStepper.value = Double((product?.quantity)!)
                (cell as! AutOrderTableViewCell).myStepper.maximumValue = Double((product?.quantity)!)
                (cell as! AutOrderTableViewCell).myStepper.minimumValue = 0
                (cell as! AutOrderTableViewCell).myStepper.addTarget(self, action: #selector(stepperAction(_:)), for: .touchUpInside)
            }else {
                (cell as! AutOrderTableViewCell).myStepper.isHidden = true
            }
        }
        return cell!
    }
    
    
    @objc func stepperAction( _ sender: UIStepper!) {
        let cell = self.myTable.cellForRow(at: myIndexPath[sender.tag])
        
        (cell as! AutOrderTableViewCell).productQuantity_label.text = String(Int(sender.value))
        self.orderReaded?.prodotti![sender.tag].quantity = Int((cell as! AutOrderTableViewCell).myStepper.maximumValue) - Int(sender.value)
        
    }
    
    private func prepareProductsOfferDetailsDictionary()->[String:String]{
        var newProductsOfferDictionary: [String:String] = [:]
        var count = 0
        for product in (self.orderReaded?.prodotti)! {
            if product.quantity == self.productQuantity[count] {
                newProductsOfferDictionary[product.productName!+"_climbed"] = "0x" + String(format:"%.2f", (product.price)!)
            }else {
                newProductsOfferDictionary[product.productName!+"_climbed"] = String((product.quantity)!) + "x" + String(format:"%.2f", (product.price)!)
            }
            count += 1
        }
        return newProductsOfferDictionary
    }
    
    private func numberOfProducts()->Int{
        var totQuantity = 0
        
        for product in (self.orderReaded?.prodotti)!{
            totQuantity += product.quantity!
        }
        return totQuantity
    }
    
    
    
    private func updateNewProductsOfferDetails(){
        
        if productQuantity.reduce(0, +) != numberOfProducts() {
            //update new quantity
            var newProductsOfferDictionary: [String:String] = [:]
            newProductsOfferDictionary = prepareProductsOfferDetailsDictionary()
            FireBaseAPI.updateNode(node: "productsOffersDetails/\((self.orderReaded?.company?.companyId)!)/\((self.orderReaded?.idOfferta)!)", value: newProductsOfferDictionary)
            
            //orderState Offerta scalata
            FireBaseAPI.updateNode(node: "ordersReceived/\((self.orderReaded?.userDestination?.idApp)!)/\((self.orderReaded?.company?.companyId)!)/\((self.orderReaded?.orderAutoId)!)", value: ["offerState":"Offerta scalata", "total" : String(format:"%.2f", (self.orderReaded?.costoTotale)!),"consumingDate":self.actualDateString!])
            FireBaseAPI.updateNode(node: "ordersSent/\((self.orderReaded?.userSender?.idApp)!)/\((self.orderReaded?.company?.companyId)!)/\((self.orderReaded?.idOfferta)!)", value: ["offerState":"Offerta scalata", "total" : String(format:"%.2f", (self.orderReaded?.costoTotale)!),"consumingDate":self.actualDateString!])
            self.sendNotifications()
            
        } else {
            //update orderState "Offerta consumata"
            FireBaseAPI.updateNode(node: "ordersReceived/\((self.orderReaded?.userDestination?.idApp)!)/\((self.orderReaded?.company?.companyId)!)/\((self.orderReaded?.orderAutoId)!)", value: ["offerState":"Offerta consumata","consumingDate":self.actualDateString!])
            FireBaseAPI.updateNode(node: "ordersSent/\((self.orderReaded?.userSender?.idApp)!)/\((self.orderReaded?.company?.companyId)!)/\((self.orderReaded?.idOfferta)!)", value: ["offerState":"Offerta consumata","consumingDate":self.actualDateString!])
           
            self.sendNotifications()
        }
        FireBaseAPI.updateNode(node: "ordersReceived/\((self.orderReaded?.userDestination?.idApp)!)/\((self.orderReaded?.company?.companyId)!)", value: ["scanningQrCode":true])
        
        self.alert = UIAlertController(title: "Operazione completata!", message: "Ordine autorizzato correttamente", preferredStyle: .alert)
        let confirm = UIAlertAction(title: "Ok", style: .default, handler: nil)
        self.alert.addAction(confirm)
        self.present(self.alert, animated: true, completion: nil)
    }
    
    
    private func sendNotificationToUserSender(){
        //Send notification
        var msg: String = ""
        
        msg = "Il tuo amico \((self.orderReaded?.userDestination?.fullName)!) ha appena consumato l'ordine da te inviato "
        NotificationsCenter.sendConsuptionNotification(userDestinationIdApp: (self.orderReaded?.userSender?.idApp)!, msg: msg, controlBadgeFrom: "purchased")
        print("Notifica al sender inviata")
    }
    
    private func sendNotificationToUserReceiver(){
        let msg = "Il tuo ordine è stato approvato "
        NotificationsCenter.sendConsuptionNotification(userDestinationIdApp: (self.orderReaded?.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
        print("notifica al receiver inviata")
    }
    
    private func sendNotifications(){
        //if order is accepted and if is not a autopurchased case, send notification to sender and receiver and add point else only send notification to receiver
        if orderReaded?.offerState == "Offerta accettata"{
            if orderReaded?.userDestination?.idApp != orderReaded?.userSender?.idApp {
                sendNotificationToUserSender()
                sendNotificationToUserReceiver()
            }
            self.updateUserPoints()
        }else {
            print("Sato offerta diversa da Accettata")
            sendNotificationToUserReceiver()
        }
    }
    
    private func updateUserPoints(){
        PointsManager.sharedInstance.readUserPointsStatsOnFirebase(userId: (self.orderReaded?.userDestination?.idApp)!,onCompletion: { (error) in
            guard error == nil else {
                print(error!)
                return
            }
            let points = PointsManager.sharedInstance.addPointsForConsumption(date: self.actualDate!, numberOfProducts: self.numberOfProducts())
            PointsManager.sharedInstance.updateNewValuesOnFirebase(actualUserId: (self.orderReaded?.userDestination?.idApp)!, onCompletion: {
                //send notification
                let msg = "Il tuo ordine è stato approvato, hai cumulato \(points) punti"
                NotificationsCenter.sendConsuptionNotification(userDestinationIdApp: (self.orderReaded?.userDestination?.idApp)!, msg: msg, controlBadgeFrom: "received")
                
            })
        })
    }
    

    @IBAction func authButton_clicked(_ sender: UIButton) {
        self.alert = UIAlertController(title: "Attenzione!", message: "Stai per autorizzare quest'ordine. Continuare?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Annulla", style: .default, handler: nil)
        let confirmAction = UIAlertAction(title: "Ok", style: .default, handler: {(paramAction:UIAlertAction!) in
            self.updateNewProductsOfferDetails()
            self.authButton.isHidden = true
            self.orderScanned = true
            self.myTable.reloadData()
         })
        self.alert.addAction(deleteAction)
        self.alert.addAction(confirmAction)
        self.present(self.alert, animated: true, completion: nil)
        
    }
    
}
