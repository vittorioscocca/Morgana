//
//  CoreData.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 06/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class CoreDataController {
    
    static let sharedIstance = CoreDataController()
    private var context: NSManagedObjectContext
    
    private init() {
        let application = UIApplication.shared.delegate as! AppDelegate
        self.context = application.persistentContainer.viewContext
    }
    
    
    func addNewUser(_ idApp: String, _ idFB: String, _ email: String?, _ fullName: String?, _ firstName: String?, _ lastName: String?, _ gender: String?, _ pictureUrl: String? ) -> User {
        
        let user = self.findUserForIdApp(idApp)
        guard  user == nil else {
            return user!
        }
        let entityUser = NSEntityDescription.entity(forEntityName: "User", in: self.context)
        let newUser = User(entity: entityUser!, insertInto: self.context)
        
        newUser.idApp = idApp
        newUser.idFB = idFB
        newUser.email = email
        newUser.fullName = fullName
        newUser.firstName = firstName
        newUser.lastName = lastName
        newUser.gender = gender
        newUser.pictureUrl = pictureUrl
        
        self.salvaContext()
        print("Utente \(newUser.fullName!) salvato in memoria")
        print(newUser.idApp!)
        print(newUser.idFB!)
        print(newUser.email!)
        print(newUser.gender!)
        print(newUser.pictureUrl!)
        
        return newUser
    }
    
    
    func saveCityAndBirthday(idApp: String, cityOfRecidence: String?, birthday: String?) {
        
        let currentUser = self.findUserForIdApp(idApp)
        
        guard  currentUser != nil else {
            return
        }
        currentUser?.cityOfRecidence = cityOfRecidence
        currentUser?.birthday = birthday
        self.salvaContext()
    }
    
    private func salvaContext() {
        do {
            try self.context.save()
        } catch let error as NSError {
            print(error)
        }
    }
    
    //cerca un utente per la idApp
    func findUserForIdApp(_ idApp: String?) -> User? {
        
        if idApp == nil {
            return nil
        }
        var user: User?
        
        let request: NSFetchRequest<User> = NSFetchRequest(entityName: "User")
        request.returnsObjectsAsFaults = false
        
        let predicate = NSPredicate(format: "idApp = %@", idApp!)
        request.predicate = predicate
        
        
        do {
            let result: Array = try self.context.fetch(request)
            
            switch result.count {
            case 0:
                print("L' utente: \(idApp!) non esiste!")
                return nil
                
            case 1:
                user = result[0]
                return user!
            case 2:
                user = result[0]
                return user!
            case 3:
                user = result[0]
                return user!
            default:
                return nil
            }
            
        } catch let error as NSError {
            print("Errore recupero informazioni dal context \n \(error.description)")
        }
        
        return nil
    }
    
    
    //cerca un utente per  email
    func findUserForEmail(_ email: String) -> User? {
        var user: User?
        
        let request: NSFetchRequest<User> = NSFetchRequest(entityName: "User")
        let predicate = NSPredicate(format: "email = %@", email)
        request.predicate = predicate
        request.returnsObjectsAsFaults = false
        
        do {
            let result: Array = try self.context.fetch(request)
            
            switch result.count {
            case 0:
                print("L' utente: \(email) non esiste!")
                return nil
                
            case 1:
                print("L'Utente \(email) è in memoria")
                user = result[0]
                print("Utente \(user!.email!) \(user!.idApp!)")
                return user!
            case 2:
                user = result[0]
                return user!
            case 3:
                user = result[0]
                return user!
            default:
                return nil
            }
        } catch let error as NSError {
            print("Errore recupero informazioni dal context \n \(error.description)")
        }
        return nil
    }
    
    func addFriendInUser(idAppUser: String, idFB: String, mail: String?, fullName: String?, firstName: String?, lastName: String?, gender: String?, pictureUrl: String?, cityOfRecidence: String?) {
        let entityFriend = NSEntityDescription.entity(forEntityName: "Friend", in: self.context)
        let newFriend = Friend(entity: entityFriend!, insertInto: self.context)
        let currentUser = findUserForEmail(mail!)
        
        
        newFriend.user = currentUser!
        
        newFriend.idFB = idFB
        newFriend.fullName = fullName
        newFriend.firstName = firstName
        newFriend.lastName = lastName
        newFriend.gender = gender
        newFriend.pictureUrl = pictureUrl
        newFriend.cityOfRecidence = cityOfRecidence
        currentUser!.addToFriends(newFriend)
        
        print("Amico  \(fullName!) aggiunto allo user \(currentUser!.fullName!)")
        self.salvaContext()
    }
    
    
    //Carica tutti gli amici di uno user
    func loadAllFriendsOfUser(idAppUser: String) ->[Friend]?{
        print("[CDC] Recupero tutti gli amici dell'utente: \(idAppUser) ")
        
        let user = findUserForIdApp(idAppUser)
        guard user != nil else  {
            return nil
        }
        let friends = user?.friends!.allObjects as! [Friend]
        return friends
        
    }
    
    //restituisce il numero di amici
    func friendsNumber(idAppUser: String) -> Int {
        let user = findUserForIdApp(idAppUser)
        guard user != nil  else{
            return 0
        }
        
        let friends = user?.friends!.allObjects as! [Friend]
        return friends.count
    }
    
    
    //Cancelle tutti gli amici di un utente

    func deleteFriends(_ idApp: String) {
        let user = findUserForIdApp(idApp)
        user?.removeFromFriends((user?.friends)!)
        do {
            try self.context.save()
        } catch let errore {
            print("[CDC] Problema eliminazione amico ")
            print("  Stampo l'errore: \n \(errore) \n")
        }
    }
    
    //cancella l'user
    func deleteUser(_ idApp: String) {
        let user = self.findUserForIdApp(idApp)
        if user != nil {
            self.context.delete(user!)
        
        
            do {
                try self.context.save()
            } catch let errore {
                print("[CDC] Problema eliminazione user ")
                print("  Stampo l'errore: \n \(errore) \n")
            }
        }
    }
}
