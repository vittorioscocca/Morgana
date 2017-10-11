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
    
    //PayPalEnvironmentSandbox
    //PayPalEnvironmentProduction
    //Production run only on hardware device
    var environment:String = PayPalEnvironmentSandbox {
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
        "Crediti" : "i tuoi crediti"
    ]
    
    //App idUtente su FireBase
    var user: User?
    var uid: String?
    
    var fireBaseToken = UserDefaults.standard
    var productOfferedBadge = UserDefaults.standard
    
    var controller: UIAlertController?
    
    //Activity Indicator
    
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.uid = fireBaseToken.object(forKey: "FireBaseToken") as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(uid)
        
        // Set up payPalConfig
        payPalConfig.acceptCreditCards = false
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
    
    func payPalPaymentViewController(_ paymentViewController: PayPalPaymentViewController, didComplete completedPayment: PayPalPayment)
    {
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
            
            for order in Cart.sharedIstance.carrello{
                order.dataCreazioneOfferta = paycreatetime
                order.calcolaDataScadenzaOfferta(selfOrder: (self.user?.idApp! == order.userDestination?.idApp!))
                order.pendingOffer()
            }
            DispatchQueue.main.async {
                self.startActivityIndicator("Pagamento in validazione...")
            }
            FirebaseData.sharedIstance.saveCartOnFirebase(user: self.user!, badgeValue: self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as! Int, onCompletion: {
                print("ordine salvato su firebase")
                DispatchQueue.main.async {
                    // ritorno sul main thread ed aggiorno la view
                    self.stopActivityIndicator()
                }
                
                if Cart.sharedIstance.state == "Valid" {
                    print("Pagamento carrello valido")
                    
                    PointsManager.sharedInstance.readUserPointsStatsOnFirebase(userId: (self.user?.idApp)!, onCompletion: { (error) in
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        let points = PointsManager.sharedInstance.addPointsForShopping(userId:(self.user?.idApp)!,expense: Cart.sharedIstance.costoTotale)
                        PointsManager.sharedInstance.updateNewValuesOnFirebase(actualUserId: (self.user?.idApp)!,onCompletion: {
                            
                            NotificationsCenter.localNotification(title: "Congratulazioni \((self.user?.firstName)!)", body: "Hai appena cumulato \(points) Punti!")
                        })
                        
                        print("Punti aggiornati")
                        Cart.sharedIstance.initializeCart()
                        self.performSegue(withIdentifier: "unwindToOfferFromPayment", sender: nil)
                    })
                    
                    
                    
                } else {
                   print("Pagamento carrello non valido, riprova")
                    self.generateAlert(title: "Attenzione", message: "Il pagamento non è stato validato, riprova su 'I miei Drinks' sezione 'Ricevuti'")
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
        let arrayKey = [String](paymentMethod.keys)
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
            for i in Order.sharedIstance.prodotti! {
                let item = PayPalItem(name: i.productName!, withQuantity: UInt(i.quantity!), withPrice: NSDecimalNumber(string: String(format:"%.2f", i.price!)), withCurrency: "EUR", withSku: "")
                items.append(item)
            }
            //let total = PayPalItem.totalPrice(forItems: items)
            
            let total = NSDecimalNumber(value: Cart.sharedIstance.costoTotale)
            
            let payment = PayPalPayment(amount: total, currencyCode: "EUR", shortDescription: "Morgana Music Club", intent: .sale)
            /*
             payment.items = items
             payment.paymentDetails = paymentDetails*/
            
            if (payment.processable) {
                let paymentViewController = PayPalPaymentViewController(payment: payment, configuration: payPalConfig, delegate: self)
                present(paymentViewController!, animated: true, completion: nil)
                
            }
            else {
                // This particular payment will always be processable. If, for
                // example, the amount was negative or the shortDescription was
                // empty, this payment wouldn't be processable, and you'd want
                // to handle that here.
                print("Payment not processalbe: \(payment)")
            }
            break
        case "ApplePay":
            break
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    
    private func completeCartInformation(){
        for j in Cart.sharedIstance.carrello {
                //Get idApp
            FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "idFB", idFB: (j.userDestination?.idFB)!, onCompletion: { (error,idApp) in
                guard error == nil else {
                    print(error!)
                    return
                }
                guard idApp != nil else {return}
                if idApp! != "04fLLHPLYYboLfy8enAkogDcdI02" {
                    j.userDestination?.idApp = idApp!
                    self.completeCartWithFirebaseToken(idApp: idApp!)
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
                    for order in Cart.sharedIstance.carrello {
                        if order.userDestination?.idApp == idApp {
                            order.userDestination?.fireBaseIstanceIDToken = dictionary?["fireBaseIstanceIDToken"] as? String
                        }
                    }
                }
            })
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
