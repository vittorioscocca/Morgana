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
            user?.idApp = idApp
            user?.idFB = idFB
            user?.email = email
            user?.fullName = fullName
            user?.firstName = firstName
            user?.lastName = lastName
            user?.gender = gender
            user?.pictureUrl = pictureUrl
            return user!
        }
        guard let entityUser = NSEntityDescription.entity(forEntityName: "User", in: self.context) else { return user! }
        let newUser = User(entity: entityUser, insertInto: self.context)
        newUser.idApp = idApp
        newUser.idFB = idFB
        newUser.email = email
        newUser.fullName = fullName
        newUser.firstName = firstName
        newUser.lastName = lastName
        newUser.gender = gender
        newUser.pictureUrl = pictureUrl
        
        self.salvaContext()
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
        
        guard let idAPP =  idApp else {
            return nil
        }
        var user: User?
        
        let request: NSFetchRequest<User> = NSFetchRequest(entityName: "User")
        request.returnsObjectsAsFaults = false
        
        let predicate = NSPredicate(format: "idApp = %@", idAPP)
        request.predicate = predicate
        
        
        do {
            let result: Array = try self.context.fetch(request)
            
            switch result.count {
            case 0:
                print("L' utente: \(idAPP) non esiste!")
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
                return result[0]
                
            case 2:
                 return result[0]
                
            case 3:
                return result[0]
                
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

        self.salvaContext()
    }
    
    
    //Carica tutti gli amici di uno user
    func loadAllFriendsOfUser(idAppUser: String, completion:@ escaping ([Friend]?)->()){
        guard let user = findUserForIdApp(idAppUser) else  {
            completion(nil)
            return
        }
        guard let friends = user.friends?.allObjects as? [Friend] else { return }
        completion(friends)
        
    }
    
    //restituisce il numero di amici
    func friendsNumber(idAppUser: String) -> Int {
        guard let user = findUserForIdApp(idAppUser) else{
            return 0
        }
        guard let friends = user.friends?.allObjects as? [Friend] else { return 0}
        return friends.count
    }
    
    
    //Cancelle tutti gli amici di un utente
    func deleteFriends(_ idApp: String) {
        guard let user = findUserForIdApp(idApp), let friend = user.friends else { return }
        user.removeFromFriends(friend)
        do {
            try self.context.save()
        } catch let errore {
            print("[CDC] Errore cercando di eliminare un amico \(errore) \n")
        }
    }
    
    //cancella l'user
    func deleteUser(_ idApp: String) {
        guard let user = self.findUserForIdApp(idApp) else { return }
        
        self.context.delete(user)
    
        do {
            try self.context.save()
        } catch let errore {
            print("[CDC] Problema eliminazione user ")
            print("  Stampo l'errore: \n \(errore) \n")
        }
    
    }
}
