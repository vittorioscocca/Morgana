//
//  CreditsPaymentViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 05/11/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import LocalAuthentication


class CreditsPaymentViewController: UIViewController {
    
    @IBOutlet weak var shopTotal_label: UILabel!
    @IBOutlet weak var userCredits_label: UILabel!
    @IBOutlet weak var msg: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    @IBOutlet weak var userTotalShopStack: UIStackView!
    
    var shopTotal: Double?
    var userCredits: Double?
    var user: User?
    var alert = UIAlertController()
    var incorrectPassword = false
    var productOfferedBadge = UserDefaults.standard
    var controller: UIAlertController?
    
    //Activity Indicator
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var strLabel = UILabel()
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        userTotalShopStack.layer.borderColor = UIColor.black.cgColor
        userTotalShopStack.layer.borderWidth = 2.0
        
        shopTotal_label.text = "€ " + String(format:"%.2f", shopTotal!)
        readCredits()
    }
    
    func readCredits(){
        FireBaseAPI.readNodeOnFirebaseWithOutAutoId(node: "users/" + (user?.idApp)!, onCompletion: { (error,dictionary) in
            guard error == nil else {
                return
            }
            guard dictionary != nil else {
                return
            }
            self.userCredits_label.text = "€ " + String(format:"%.2f", dictionary?["credits"] as! Double)
            self.userCredits = dictionary?["credits"] as? Double
            
            if self.userCredits! < self.shopTotal! {
                self.msg.isHidden = false
            } else {
                self.buyButton.isHidden = false
            }
            
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func unwindToPaymentMethods(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "unwindToPaymentMethods", sender: nil)
        self.dismiss(animated: true) { () -> Void in
            print("VC Dismesso")
        }
    }
    
    

    @IBAction func authPayment(_ sender: UIButton) {
        guard let total = shopTotal else {
            alert = UIAlertController(title: "Errore", message: "Lettura totale spesa non valida", preferredStyle: .alert)
            let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:{(
                paramAction:UIAlertAction!) in print("Il messaggio di chiusura è stato premuto")
            })
            alert.addAction(action)
            present(self.alert, animated: true, completion: nil)
            return
        }
        
        guard let currentUserCredits = userCredits else {
            alert = UIAlertController(title: "Errore", message: "Lettura totale credito non valida", preferredStyle: .alert)
            let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:{(
                paramAction:UIAlertAction!) in print("Il messaggio di chiusura è stato premuto")
            })
            alert.addAction(action)
            present(self.alert, animated: true, completion: nil)
            return
        }
        
        guard (currentUserCredits - total) >= 0 else {
            alert = UIAlertController(title: "Attenzione", message: "Il tuo credito non è sufficiente per effettuare l'acquisto", preferredStyle: .alert)
            let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:{(
                paramAction:UIAlertAction!) in print("Il messaggio di chiusura è stato premuto")
            })
            alert.addAction(action)
            present(self.alert, animated: true, completion: nil)
            return
        }
        userPaymentAuth()
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

extension CreditsPaymentViewController {
    
    func userPaymentAuth(){
        let context = LAContext()
        //context.touchIDAuthenticationAllowableReuseDuration = 60
        var error:NSError?
        let stringaRichiesta = "Autenticarsi per autorizzare il pagamento"
        //context.localizedFallbackTitle = "Use Passcode"
        
        if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &error){
            context.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: stringaRichiesta, reply: { (successo, errorePolicy) -> Void in
                
                if successo   // questo if-else verifica se l'autenticazione è avventua con successo o meno
                {
                    print("Autenticazione avvenuta con successo") // stampiamo in console
                    OperationQueue.main.addOperation({ () -> Void in
                        self.startActivityIndicator("Pagamento in validazione...")
                        self.executePayment()
                    })
                    
                }else {      // se la'utenticazione fallisce entriamo nei case in base al tipo di scelte che facciamo
                    switch errorePolicy?._code{
                    case LAError.systemCancel.rawValue?:                   // in caso di errore di sistema
                        print("Autenticazione cancellata dal sistema")   // stampiamo in console
                        
                    case LAError.userCancel.rawValue?:                   // se premiamo Cancel
                        print("Autenticazione cancellata dall'Utente") // stampiamo in console
                    default :                             // se nessuno dei casi è valido
                        print("Autenticazione fallita")  // stampiamo a console
                    }
                }
                
            })
        }else {
            print((error?.localizedDescription)!)  // stampa l'eventuale errore e mostra nuovamente la richiesta
        }
    }
    
    func executePayment(){
        print("User credit Payment Success!")
        
        let formatter = DateFormatter()
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "yyyy-MM-dd'T'H:mm:ssZ"
        let paycreatetime = formatter.string(from: Date())
        let paystate = "approved"
        let paymentType:String = "Credits"

        let payment = Payment(platform: "ND", paymentType: paymentType, createTime: paycreatetime, idPayment: "", statePayment: paystate, autoId: "", total: "" )
        
        Cart.sharedIstance.paymentMethod = payment
        Cart.sharedIstance.pendingPayPalOffer()
        
        for order in Cart.sharedIstance.carrello{
            order.dataCreazioneOfferta = paycreatetime
            order.calcolaDataScadenzaOfferta(selfOrder: (self.user?.idApp! == order.userDestination?.idApp!))
            order.pendingOffer()
        }
        
        FirebaseData.sharedIstance.saveCartOnFirebase(user: self.user!, badgeValue: self.productOfferedBadge.object(forKey: "paymentOfferedBadge") as? Int, onCompletion: {
            print("ordine salvato su firebase")
            DispatchQueue.main.async {
                // ritorno sul main thread ed aggiorno la view
                self.stopActivityIndicator()
            }
            
            if Cart.sharedIstance.state == "Valid" {
                print("Pagamento carrello valido")
                
                FireBaseAPI.updateNode(node: "users/" + (self.user?.idApp)!, value: ["credits": self.userCredits! - self.shopTotal! ], onCompletion: { (error) in
                    guard error == nil else {
                        print("Errore di connessione")
                        return
                    }
                    print("Crediti aggiornati")
                })
                
                self.alert = UIAlertController(title: "Pagamento avvenuto con successo", message: "Ora il tuo credito è " + "€ " + String(format:"%.2f", self.userCredits! - self.shopTotal!), preferredStyle: .alert)
                let action = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{(
                    paramAction:UIAlertAction!) in
                    Cart.sharedIstance.initializeCart()
                    self.performSegue(withIdentifier: "unwindToOfferFromCreditsPayment", sender: nil)
                })
                self.alert.addAction(action)
                
                self.present(self.alert, animated: true, completion: nil)
            } else {
                print("Pagamento carrello non valido, riprova")
                self.generateAlert(title: "Attenzione", message: "Il pagamento non è stato validato, riprova su 'I miei Drinks' sezione 'Ricevuti'")
            }
        })
    }
    
    func generateAlert(title: String, message:String){
        controller = UIAlertController(title: title,
                                       message: message,
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("Il messaggio di chiusura è stato stampato")
        })
        
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
}
