//
//  OrdineDrinksViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 03/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import FBSDKCoreKit
import FBSDKLoginKit
import UIKit
import FirebaseDatabase
import FirebaseAuth
import FirebaseMessaging
import FirebaseInstanceID

// Destination Order and products Order controller
class DrinksOrderViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var quantità_label: UILabel!
    @IBOutlet weak var totale_label: UILabel!
    @IBOutlet weak var delete: UIBarButtonItem!
    @IBOutlet weak var carousel: UIBarButtonItem!
    
    enum Alert: String {
        case lostConnection_title = "Attenzione connessione Internet assente"
        case lostConnection_msg = "Accertati che la tua connessione WiFi o cellulare sia attiva"
        case deleteSelection_title = "Attenzione!"
        case deleteSelection_msg = "Stai per eliminimare le selezioni effettuate. Continuare?"
        case friendNotSelect_title = "Attenzione!!"
        case friendNotSelect_msg = "Devi selezionare un amico prima di proseguire"
        case productsNotSelected_title = "Attenzione!!!"
        case productsNotSelected_msg = "Devi selezionare almeno un prodotto prima di proseguire"
    }
    
    var sectionTitle = ["A chi?", "Dove?", "Cosa?"]
    
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    var user: User?
    var uid: String?
    
    //UserDefault variables
    var fireBaseToken = UserDefaults.standard
    let fbToken = UserDefaults.standard
    var productOfferedBadge = UserDefaults.standard
    let defaults = UserDefaults.standard
    var firebaseObserverKilled = UserDefaults.standard
    
    var fbTokenString: String?
    var controller :UIAlertController?
    
    //company products
    var elencoProdotti: [String] = []
    var dictionaryOfferte = [String:Double]()
    var offerteCaricate = false
    var isConnectedtoNetwork = true
    
    //companies list
    var companies: [Company]?
    
    let queue = DispatchQueue.init(label: "it.morganamusic.queue", qos: .background)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        //navigationController?.navigationBar.shadowImage = UIImage()
        guard CheckConnection.isConnectedToNetwork() == true else{
            self.isConnectedtoNetwork = false
            self.quantità_label.text = "   Quantità prodotti: " + "\(Order.sharedIstance.prodottiTotali)"
            self.totale_label.text = "  Totale: € " + String(format:"%.2f", Order.sharedIstance.costoTotale)
            self.generateAlert(title: Alert.lostConnection_title.rawValue, msg: Alert.lostConnection_msg.rawValue)
            return
        }
        self.isConnectedtoNetwork = true
        DispatchQueue.main.async {
            self.loadOfferte()
        }
        self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        
        self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
        guard user != nil else{
            print("User non esiste")
            return
        }
        UpdateBadgeInfo.sharedIstance.updateBadgeInformations(nsArray: self.tabBarController?.tabBar.items as NSArray!)
        self.getFriendsList()
        self.quantità_label.text = "   Quantità prodotti: 0"
        self.totale_label.text = "   Totale: € 0,00"
        self.myTable.dataSource = self
        self.myTable.delegate = self
        let token = Messaging.messaging().fcmToken
        print("FCM token: \(token ?? "")")
        self.readCompanies()
        self.firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
        
        
        //reset Firebase DB. only for simulator tests
        FireBaseAPI.resetFirebaseDB()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if  isConnectedtoNetwork == false {
            self.viewDidLoad()
        }
        self.isConnectedtoNetwork = true
        self.myTable.reloadData()
        UIApplication.shared.statusBarStyle = UIStatusBarStyle.lightContent
        //Update badge info
        //UpdateBadgeInfo.sharedIstance.updateBadgeInformations(nsArray: self.tabBarController?.tabBar.items as NSArray!)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionTitle.count
    }
    
    private func readCompanies(){
        FirebaseData.sharedIstance.readCompaniesOnFireBase { (companies) in
            self.companies = companies
            //self.myTable.reloadData()
            Cart.sharedIstance.company = self.companies?[0]
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            if let localCompanies = companies {
                return localCompanies.count
            }else {return 1}
        case 2:
            if (Order.sharedIstance.prodotti?.isEmpty)! {
                let product = Product(productName: "+    Aggiungi prodotto", price: 0, quantity: 0)
                Order.sharedIstance.prodotti?.append(product)
            }
            return (Order.sharedIstance.prodotti?.count)!
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            return 78.0
        } else if sectionTitle[indexPath.section] == sectionTitle[1]{
            return 58.0
        }else {
            return 40.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        
        if (sectionTitle[indexPath.section] == sectionTitle[0]) {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath)
            if (Order.sharedIstance.userDestination?.idFB != nil) {
                let userTemp = Order.sharedIstance.userDestination
                let url = NSURL(string: (userTemp?.pictureUrl)!)
                let data = NSData(contentsOf: url! as URL)
                
                (cell as! FirendsListTableViewCell).friendImageView.image = UIImage(data: data! as Data)
                (cell as! FirendsListTableViewCell).friendName.text = userTemp?.fullName
            } else {
                let url = NSURL(string: (user?.pictureUrl)!)
                let data = NSData(contentsOf: url! as URL)
                
                (cell as! FirendsListTableViewCell).friendImageView.image = UIImage(data: data! as Data)
                (cell as! FirendsListTableViewCell).friendName.text = user?.fullName
                cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            }
            
        } else if (sectionTitle[indexPath.section] == sectionTitle[1]){
            cell = tableView.dequeueReusableCell(withIdentifier: "cellOffer", for: indexPath)
            /*
            if let company = companies?[indexPath.row] {
                cell?.textLabel?.text = company.companyName
            } else {
                cell?.textLabel?.text = "Azienda non selezionata"
            }*/
            cell?.textLabel?.text = "Morgana Music Club"
            
            
            cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellOffer", for: indexPath)
            
            let elemento = Order.sharedIstance.prodotti?[indexPath.row]
            if indexPath.row < (Order.sharedIstance.prodotti?.count)!  {
                if elemento?.quantity != 0 {
                    cell?.textLabel?.text = "(\(elemento!.quantity!))  " + (elemento?.productName)! + " € " + String(format:"%.2f", elemento!.price!)
                    
                    self.quantità_label.text = "   Quantità prodotti: " + "\(Order.sharedIstance.prodottiTotali)"
                    self.totale_label.text = "   Totale: € " + String(format:"%.2f", Order.sharedIstance.costoTotale)
                }else {
                    cell?.textLabel?.text = elemento?.productName
                }
                cell?.accessoryType = UITableViewCellAccessoryType.none
                cell?.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
                cell?.textLabel?.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
                if indexPath.row == ((Order.sharedIstance.prodotti?.count)! - 1){
                    cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
                    cell?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                    cell?.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
                    cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
                }
            }
        }
        return cell!
    }
    
    private func getFriendsList(){
        guard CheckConnection.isConnectedToNetwork() == true else {
            self.generateAlert(title: Alert.lostConnection_title.rawValue, msg: Alert.lostConnection_msg.rawValue)
            return
        }
        
        //if friends list is 0, load user Facebook friends
        guard self.user?.friends?.count != 0 else {
            self.getFriends(mail: (self.user?.email)!)
            let date = Date()
            self.defaults.set(date, forKey: "Data")
            return
        }
        
        //if request is > 18000 seconds refresh list friends  with getFriends func
        guard self.refreshUpdateFriendList() else {
            return
        }
        self.getFriends(mail: (self.user?.email)!)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        if (thisCell is FirendsListTableViewCell){
            guard self.user != nil else {
                print("utente non presente")
                return
            }
            self.getFriendsList()
            self.performSegue(withIdentifier: "segueToAmiciFromOffer", sender: nil)
            
        }else {
            if (thisCell?.textLabel?.text == "+    Aggiungi prodotto") {
                if !self.offerteCaricate {
                    thisCell?.selectionStyle = UITableViewCellSelectionStyle.none
                    self.myTable.reloadData()
                } else {
                    self.performSegue(withIdentifier: "segueToOfferta", sender: nil)
                }
            }
        }
        tableView.deselectRow(at: indexPath, animated: false)
        
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (sectionTitle[indexPath.section] == sectionTitle[1]) {
            if indexPath.row < (Order.sharedIstance.prodotti?.count)! - 1{
                return true
            }
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        switch editingStyle {
        case .delete:
            print("premuto il tasto Delete")
            
            let elemento = Order.sharedIstance.prodotti?[indexPath.row]
            print("elimo l'elemento \((elemento?.productName)!)")
            
            Order.sharedIstance.prodotti?.remove(at: indexPath.row)
            
            self.quantità_label.text = "   Quantità prodotti: " + "\(Order.sharedIstance.prodottiTotali)"
            self.totale_label.text = "   Totale: € " + String(format:"%.2f", Order.sharedIstance.costoTotale)
            
            tableView.deleteRows(at: [indexPath], with: .left)
            break
        default:
            break
        }
    }
    
    private func loadOfferte(){
        guard self.elencoProdotti.isEmpty else {
            return
        }
        FireBaseAPI.readNodeOnFirebase(node: "merchant products", onCompletion: { (error, dictionary) in
            guard error == nil else {
                self.generateAlert(title: "Connessione assente", msg: "Controlla che i segnale internet sia presente ")
                return
            }
            guard dictionary != nil else {
                return
            }
            for (prodotto, costo) in dictionary! {
                if prodotto != "autoId" {
                    let prodottoConCosto = prodotto
                    self.elencoProdotti.append(prodottoConCosto)
                    self.dictionaryOfferte[prodotto] = costo as? Double
                }
            }
            self.offerteCaricate = true
            print("offerte caricate")
        })
    }
    
    private func generateAlert(title: String, msg: String){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Chiudi", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            print("Il messaggio di chiusura è stato premuto")
        })
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
        
    }
    
    private func generateAlert2(title: String, msg: String){
        controller = UIAlertController(title: title,
                                       message: msg,
                                       preferredStyle: .alert)
        let actionProsegui = UIAlertAction(title: "Elimina", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            self.deleteOrdine()
            
        })
        let actionAnnulla = UIAlertAction(title: "Annulla", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            print("Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(actionAnnulla)
        controller!.addAction(actionProsegui)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    private func deleteOrdine(){
        Order.sharedIstance.userDestination?.idFB = nil
        Order.sharedIstance.prodotti?.removeAll()
        self.quantità_label.text = "   Quantità prodotti: 0"
        self.totale_label.text = "   Totale: € 0,00"
        self.delete.isEnabled = false
        self.myTable.reloadData()
    }
    
    func startActivityIndicator(_ title: String) {
        
        strLabel.removeFromSuperview()
        activityIndicator.removeFromSuperview()
        effectView.removeFromSuperview()
        
        strLabel = UILabel(frame: CGRect(x: 50, y: 0, width: 200, height: 46))
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
    
    func getFriends(mail: String){
        print("Update Friends List")
        
        if user?.friends!.count != nil {
            CoreDataController.sharedIstance.deleteFriends(self.uid!)
        }
        let fbToken = UserDefaults.standard
        fbTokenString = fbToken.object(forKey: "FBToken") as? String
        
        
        let parameters_friend = ["fields" : "name, first_name, last_name, id, email, gender, picture.type(large)"]
        
        FBSDKGraphRequest(graphPath: "me/friends", parameters: parameters_friend, tokenString: fbTokenString, version: nil, httpMethod: "GET").start(completionHandler: {(connection,result, error) -> Void in
            if ((error) != nil)
            {
                // Process error
                print("Error: \(error!)")
                return
            }
            //numbers of total friends
            let newResult = result as! NSDictionary
            let summary = newResult["summary"] as! NSDictionary
            let counts = summary["total_count"] as! NSNumber
            
            print("Totale amici letti:  \(counts)")
            var contFriends = 0
            
            //self.startActivityIndicator("Carico lista amici...")
            let dati: NSArray = newResult.object(forKey: "data") as! NSArray
            
            guard dati.count != 0 else {
                return
            }
            
            for i in 0...(dati.count - 1) {
                contFriends += 1
                let valueDict: NSDictionary = dati[i] as! NSDictionary
                let name = valueDict["name"] as? String
                let idFB = valueDict["id"] as! String
                let firstName = valueDict["first_name"] as! String
                let lastName = valueDict["last_name"] as! String
                print(idFB)
                
                //let gender = valueDict["gender"] as! String
                let picture = valueDict["picture"] as! NSDictionary
                let data = picture["data"] as? NSDictionary
                let url = data?["url"] as? String
                
                CoreDataController.sharedIstance.addFriendInUser(idAppUser: self.uid!, idFB: idFB, mail: mail, fullName: name, firstName: firstName, lastName: lastName, gender: nil, pictureUrl: url)
            }
            print("Aggiornamento elnco amici di Facebook completato!. Inseriti \(contFriends) amici")
            //self.stopActivityIndicator()
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToAmiciFromOffer":
            (segue.destination as! FriendsListViewController).segueFrom = "offerView"
            break
        case "segueToOfferta":
            (segue.destination as! FriendActionViewController).productsList = self.elencoProdotti
            (segue.destination as! FriendActionViewController).offersDctionary = self.dictionaryOfferte
            (segue.destination as! FriendActionViewController).userId = self.uid
            
            if (Order.sharedIstance.userDestination?.idFB != nil) {
                let userTemp = Order.sharedIstance.userDestination
                let url = NSURL(string: (userTemp?.pictureUrl)!)
                let data = NSData(contentsOf: url! as URL)
                
                (segue.destination as! FriendActionViewController).imageFriend = UIImage(data: data! as Data)
                (segue.destination as! FriendActionViewController).fullNameFriend = userTemp?.fullName!
            } else {
                let url = NSURL(string: (user?.pictureUrl)!)
                let data = NSData(contentsOf: url! as URL)
                
                (segue.destination as! FriendActionViewController).imageFriend = UIImage(data: data! as Data)
                (segue.destination as! FriendActionViewController).fullNameFriend = self.user?.fullName
            }
            break
        default:
            break
        }
        
    }
    
    func refreshUpdateFriendList() -> Bool{
        //create first request Date
        guard  defaults.object(forKey: "Data") != nil else {
            let date = Date()
            self.defaults.set(date, forKey: "Data")
            print("data prima richiesta: ",defaults.object(forKey: "Data")!)
            return true
        }
        
        //current Date
        let currentDate = Date()
        
        
        // difference in seconds from TimeIntervalNow and one date
        let diffTime = (defaults.object(forKey: "Data") as! Date).timeIntervalSinceNow * -1
        print(diffTime)
        
        //if the request is > 1/2 gg (18000 sec) refresh FB Friends List
        //for test: don't insert a value < 5
        if diffTime > 18000 {
            self.defaults.set(currentDate, forKey: "Data")
            return true
        }
        return false
    }
    
    @IBAction func unwindToOffer(_ sender: UIStoryboardSegue) {
        switch sender.identifier! {
        case "unwindToOffer":
            //Hide Delet BarButtonItem if cart is empty
            if (Order.sharedIstance.prodotti?.count)! > 1 {
                self.delete.isEnabled = true
            }
            
            //Disable Cart BarButtonItem if cart is Empty and remove badge number
            if Cart.sharedIstance.carrello.count == 0 {
                self.carousel.isEnabled = false
                self.carousel.removeBadge()
            }else {
                self.carousel.addBadge(number: Cart.sharedIstance.carrello.count)
            }

            break
        case "unwindToOfferfromListFriendWithoutValue":
            print("senza valori e reload table")
            break
        case "unwindToOfferFromCartWithoutData":
            print("senza dati")
            break
        default:
            self.myTable.reloadData()
            break
        }
        //Hide Delet BarButtonItem if cart is empty
        if (Order.sharedIstance.prodotti?.count)! > 1 {
            self.delete.isEnabled = true
        }
        
        //Disable Cart BarButtonItem if cart is Empty and remove badge number
        if Cart.sharedIstance.carrello.count == 0 {
            self.carousel.isEnabled = false
            self.carousel.removeBadge()
        }else {
            self.carousel.addBadge(number: Cart.sharedIstance.carrello.count)
        }

    }
    
    @IBAction func addToCaourosel(_ sender: UIButton) {
        guard (Order.sharedIstance.prodotti?.count)! > 1 else {
            self.generateAlert(title: Alert.productsNotSelected_title.rawValue, msg: Alert.productsNotSelected_msg.rawValue)
            return
        }
        
        let userDestination = UserDestination(nil,nil,nil,nil,nil)
        if Order.sharedIstance.userDestination?.idFB != nil {
            userDestination.fullName =  Order.sharedIstance.userDestination?.fullName
            userDestination.idFB = Order.sharedIstance.userDestination?.idFB
            userDestination.pictureUrl = Order.sharedIstance.userDestination?.pictureUrl
        }else {
            userDestination.fullName =  self.user?.fullName
            userDestination.idFB = self.user?.idFB
            userDestination.pictureUrl = self.user?.pictureUrl
            userDestination.idApp = self.user?.idApp
        }
        
        let order = Order(prodotti: Order.sharedIstance.prodotti!, userDestination: userDestination, userSender: UserDestination(nil,self.user?.idApp,nil,nil,nil))
        
        var insertOk = false
        
        //add new Order into Cart
        //Se l'Ordine è indirizzata ad un utente già presente nel carrello unisce i prodotti sotto lo stesso utente destinatario
        for cartOrder in Cart.sharedIstance.carrello {
            if cartOrder.userDestination?.idFB == order.userDestination?.idFB {
                cartOrder.prodotti?.removeLast()
                //Se il prodotto è lo stesso cambia solo la quantità
                for productInOrder in cartOrder.prodotti! {
                    var numberProducts = 0
                    for product in order.prodotti! {
                        if productInOrder.productName == product.productName {
                            productInOrder.quantity = productInOrder.quantity! +  product.quantity!
                            order.prodotti?.remove(at: numberProducts)
                        }
                        numberProducts += 1
                    }
                    
                }
                cartOrder.prodotti = cartOrder.prodotti! + order.prodotti!
                insertOk = true
            }
        }
        if !insertOk {
            Cart.sharedIstance.carrello.append(order)
        }
        
        self.carousel.isEnabled = true
        self.carousel.addBadge(number: Cart.sharedIstance.carrello.count)
        self.deleteOrdine()
        
    }
    
    @IBAction func carousel_clicked(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "segueToCarousel", sender: nil)
    }
    @IBAction func deleteSelections(_ sender: UIBarButtonItem) {
        self.generateAlert2(title: Alert.deleteSelection_title.rawValue, msg: Alert.deleteSelection_msg.rawValue)
    }
    
    
}
