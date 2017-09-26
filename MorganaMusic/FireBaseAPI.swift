//
//  FireBaseAppIO.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 04/07/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation

import UIKit
import FirebaseDatabase
import FirebaseAuth
import Firebase
import FirebaseMessaging
import FirebaseInstanceID
import UserNotifications

class FireBaseAPI {
    
    static let ref = Database.database().reference()
    static var dictionary: [String:Any]?
    
    static var error: String?
   
    class func saveNodeOnFirebaseWithAutoId (node: String, child: String, dictionaryToSave: [String:Any],onCompletion: @escaping (String?) -> ()) {
        
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        
        ref.child(node).child(child).childByAutoId().setValue(dictionaryToSave)
        onCompletion(error)
    }
    
    class func saveNodeOnFirebaseWithoutAutoId (node: String, child: String, dictionaryToSave: [String:Any],onCompletion: @escaping (String?) -> ()) {
        
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        
        ref.child(node).child(child).setValue(dictionaryToSave)
        onCompletion(error)
    }
    
    
    
    
    //read node withOut AutoId
    class func readNodeOnFirebaseWithOutAutoId(node: String, onCompletion: @escaping (String?,[String:Any]?) -> ()){
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,dictionary)
            return
        }
        ref.child(node).observeSingleEvent(of: .value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            
            guard snap.value != nil else {
                print("snap "+node+" non ha valori")
                onCompletion(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            
            for (chiave,valore) in nodeDictionary {
                dictionary?[chiave as! String] = valore
            }
            
            onCompletion(error,dictionary)
            
        })
    }
    
    //read node withOut AutoId
    class func readNodeOnFirebaseWithOutAutoIdHandler(node: String, beginHandler: @escaping ()->(),completionHandler: @escaping (String?,[String:Any]?) -> ()){
        
        beginHandler()
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            completionHandler(error,dictionary)
            return
        }
        ref.child(node).observeSingleEvent(of: .value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {
                print("snap "+node+" non esiste")
                completionHandler(error,dictionary)
                return
            }
            
            guard snap.value != nil else {
                print("snap "+node+" non ha valori")
                completionHandler(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            
            for (chiave,valore) in nodeDictionary {
                dictionary?[chiave as! String] = valore
            }
            
            completionHandler(error,dictionary)
            
        })
    }
    
    //read node
    class func readNodeOnFirebaseHandler(node: String, beginHandler: @escaping ()->(),onCompletion: @escaping (String?,[String:Any]?) -> ()){
        
        beginHandler()
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,dictionary)
            return
        }
        ref.child(node).observeSingleEvent(of: .value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            guard snap.value != nil else {
                print("snap "+node+" non ha valori")
                onCompletion(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            for (autoId, childDictionary) in nodeDictionary{
                dictionary?["autoId"] = autoId
                for (chiave,valore) in (childDictionary as! NSDictionary) {
                    dictionary?[chiave as! String] = valore
                }
                
                onCompletion(error,dictionary)
            }
            
        })
    }

    
    //read node
    class func readNodeOnFirebase(node: String, onCompletion: @escaping (String?,[String:Any]?) -> ()){
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,dictionary)
            return
        }
        ref.child(node).observeSingleEvent(of: .value, with: { (snap) in
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            guard snap.value != nil else {
                print("snap "+node+" non ha valori")
                onCompletion(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            for (autoId, childDictionary) in nodeDictionary{
                dictionary?["autoId"] = autoId
                for (chiave,valore) in (childDictionary as! NSDictionary) {
                    dictionary?[chiave as! String] = valore
                }
                
                onCompletion(error,dictionary)
            }
            
        })
    }
    
    //read node with query Limited
    
    class func readNodeOnFirebaseQueryLimited (node: String, queryLimit: Int, onCompletion: @escaping (String?,[String:Any]?) -> ()){
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,dictionary)
            return
        }
        let query = ref.child(node).queryLimited(toLast: UInt(queryLimit))
        query.observeSingleEvent(of: .value, with: { (snap) in
            
            // controllo che lo snap dei dati non sia vuoto
            guard snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            guard snap.value != nil else {
                print("snap "+node+" non ha valori")
                onCompletion(error,dictionary)
                return
            }

            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            for (autoId, childDictionary) in nodeDictionary{
                dictionary?["autoId"] = autoId
                for (chiave,valore) in (childDictionary as! NSDictionary) {
                    dictionary?[chiave as! String] = valore
                }
                //dictionaries?.append(dictionary!)
                onCompletion(error,dictionary)
            }
        })
    }
    
    class func readKeyForValueEqualTo(node: String, child: String, value: String?, onCompletion: @escaping (String?,String?) -> ()){
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,nil)
            return
        }
        guard value != nil else {
            error = "Valore \(child) nullo"
            onCompletion(error,nil)
            return
        }
        let query = ref.child(node).queryOrdered(byChild: child).queryEqual(toValue: value)
        query.observeSingleEvent(of: .childAdded, with: { (snap) in
            guard snap.exists() else {
                error = "Valore \(child) non trovato"
                onCompletion(error,nil)
                return
            }
            guard snap.value != nil else {
                error = "Valore \(child) non trovato"
                return
            }
            onCompletion(error,snap.key)
        })
        
        
    }
    
    //update value
    class func updateNode (node: String, value: [String:Any]){
        ref.child(node).updateChildValues(value)
    }
    
    class func updateNode (node: String, value: [String:Any],onCompletion: @escaping (String?)->()){
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        ref.child(node).updateChildValues(value)
        onCompletion(error)
    }
    
    class func returnFirebaseTimeStamp(onCompletion: @escaping (TimeInterval?)->()) {
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(nil)
            return
        }
        ref.child("sessions").setValue(ServerValue.timestamp())
        ref.child("sessions").observeSingleEvent(of: .value, with: { (snap) in
            let timeStamp = snap.value! as! TimeInterval
            onCompletion(timeStamp)
        })
    }
    
    //remove Node
    class func removeNode(node: String, autoId: String){
        ref.child(node + "/" + autoId).removeValue()
    }
    
    //remove FireBase DB
    class func resetFirebaseDB(){
        //remove orderOffered
        ref.child("orderOffered").removeValue()
        
        //remove Payement
        ref.child("orderReceived").removeValue()
        
        //remove orderReceived
        ref.child("pendingPayments").removeValue()
        
        //remove OrderDetails
        ref.child("productsOffersDetails").removeValue()
        
        //resetUserPointsStats
        
    }
    
    
    class func moveFirebaseRecord(sourceChild: String, destinationChild: String, onCompletion: @escaping (String?)->()){
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        ref.child(sourceChild).observeSingleEvent(of: .value, with: { (snapshot) in
            ref.child(destinationChild).setValue(snapshot.value)
            ref.child(sourceChild).removeValue()
            onCompletion(error)
            
        })
    }
    
    class func moveFirebaseRecordApplyingChanges(sourceChild: String, destinationChild: String, newValues: [String:Any],onCompletion: @escaping (String?)->()){
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        ref.child(sourceChild).observeSingleEvent(of: .value, with: { (snap) in
            guard snap.exists() else {
                print("snap "+sourceChild+" non esiste")
                onCompletion(error)
                return
            }
            guard snap.value != nil else {
                print("snap "+sourceChild+" non ha valori")
                onCompletion(error)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap.value! as! NSMutableDictionary
            
            for (chiave,valore) in newValues {
                nodeDictionary[chiave] = valore
            }

            ref.child(destinationChild).setValue(nodeDictionary)
            ref.child(sourceChild).removeValue()
            onCompletion(error)
            
        })
    }
    
    class func removeObserver (node: String){
        ref.child(node).removeAllObservers()
    }

    
}
