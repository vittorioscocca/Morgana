//
//  FacebookFriendsList.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/02/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
import FBSDKLoginKit
import CoreData

public extension NSNotification.Name {
    static let FacebookFriendsListStateDidChange = NSNotification.Name("FacebookFriendsListStateDidChangeNotification")
    static let FacebookFriendsListListDataDidChange = NSNotification.Name("FacebookFriendsListListDataDidChangeNotification")
}

class FacebookFriendsList {
    private let contactList: [Friend]
    
    var isEmpty: Bool {
        return contactList.isEmpty
    }
    
    fileprivate init(contactList: [Friend]){
        self.contactList = contactList
    }
    
    var facebookFriendsList :[Friend] {
        return contactList
    }
}

class FacebookFriendsListManager: NSObject {
    public static let instance = FacebookFriendsListManager(dispatchQueue: DispatchQueue.main,
                                                            networkStatus: NetworkStatus.default,
                                                            notificationCenter: NotificationCenter.default,
                                                            uiApplication: UIApplication.shared)
    
    private var dispatchQueue: DispatchQueue
    private var networkStatus: NetworkStatus
    private var notificationCenter: NotificationCenter
    private let uiApplication: UIApplication
    private static let requestRetryDelay: DispatchTimeInterval = DispatchTimeInterval.seconds(10)
    private let fbTokenString: String?
    private var userId: String?
    private let fireBaseToken = UserDefaults.standard
    private let user: User?
    private var context: NSManagedObjectContext

    init(dispatchQueue: DispatchQueue, networkStatus: NetworkStatus, notificationCenter: NotificationCenter, uiApplication: UIApplication) {
        self.dispatchQueue = dispatchQueue
        self.networkStatus = networkStatus
        self.notificationCenter = notificationCenter
        self.uiApplication = uiApplication
        internalState = FacebookFriendsListManager.setInitialState(networkStatus: networkStatus)
        self.userId = fireBaseToken.object(forKey: "FireBaseToken") as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(userId)
        let application = uiApplication.delegate as! AppDelegate
        self.context = application.persistentContainer.viewContext
        
        fbTokenString = UserDefaults.standard.object(forKey: "FBToken") as? String
        super.init()
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(networkStatusDidChange),
                                            name: .NetworkStatusDidChange,
                                            object: self.networkStatus)

        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationWillEnterForeground),
                                            name: .UIApplicationWillEnterForeground,
                                            object: uiApplication)
        
        requestContactList(freshness: .fresh)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    private static func setInitialState(networkStatus: NetworkStatus) -> InternalState {
        let fbToken = UserDefaults.standard.object(forKey: "FBToken") as? String
        if let fbCredentials = fbToken, networkStatus.online{
            return .startUp(fbCredentials)
        } else {
            return .stop("", online: networkStatus.online)
        }
    }
    
    @objc private func networkStatusDidChange() {
        let online = networkStatus.online
        
        dispatchQueue.async {
            switch self.internalState {
            case let .stop(fbTokenString, _):
                if (self.fbTokenString != nil) && online {
                    print("[FBFriendsListManager]: fbTokenString is complete and network is online, starting up")
                    self.setInternalState(.startUp(fbTokenString))
                }
                else {
                    print("[FBFriendsListManager]: Credentials are incomplete or network is offline, won't start up")
                    self.setInternalState(.stop(fbTokenString,online: online))
                }
                
            case let .startUp(fbTokenString), let .error(fbTokenString, _, _):
                if !online {
                    print("[FBFriendsListManager]: Network offline, stopping")
                    self.setInternalState(.stop(fbTokenString, online: false))
                }
                else {
                    print("[FBFriendsListManager]: Network is now online, all processes restored ")
                }
                
            case let .success(fbTokenString, contactList, freshness, _):
                print("[FBFriendsListManager]: Network is online, network status updated")
                self.setInternalState(.success(fbTokenString, contactList, freshness, online: online))
            }
            print("[FBFriendsListManager]: Automatic refresh started, due to the switch to a different network connection")
            self.requestContactList(freshness: .localCache)
        }
    }
    
    @objc func applicationWillEnterForeground() {
        dispatchQueue.async {
            print("[FBFriendsListManager]: Application will enter foreground: automatic refresh started")
            self.requestContactList(freshness: .fresh)
        }
    }
    
    
    enum InternalError: Error {
        case unexpectedError(String)
        
        public var localizedDescription: String {
            get {
                switch self {
                case let .unexpectedError(description):
                    return "[FBFriendsListManager]: Unexpected error: \(description)"
                }
            }
        }
    }
    
    enum ErrorCondition {
        case networkInterference(Error)
        case securityError(Error)
        case generalError(Error)
        
        public var error: Error {
            get {
                switch self {
                case let .networkInterference(error), let .securityError(error), let .generalError(error):
                    return error
                }
            }
        }
    }
    
    enum RequestOutcome {
        case transitoryError(Error)
        case persistentError(ErrorCondition)
        case success([Friend])
    }
    
    enum ContactListFreshness: Int {
        case localCache = 0
        case fresh
    }
    
    enum InternalState: CustomStringConvertible {
        case stop(String, online: Bool)
        case startUp(String)
        case error(String, ErrorCondition, ContactListFreshness)
        case success(String, [Friend], ContactListFreshness, online: Bool)
        
        var description: String {
            switch self {
            case .stop:
                return "[FBFriendsListManager]: STOP"
            case .startUp:
                return "[FBFriendsListManager]: STARTUP"
            case .error:
                return "[FBFriendsListManager]: ERROR"
            case .success:
                return "[FBFriendsListManager]: SUCCESS"
            }
        }
        
        var facebookFriendsList: [Friend] {
            switch self {
            case let .success(_, fbFriendsList, _, online: _):
                return fbFriendsList
            case .stop, .startUp, .error:
                return []
            }
        }
        
        var fbTokenString: String {
            switch self {
            case let .stop(fbTokenString, _), let .startUp(fbTokenString), let .error(fbTokenString, _, _), let .success(fbTokenString, _, _, _):
                return fbTokenString
            }
        }
    }
    
    private var internalState: InternalState
    
    private func setInternalState(_ newState: InternalState) {
        let oldState = internalState
        
        print("[FBFriendsListManager]: Internal state did change: \(oldState) -> \(newState)")
        internalState = newState
        
        dispatchQueue.async {
            print("[FBFriendsListManager]: Notifying state changed")
            self.notificationCenter.post(name: .FacebookFriendsListStateDidChange, object: self)
            if oldState.fbTokenString != newState.fbTokenString {
                print("[FBFriendsListManager]: Notifying data changed")
                self.notificationCenter.post(name: .FacebookFriendsListListDataDidChange, object: self)
            }
        }
    }
    
    private func requestContactList(freshness: ContactListFreshness) {
        switch internalState {
        case .stop:
            print("[FBFriendsListManager]: Request of contact list ignored in state: \(internalState)")
            
        case let .startUp(fbTokenString), let .error(fbTokenString, _, _), .success(let fbTokenString, _, _, true):
            connectToFacebook(freshness: freshness, completion: { (outcome) in
                switch self.internalState {
                case let .stop(newFbTokenString, _), let .startUp(newFbTokenString), let .error(newFbTokenString, _, _), let .success(newFbTokenString, _, _, _):
                     if newFbTokenString != fbTokenString {
                        print("[FBFriendsListManager]: Request of contact list ignored: detected new credentials")
                            if case .startUp = self.internalState {
                                print("[FBFriendsListManager]: Detected new facebook credential in startup state: new request of facebook friends list started")
                                self.requestContactList(freshness: freshness)
                            }
                            return
                    }
                }
                
                switch outcome {
                case let .transitoryError(error):
                    switch self.internalState {
                    case .stop:
                        print("[FBFriendsListManager]: Request failed due to a transitory error: \(error)")
                        
                    case .error, .startUp,.success:
                        print("[FBFriendsListManager]: Request failed due to a transitory error: \(error)")
                        self.tryNewRequest(freshness: freshness)
                    }
                    
                case let .persistentError(errorCondition):
                    switch self.internalState {
                    case .stop, .success:
                        print("[FBFriendsListManager]: Request failed due to a persistent error: \(errorCondition.error)")
                        
                    case let .startUp(credentials):
                        print( "[FBFriendsListManager]: Initial request failed due to a persistent error: \(errorCondition.error)")
                        self.setInternalState(.error(credentials, errorCondition, freshness))
                        
                    case let .error(credentials, _, currentFreshness):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("[FBFriendsListManager]: Updating fatal error: \(errorCondition.error) ")
                            self.setInternalState(.error(credentials, errorCondition, freshness))
                        }
                    }
                    
                case let .success(fbFriendsList):
                    switch self.internalState {
                    case .stop:
                        print("[FBFriendsListManager]: Facebook friends list ignored in state \(self.internalState)")
                        
                    case let .startUp(fbTokenString), let .error(fbTokenString, _, _):
                        print("[FBFriendsListManager]: Initial contact list request was succes")
                        self.setInternalState(.success(fbTokenString, fbFriendsList, freshness, online: true))
                        
                    case let .success(credentials, _, currentFreshness, online):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("[FBFriendsListManager]: Contact list updated")
                            self.setInternalState(.success(credentials, fbFriendsList, freshness, online: online))
                        } else {
                            print("[FBFriendsListManager]: Facebook friends list ignored: current contact list was fresher")
                        }
                    }
                }
            })
            
        case .success(_, _, _, false):
            print("[FBFriendsListManager]: Request of contact list ignored due to lost network connection")
        }
    }
    
    private var pendingRequests = 0
    
    private func connectToFacebook(freshness: ContactListFreshness, completion: @escaping (RequestOutcome) -> ()) {
        if  case .localCache = freshness{
            CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: (self.user?.idApp)!, completion: { (list) in
                if let fbFriendsList = list {
                    completion(.success(fbFriendsList))
                }else {
                    //completion(.transitoryError(Error))
                }
            })
        }
        else if case .fresh = freshness {
            CoreDataController.sharedIstance.deleteFriends((self.user?.idApp)!)
            let parameters_friend = ["fields" : "name, first_name, last_name, id, email, gender, picture.type(large)"]
            
            FBSDKGraphRequest(graphPath: "me/friends", parameters: parameters_friend, tokenString: fbTokenString, version: nil, httpMethod: "GET").start(completionHandler: {(connection,result,error) -> Void in
                self.pendingRequests -= 1
                print("[FBFriendsListManager]: Pendig request with freshness level \(freshness), served!. Actual pending requests: \(self.pendingRequests)")
                
                self.dispatchQueue.async {
                    print("[FBFriendsListManager]: Facebook friends List state did change")
                    self.notificationCenter.post(name: .FacebookFriendsListStateDidChange, object: self)
                }
                
                if ((error) != nil) {
                    print("[FBFriendsListManager]: Error: \(error!)")
                    completion(.persistentError(.generalError(error!)))
                }
                guard result != nil else {
                    print("[FBFriendsListManager]: Error: \(error!)")
                    completion(.persistentError(.generalError(error!)))
                    return
                }
                //numbers of total friends
                let newResult = result as! NSDictionary
                let summary = newResult["summary"] as! NSDictionary
                let counts = summary["total_count"] as! NSNumber
                
                print("[FBFriendsListManager]: Totale amici letti:  \(counts)")
                var contFriends = 0
                
                //self.startActivityIndicator("Carico lista amici...")
                let dati: NSArray = newResult.object(forKey: "data") as! NSArray
                
                guard dati.count != 0 else {
                    completion(.persistentError(.generalError(error!)))
                    return
                }
                var fbList = [Friend]()
                
                for i in 0...(dati.count - 1) {
                    contFriends += 1
                    let valueDict: NSDictionary = dati[i] as! NSDictionary
                    let name = valueDict["name"] as? String
                    let idFB = valueDict["id"] as! String
                    let firstName = valueDict["first_name"] as! String
                    let lastName = valueDict["last_name"] as! String
                    
                    //let gender = valueDict["gender"] as! String
                    let picture = valueDict["picture"] as! NSDictionary
                    let data = picture["data"] as? NSDictionary
                    let url = data?["url"] as? String
            
                    FirebaseData.sharedIstance.readNodeFromIdFB(node: "users", child: "idFB", idFB: idFB, onCompletion: { (error,dictionary) in
                        guard error == nil else {
                            print(error!)
                            //completion(.transitoryError(Error))
                            return
                        }
                        guard dictionary != nil else {
                            print("[FBFriendsListManager]: Errore di lettura del dell'Ordine richiesto")
                            //completion(.transitoryError(Error))
                            return
                        }
                        var cityOfRecidence: String = ""
                        
                        for (key,value) in dictionary! {
                            if key == "idApp" {
                                cityOfRecidence = value as! String
                            }
                        }
                        
                        CoreDataController.sharedIstance.addFriendInUser(idAppUser: (self.user?.idApp)!, idFB: idFB, mail: self.user?.email, fullName: name, firstName: firstName, lastName: lastName, gender: nil, pictureUrl: url, cityOfRecidence: cityOfRecidence)
                        
                        let entityFriend = NSEntityDescription.entity(forEntityName: "Friend", in: self.context)
                        let newFriend = Friend(entity: entityFriend!, insertInto: self.context)
                        
                        newFriend.user = self.user
                        
                        newFriend.idFB = idFB
                        newFriend.fullName = name
                        newFriend.firstName = firstName
                        newFriend.lastName = lastName
                        newFriend.gender = nil
                        newFriend.pictureUrl = url
                        newFriend.cityOfRecidence = cityOfRecidence
                        
                        fbList.append(newFriend)
                        if i == (dati.count - 1) {
                            print("[FBFriendsListManager]: DIMENSIONE FRIENDSLIST \(fbList.count)")
                            completion(.success(fbList))
                        }
                    })
                }
                print("[FBFriendsListManager]: Aggiornamento elenco amici di Facebook completato!. Inseriti \(contFriends) amici")
                
            })
            pendingRequests += 1
            print("[FBFriendsListManager]: New request with freshness level \(freshness). Actual pending requests: \(self.pendingRequests)")
    
            dispatchQueue.async {
                print("[FBFriendsListManager]: Facebook friends List state did change")
                self.notificationCenter.post(name: .FacebookFriendsListStateDidChange, object: self)
            }
        }
    }
    
    private func tryNewRequest(freshness: ContactListFreshness) {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + FacebookFriendsListManager.requestRetryDelay , execute: {
            print("[FBFriendsListManager]: Trying a new request of Contact List afer 10 seconds")
            switch self.internalState {
            case .stop, .success(_, _, _, false):
                print("[FBFriendsListManager]: Reconnect to facebook request ingored: network connection or credentials error")
                break
            case .startUp, .error, .success(_, _, _, true):
                if self.uiApplication.applicationState == .active {
                    print("[FBFriendsListManager]: Automatic refresh of Contact List correctly aperformed afer 10 seconds")
                    self.requestContactList(freshness: freshness)
                }
                else {
                    print("[FBFriendsListManager]: Automatic refresh of Contact List won't be performed in background mode")
                }
            }
        })
    }
    
    // MARK: Public API
    public enum State {
        case success
        case fatalError(ErrorCondition)
        case noCredentials
        case loading
    }
    
    public var state: State {
        get {
            switch internalState{
            case .stop:
                return .loading
            case .startUp:
                return .loading
            case let .error(_, error, _):
                return .fatalError(error)
            case .success:
                return .success
            }
        }
    }
    
    public var requestInProgress: Bool {
        get {
            return pendingRequests != 0
        }
    }
    
    public func refreshContactList(){
        print("[FBFriendsListManager]: Refresh requested")
        
        dispatchQueue.async {
            self.requestContactList(freshness: .fresh)
        }
    }
    
    public func readContactList()-> FacebookFriendsList {
        return FacebookFriendsList(contactList: internalState.facebookFriendsList)
    }
}

