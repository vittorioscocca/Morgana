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
class OrderViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var quantità_label: UILabel!
    @IBOutlet weak var totale_label: UILabel!
    @IBOutlet weak var delete: UIBarButtonItem!
    @IBOutlet weak var carousel: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    @IBOutlet weak var addToCart: UIButton!
    
    
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
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
        self.isConnectedtoNetwork = true
        self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
        if user == nil {
            self.logout()
        } else {self.viewSettings()}
        
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(networkStatusDidChange),
                                            name: .NetworkStatusDidChange,
                                            object: nil)
        
        addToCart.layer.masksToBounds = true
        addToCart.layer.cornerRadius = 10
        
        //reset Firebase DB. only for simulator tests
        //FireBaseAPI.resetFirebaseDB()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if  isConnectedtoNetwork == false {
            self.viewDidLoad()
        }
        self.isConnectedtoNetwork = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateTable),
                                               name: .CacheImageLoadImage,
                                               object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func networkStatusDidChange() {
        if CheckConnection.isConnectedToNetwork() == true {
            updateTable()
        }
    }
    
    private func viewSettings(){
        UpdateBadgeInfo.sharedIstance.updateBadgeInformations(nsArray: self.tabBarController?.tabBar.items as NSArray?)
        self.quantità_label.text = "   Quantità prodotti: 0"
        self.totale_label.text = "   Totale: € 0,00"
        self.myTable.dataSource = self
        self.myTable.delegate = self
        self.readCompanies()
        self.firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
    }
    @objc func updateTable(){
        print("table reloaded")
        myTable.reloadData()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    
    private func killFirebaseObserver (){
        let firebaseObserverKilled = UserDefaults.standard
        if !firebaseObserverKilled.bool(forKey: "firebaseObserverKilled") {
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            let fireBaseToken = UserDefaults.standard
            let uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
            let user = CoreDataController.sharedIstance.findUserForIdApp(uid)
            guard let userIdApp = user?.idApp else { return }
            FireBaseAPI.removeObserver(node: "users/" + userIdApp)
            FireBaseAPI.removeObserver(node: "ordersSent/" + userIdApp)
            FireBaseAPI.removeObserver(node: "ordersReceived/" + userIdApp)
            firebaseObserverKilled.set(true, forKey: "firebaseObserverKilled")
            print("Firebase Observer Killed")
            
        } else {print("no observer killed")}
    }
    
    private func logout(){
        guard CheckConnection.isConnectedToNetwork() == true else {
            return
        }
        //effettuo logout FB
        let loginManager = FBSDKLoginManager()
        loginManager.logOut()
        //self.fbToken.set(nil, forKey: "FBToken")
        self.fbToken.set(nil, forKey: "FBToken")
        
        //effettuologout da firebase
        let firebaseAuth = Auth.auth()
        do {
            self.killFirebaseObserver()
            try firebaseAuth.signOut()
            self.fireBaseToken.removeObject(forKey: "FireBaseToken")
            
            print("utente disconnesso di firebase")
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        //passo il controllo alla view di login, LoginViewController
        let loginPage = storyboard?.instantiateViewController(withIdentifier: "LoginViewController")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window!.rootViewController = loginPage
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionTitle.count
    }
    
    private func readCompanies(){
        FirebaseData.sharedIstance.readCompaniesOnFireBase { (companies) in
            DispatchQueue.main.async(execute: {
                self.companies = companies
                //self.myTable.reloadData()
                Cart.sharedIstance.company = self.companies?[0]
            })
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
            var url: String?
            
            if (Order.sharedIstance.userDestination?.idFB != nil) {
                url = Order.sharedIstance.userDestination?.pictureUrl
                (cell as! FirendsListTableViewCell).friendName.text = Order.sharedIstance.userDestination?.fullName
            } else {
                url = self.user?.pictureUrl
                (cell as! FirendsListTableViewCell).friendName.text = user?.fullName
                cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            }
            
            CacheImage.getImage(url: url, onCompletion: { (image) in
                guard image != nil else {
                    print("immagine utente non reperibile")
                    return
                }
                DispatchQueue.main.async(execute: {
                    if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                        (cellToUpdate as! FirendsListTableViewCell).friendImageView.image = image
                    }
                })
            })
            
        } else if (sectionTitle[indexPath.section] == sectionTitle[1]){
            cell = tableView.dequeueReusableCell(withIdentifier: "cellOffer", for: indexPath)
            cell?.textLabel?.text = "Morgana Music Club"
            cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
            cell?.isUserInteractionEnabled = false
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellOffer", for: indexPath)
            
            guard let products = Order.sharedIstance.prodotti else  { return cell! }
            let elemento = products[indexPath.row]
            guard let quantity = elemento.quantity, let productName = elemento.productName, let price = elemento.price else { return cell!}
            if indexPath.row < products.count  {
                if quantity != 0 {
                    cell?.textLabel?.text = "(\(quantity))  " + productName + " € " + String(format:"%.2f", price)
                    
                    self.quantità_label.text = "   Quantità prodotti: " + "\(Order.sharedIstance.prodottiTotali)"
                    self.totale_label.text = "   Totale: € " + String(format:"%.2f", Order.sharedIstance.costoTotale)
                }else {
                    cell?.textLabel?.text = elemento.productName
                }
                cell?.accessoryType = UITableViewCellAccessoryType.none
                cell?.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
                cell?.textLabel?.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
                if indexPath.row == (products.count - 1){
                    cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
                    cell?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                    cell?.textLabel?.textColor = #colorLiteral(red: 0.7419371009, green: 0.1511851847, blue: 0.20955199, alpha: 1)
                    cell?.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.light)
                }
            }
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        if (thisCell is FirendsListTableViewCell){
            guard self.user != nil else {
                print("utente non presente")
                return
            }
            //self.getFriendsList()
            self.performSegue(withIdentifier: "segueToAmiciFromOffer", sender: nil)
            
        }else {
            if (thisCell?.textLabel?.text == "+    Aggiungi prodotto") {
                self.performSegue(withIdentifier: "segueToOfferta", sender: nil)
            } 
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (sectionTitle[indexPath.section] == sectionTitle[2]) {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToAmiciFromOffer":
            (segue.destination as! FriendsListViewController).segueFrom = "offerView"
            (segue.destination as! FriendsListViewController).user = self.user
            break
        case "segueToOfferta":
            (segue.destination as! FriendActionViewController).userId = self.uid
            
            if (Order.sharedIstance.userDestination?.idFB != nil) {
                let userTemp = Order.sharedIstance.userDestination
                
                (segue.destination as! FriendActionViewController).friendURLImage = userTemp?.pictureUrl
                (segue.destination as! FriendActionViewController).fullNameFriend = userTemp?.fullName!
            } else {
                
                (segue.destination as? FriendActionViewController)?.friendURLImage = user?.pictureUrl
                (segue.destination as? FriendActionViewController)?.fullNameFriend = self.user?.fullName
            }
            break
        default:
            break
        }
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
            } else {
                self.carousel.addBadge(number: Cart.sharedIstance.carrello.count)
            }

            break
        case "unwindToOfferfromListFriendWithoutValue":
            print("senza valori senza reload table")
            break
        case "unwindToOfferfromListFriend":
            print("con nuovi valori valori e reload table")
            self.delete.isEnabled = true
            self.myTable.reloadData()
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
    
    @IBAction func addOrderToCart(_ sender: UIButton) {
        guard let orderProducts = Order.sharedIstance.prodotti else {
            return
        }
        guard orderProducts.count > 1 else {
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
        
        let order = Order(prodotti: orderProducts, userDestination: userDestination, userSender: UserDestination(nil,self.user?.idApp,nil,nil,nil))
        
        order.company = self.companies?[0]  //insert Morgana Company Order
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
