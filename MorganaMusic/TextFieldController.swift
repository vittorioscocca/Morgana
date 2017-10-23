//
//  TextFieldController.swift
//  FormLogin
//
//  Created by Vittorio Scocca on 22/02/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import UIKit


//estensione della classe UIViewController

extension UIViewController {
    
    //aggiungo la funzione per far scomparire la tastiera
    func closeTextFieldAtTouch(txtFields: [UITextField]) {
        for x in txtFields {
            x.resignFirstResponder()
        }
    }
}


class TextFieldController: NSObject, UITextFieldDelegate {
    static let singleton = TextFieldController() //creo il singleton della classe
    
    private override init() {
        super.init()
    }
    
    //funzione che disattiva (la fa scomparire) la tastiera quando viene premuto invio sulla stessa
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("Premuto il tasto Return")
        //gestisce il passaggio tra TextField da una all'altra quando l'utente preme Invio
        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
            //se esiste allora diventa la FirstResponder, cioè si attiva (e compare la tastiera)
            nextField.becomeFirstResponder()
        } else {
            //se non la trova resignFirstResponder() riporta la textfield al suo stato naturale (tastiera chiusa)
            textField.resignFirstResponder()
        }

        
        textField.resignFirstResponder()
        return true
    }
    
    

    /*
    // funzione che controlla per ogni field a cui abbiamo associato il delegate se l'utente ha  inserito del testo
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        guard !textField.text!.isEmpty else {
            switch textField.tag {
            case 0:
                textField.placeholder = "Inserisci nome utente"
                return false
            case 1:
                textField.placeholder = "Inserisci password"
                return false
            default:
                return false
            }
            
        }
        return true
    }
    */

    
}
