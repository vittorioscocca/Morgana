//
//  PaymentViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 17/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//
import UIKit
import FirebaseDatabase
import FirebaseAuth
import Firebase
import FirebaseMessaging
import FirebaseInstanceID
import UserNotifications

class PaymentViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PayPalPaymentDelegate {
    
    @IBOutlet var myTable: UITableView!
    
    var environment:String = Cart.sharedIstance.payPalEnvironment?.actualEnvironment ?? PayPalEnvironmentSandbox {
        willSet(newEnvironment) {
            if (newEnvironment != environment) {
                PayPalMobile.preconnect(withEnvironment: newEnvironment)
            }
        }
    }
    
    var payPalConfig = PayPalConfiguration() // default
    
    var paymentMethod: [String:String] = [
        "PayPal": "paypalButtom",
        "ApplePay" : "applePayButtom",
        "Crediti" : "credits"
    ]
    
    //App idUtente su FireBase
    var user: User?
    var productOfferedBadge = UserDefaults.standard
    
    var controller: UIAlertController?
    
    //Activity Indicator
    
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
        
        // Set up payPalConfig
        payPalConfig.acceptCreditCards = true
        payPalConfig.merchantName = "Morgana Music S.r.l.s."
        payPalConfig.merchantPrivacyPolicyURL = URL(string: "https://www.paypal.com/webapps/mpp/ua/privacy-full")
        payPalConfig.merchantUserAgreementURL = URL(string: "https://www.paypal.com/webapps/mpp/ua/useragreement-full")
        payPalConfig.languageOrLocale = Locale.preferredLanguages[0]
        payPalConfig.payPalShippingAddressOption = .payPal;
        
        
        print("PayPal iOS SDK Version: \(PayPalMobile.libraryVersion())")
        self.myTable.dataSource = self
        self.myTable.delegate = self
        self.completeCartInformation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        PayPalMobile.preconnect(withEnvironment: environment)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func generateAlert(title: String, message:String){
        controller = UIAlertController(title: title,
                                       message: message,
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    // PayPalPaymentDelegate
    
    func payPalPaymentDidCancel(_ paymentViewController: PayPalPaymentViewController) {
        print("PayPal Payment Cancelled")
        
        paymentViewController.dismiss(animated: true, completion: nil)
    }
    
    func payPalPaymentViewController(_ paymentViewController: PayPalPaymentViewController, didComplete completedPayment: PayPalPayment) {
        print("PayPal Payment Success !")
        paymentViewController.dismiss(animated: true, completion: { () -> Void in
            // send completed confirmaion to  server
            print("Here is your proof of payment:\n\n\(completedPayment.confirmation)\n\nSend this to your server for confirmation and fulfillment.")
            
            let dict = completedPayment.confirmation
            print("dict data is ====%@", dict)
            
            let paymentResultDic = completedPayment.confirmation as NSDictionary
            let dicResponse: AnyObject? = paymentResultDic.object(forKey: "response") as AnyObject?
            let dicResponse2: AnyObject? = paymentResultDic.object(forKey: "client") as AnyObject?
            //let dicResponse3: AnyObject? = paymentResultDic.object(forKey: "payer") as AnyObject?
            
            let paycreatetime:String = dicResponse!["create_time"] as! String
            let payauid:String = dicResponse!["id"] as! String
            let paystate:String = dicResponse!["state"] as! String
            let payintent:String = dicResponse!["intent"] as! String
            let platform:String = dicResponse2!["platform"] as! String
            //let payer_id:String = dicResponse3!["payment_method"] as! String
            let paymentType:String = "PayPal"
            
            print("id is  --->%@",payauid)
            print("created  time ---%@",paycreatetime)
            print("paystate is ----->%@",paystate)
            print("payintent is ----->%@",payintent)
            
            //print("payer_id is ----->%@",payer_id)
            
            guard paystate == "approved" else {
                print("pagamento non approvato riprova")
                self.generateAlert(title: "Attenzione", message: "Il pagamento non è stato approvato da Paypal, riprova")
                return
            }
            let payment = Payment(platform: platform, paymentType: paymentType, createTime: paycreatetime, idPayment: payauid, statePayment: paystate, autoId: "", total: "" )
            
            Cart.sharedIstance.paymentMethod = payment
            Cart.sharedIstance.pendingPayPalOffer()
            
            for order in Cart.sharedIstance.cart{
                order.dataCreazioneOfferta = paycreatetime
                order.calcolaDataScadenzaOfferta(selfOrder: (self.user?.idApp == order.userDestination?.idApp))
                order.pendingOffer()
            }
            DispatchQueue.main.async {
                self.startActivityIndicator("Pagamento in validazione...")
            }
            guard let userApp = self.user, let userIdApp = self.user?.idApp else { return }
            FirebaseData.sharedIstance.saveCartOnFirebase(user: userApp, badgeValue: self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int, onCompletion: {
                print("[PAYMENT]: ordine salvato su firebase")
                
                if Cart.sharedIstance.state == "Valid" {
                    print("[PAYMENT]: Pagamento carrello valido")
                    PointsManager.sharedInstance.readUserPointsStatsOnFirebase(userId: userIdApp, onCompletion: { (error) in
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        let points = PointsManager.sharedInstance.addPointsForShopping(userId:userIdApp, expense: Cart.sharedIstance.costoTotale)
                        PointsManager.sharedInstance.updateNewPointsOnFirebase(actualUserId: userIdApp, onCompletion: {
                            NotificationsCenter.pointsNotification(title: "Congratulazioni \((userApp.firstName)!)", body: "Hai appena cumulato \(points) Punti!")
                        })

                        print("[PAYMENT]: Punti aggiornati")
                        Cart.sharedIstance.initializeCart()
                        DispatchQueue.main.async(execute: {
                            self.stopActivityIndicator()
                            self.performSegue(withIdentifier: "unwindToOfferFromPayment", sender: nil)
                        })
                    })
                } else {
                    print("[PAYMENT]: Pagamento carrello non valido, riprova")
                    DispatchQueue.main.async(execute: {
                        self.generateAlert(title: "Attenzione", message: "Il pagamento non è stato validato, riprova su 'I miei Drinks' sezione 'Ricevuti'")
                    })
                }
            })
        })
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Metodi di pagamento"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return self.paymentMethod.count
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "paymentCell", for: indexPath)
        let arrayKey = [String](paymentMethod.keys).sorted{ $0<$1 }
        
        (cell as! PaymentTableViewCell).brandCompany.image = UIImage(named: self.paymentMethod[arrayKey[indexPath.row]]!)
        (cell as! PaymentTableViewCell).nameCompany.text = arrayKey[indexPath.row]
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let thisCell = tableView.cellForRow(at: indexPath)
        switch (thisCell as! PaymentTableViewCell).nameCompany.text! {
            
        case "PayPal":
            /*
             // Optional: include payment details
             let shipping = NSDecimalNumber(string: "0.19")
             let tax = NSDecimalNumber(string: "0.10")
             let paymentDetails = PayPalPaymentDetails(subtotal: subtotal, withShipping: shipping, withTax: tax)
             let total = subtotal.adding(shipping).adding(tax)*/
            var items: [PayPalItem] = []
            guard let ordersProducts = Order.sharedIstance.products else { return }
            for product in ordersProducts {
                guard let name = product.productName, let quantity = product.quantity, let price = product.price else { return }
                let item = PayPalItem(name: name, withQuantity: UInt(quantity), withPrice: NSDecimalNumber(string: String(format:"%.2f", price)), withCurrency: "EUR", withSku: "")
                items.append(item)
            }
            //let total = PayPalItem.totalPrice(forItems: items)
            
            let total = NSDecimalNumber(value: Cart.sharedIstance.costoTotale)
            
            let payment = PayPalPayment(amount: total, currencyCode: "EUR", shortDescription: "Morgana Music Club", intent: .sale)
            /*
            payment.items = items
            payment.paymentDetails = paymentDetails
            */
            
                
            if (payment.processable) {
                let paymentViewController = PayPalPaymentViewController(payment: payment, configuration: self.payPalConfig, delegate: self)
                self.present(paymentViewController!, animated: true, completion: nil)
                
            }
            else {
                print("Payment not processalbe: \(payment)")
            }
            break
        case "ApplePay":
            break
        case "Crediti":
            self.performSegue(withIdentifier: "segueToCreditsPayment", sender: nil)
            break
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "segueToCreditsPayment":
            (segue.destination as! CreditsPaymentViewController).shopTotal = Cart.sharedIstance.costoTotale
            (segue.destination as! CreditsPaymentViewController).user = self.user
            break
        default:
            break
        }
    }
    
    
    private func completeCartInformation(){
        for j in Cart.sharedIstance.cart {
            //Get idApp
            guard let idFBUserDestination = j.userDestination?.idFB else { return }
            FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "idFB", idFB: idFBUserDestination, onCompletion: { (error,idApp) in
                guard error == nil else {
                    print(error!)
                    return
                }
                guard let IDApp = idApp else {return}
                if IDApp != "04fLLHPLYYboLfy8enAkogDcdI02" {
                    j.userDestination?.idApp = IDApp
                    self.completeCartWithFirebaseToken(idApp: IDApp)
                }
            })
            
        }
    }
    
    //complete caurosel with Firebase Token
    private func completeCartWithFirebaseToken(idApp: String){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/"+idApp, onCompletion: { (error,dictionary) in
            guard error == nil else {
                self.generateAlert(title: "Attenzione connessione Internet assente", message: "Accertati che la tua connessione WiFi o cellulare sia attiva")
                return
            }
            guard dictionary != nil else {return}
            if (dictionary?["autoId"] as? String) != "04fLLHPLYYboLfy8enAkogDcdI02"{
                //in seguito da eliminare escludo l'utente vittorio del simulatore
                for order in Cart.sharedIstance.cart {
                    if order.userDestination?.idApp == idApp {
                        order.userDestination?.fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as? String
                    }
                }
            }
        })
    }
    
    @IBAction func unwindToPaymentMethod(_ sender: UIStoryboardSegue) {
        
    }
    
    @IBAction func unwindToCarousel(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "unwindToCarousel", sender: nil)
        self.dismiss(animated: true) { () -> Void in
            print("VC Dismesso")
        }
    }
    
    
    func startActivityIndicator(_ title: String) {
        
        strLabel.removeFromSuperview()
        activityIndicator.removeFromSuperview()
        effectView.removeFromSuperview()
        
        strLabel = UILabel(frame: CGRect(x: 50, y: 0, width: 240, height: 66))
        strLabel.text = title
        strLabel.font = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.medium)
        strLabel.textColor = UIColor(white: 0.9, alpha: 0.7)
        
        effectView.frame = CGRect(x: view.frame.midX - strLabel.frame.width/2, y: view.frame.midY - strLabel.frame.height/2 , width: 240, height: 66)
        effectView.layer.cornerRadius = 15
        effectView.layer.masksToBounds = true
        
        //activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.white
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 46, height: 66)
        activityIndicator.startAnimating()
        
        
        effectView.contentView.addSubview(activityIndicator)
        effectView.contentView.addSubview(strLabel)
        /*
         effectView.addSubview(activityIndicator)
         effectView.addSubview(strLabel)*/
        
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
    
}
