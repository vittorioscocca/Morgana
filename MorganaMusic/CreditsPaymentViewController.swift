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
    
    var shopTotal: Double?
    var userCredits: Double?
    var user: User?
    var incorrectPassword = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        shopTotal_label.text = "€"+String(format:"%.2f", shopTotal!)
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
            self.userCredits_label.text = String(format:"%.2f", dictionary?["credits"] as! Double)
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
        self.userPaymentAuth()
    }
    
}

extension CreditsPaymentViewController {
    
    func userPaymentAuth(){
        let
        context = LAContext()
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
                        //inserire qui codice per
                        // - sottrare i crediti appena consumati
                        // - salvare l'ordine su firebase
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
    
}
