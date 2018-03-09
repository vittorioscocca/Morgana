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
        print("\(node)/\(child)")
        ref.child(node).child(child).childByAutoId().setValue(dictionaryToSave)
        
        onCompletion(error)
    }
    
    class func saveNodeOnFirebaseWithPassedAutoId(node: String, child: String, passedAutoId: String, dictionaryToSave: [String:Any],onCompletion: @escaping (String?) -> ()) {
        
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        print("\(node)/\(child)")
        ref.child(node).child(child).child(passedAutoId).setValue(dictionaryToSave)
        
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
    
    class func saveNodeOnFirebase(node: String, dictionaryToSave: [String:Any],onCompletion: @escaping (String?) -> ()) {
        
        guard CheckConnection.isConnectedToNetwork() == true else{
            error = "Connessione Internet Assente"
            onCompletion(error)
            return
        }
        
        ref.child(node).setValue(dictionaryToSave)
        onCompletion(error)
    }
    
    
    
    
    //read node withOut AutoId
    class func readNodeOnFirebaseWithOutAutoId(node: String, onCompletion: @escaping (String?,[String:Any]?) -> ()){
        
        guard CheckConnection.isConnectedToNetwork() == true else {
            error = "Connessione Internet Assente"
            onCompletion(error,nil)
            return
        }
        ref.child(node).observeSingleEvent(of: .value, with: { (snap) in
            
            // controllo che lo snap dei dati non sia vuoto
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,nil)
                return
            }
            
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            
            for (chiave,valore) in nodeDictionary {
                dictionary?[chiave as! String] = valore
            }
            
            onCompletion(error,dictionary)
            
        })
    }
    
    class func setId(node:String)->String {
        return ref.child(node).childByAutoId().key
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
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+node+" non esiste")
                completionHandler(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
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
            
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
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
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
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
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+node+" non esiste")
                onCompletion(error,dictionary)
                return
            }

            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
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
            
            guard let _ = snap.value, snap.exists() else {
                error = "Valore \(child) non trovato"
                onCompletion(error,nil)
                return
            }
            onCompletion(error,snap.key)
        })
        
        
    }
    
    class func readNodeForValueEqualTo(node: String, child: String, value: String?, onCompletion: @escaping (String?,[String:Any]?) -> ()){
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
            guard let snap_value = snap.value, snap.exists() else {
                error = "Valore \(child) non trovato"
                onCompletion(error,nil)
                return
            }
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSDictionary
            dictionary = [:]
            
            // leggo i dati dell'ordine o offerte
            
            for (chiave,valore) in nodeDictionary {
                dictionary?[chiave as! String] = valore
            }
            onCompletion(error,dictionary)
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
    
    //remove Node with autoId
    class func removeNode(node: String, autoId: String){
        ref.child(node + "/" + autoId).removeValue()
    }
    
    class func removeNode(node: String){
        ref.child(node).removeValue()
    }
    
    //remove FireBase DB
    class func resetFirebaseDB(){
        //remove ordersSent
        ref.child("ordersSent").removeValue()
        
        //remove ordersReceived
        ref.child("ordersReceived").removeValue()
        
        //remove Payement
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
            guard let snap_value = snap.value, snap.exists() else {
                print("snap "+sourceChild+" non esiste")
                onCompletion(error)
                return
            }
            
            // eseguo il cast in dizionario dato che so che sotto offers c'è un dizionario
            let nodeDictionary = snap_value as! NSMutableDictionary
            
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
    
    //PAGINATION while scrolling for MyOrderView
    /*
    func retrievePost(offset: NSNumber, callFlag: Bool, completion: (result: AnyObject?, error: NSError?)->()){
        // As this method is called from viewDidLoad and fetches 20 records at first.
        // Later when user scrolls down to bottom, its called again
        let postsRef = ref.child(kDBPostRef)
        var startingValue:AnyObject?
        // starting  value will be nil when this method is called from viewDidLoad as the offset is not set
        
        if callFlag{
            if offset == 0{
                startingValue = nil
            }
            else{
                startingValue = offset
            }
        } else{
            // get offset from the offsetArray
            startingValue = self.findOffsetFromArray()
            
        }
        // sort records by pOrder fetch offset+1 records
        self.refHandler = postsRef.queryOrderedByChild("pOrder").queryStartingAtValue(startingValue).queryLimitedToFirst(kPostLimit + 1).observeEventType(FIRDataEventType.Value, withBlock: { (snapshot) in
            // flag is for setting the last record/ 21st as offset
            var flag = 0
            
            let tempPost = NSMutableSet()
            // iterate over children and add to tempPost
            for item in snapshot.children {
                
                // check for offet, the last row(21st) is offset ; Do not add last element in the main table list
                flag += 1
                if flag == 21 && callFlag == true{
                    // this row is offset
                    self.kOffset = item.value?["pOrder"] as! NSNumber
                    self.offSetArray?.append(self.kOffset)
                    continue
                }
                // create Post object
                let post = Post(snapshot: item as! FIRDataSnapshot)
                
                // append to tempPost
                tempPost.addObject(post)
            }
            // return to the closure
            completion(result:tempPost, error:nil)
        })

        func updateNewRecords(offset:NSNumber, callFlag: Bool){
            self.retrievePost(offset,callFlag:callFlag) { (result,error) -> Void in
                //            let tempArray = result as! [Post]
                let oldSet = Set(self.posts)
                var unionSet = oldSet.union(result as! Set<Post>)
                unionSet = unionSet.union(unionSet)
                self.posts = Array(unionSet)
                self.postsCopy = self.posts
                //          print(self.posts.count)
                self.posts.sortInPlace({ $0.pOrder> $1.pOrder})
                self.reloadTableData()
            }
        }
        
        func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            
            // UITableView only moves in one direction, y axis
            let currentOffset = scrollView.contentOffset.y
            let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
            
            // Change 10.0 to adjust the distance from bottom
            if maximumOffset - currentOffset <= 10.0 {
                self.updateNewRecords(self.kOffset, callFlag:true)
            }
        }
        
        // find the offset from the offsetDict
        func findOffsetFromArray() -> NSNumber{
            let idx = self.kClickedRow/20 // kClickedRow is the updated row in the table view
            return self.offSetArray![idx]
            
        }*/
    
}
