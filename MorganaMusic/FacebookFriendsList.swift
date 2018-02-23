//
//  FacebookFriendsList.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 22/02/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
import FBSDKLoginKit

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

    init(dispatchQueue: DispatchQueue, networkStatus: NetworkStatus, notificationCenter: NotificationCenter, uiApplication: UIApplication) {
        self.dispatchQueue = dispatchQueue
        self.networkStatus = networkStatus
        self.notificationCenter = notificationCenter
        self.uiApplication = uiApplication
        internalState = FacebookFriendsListManager.setInitialState(networkStatus: networkStatus)
        self.userId = fireBaseToken.object(forKey: "FireBaseToken")! as? String
        self.user = CoreDataController.sharedIstance.findUserForIdApp(userId)
        
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
        if let fbCredentials =  fbToken{
            return .startUp(fbCredentials)
        } else {
            return .stop(fbToken!, online: networkStatus.online)
        }
    }
    
    @objc private func networkStatusDidChange() {
        let online = networkStatus.online
        
        dispatchQueue.async {
            switch self.internalState {
            case let .stop(fbTokenString, _):
                if (self.fbTokenString != nil) && online {
                    print("fbTokenString is complete and network is online, starting up")
                    self.setInternalState(.startUp(fbTokenString))
                }
                else {
                    print("Credentials are incomplete or network is offline, won't start up")
                    self.setInternalState(.stop(fbTokenString,online: online))
                }
                
            case let .startUp(fbTokenString), let .error(fbTokenString, _, _):
                if !online {
                    print("Network offline, stopping")
                    self.setInternalState(.stop(fbTokenString, online: false))
                }
                else {
                    print("Network is now online, all processes restored ")
                }
                
            case let .success(fbTokenString, contactList, freshness, _):
                print("Network is online, network status updated")
                self.setInternalState(.success(fbTokenString, contactList, freshness, online: online))
            }
            print("Automatic refresh started, due to the switch to a different network connection")
            self.requestContactList(freshness: .localCache)
        }
    }
    
    @objc func applicationWillEnterForeground() {
        dispatchQueue.async {
            print("Application will enter foreground: automatic refresh started")
            self.requestContactList(freshness: .fresh)
        }
    }
    
    
    enum InternalError: Error {
        case unexpectedError(String)
        
        public var localizedDescription: String {
            get {
                switch self {
                case let .unexpectedError(description):
                    return "Unexpected error: \(description)"
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
                return "STOP"
            case .startUp:
                return "STARTUP"
            case .error:
                return "ERROR"
            case .success:
                return "SUCCESS"
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
        
        print("Internal state did change: \(oldState) -> \(newState)")
        internalState = newState
        
        dispatchQueue.async {
            print("Notifying state changed")
            self.notificationCenter.post(name: .FacebookFriendsListStateDidChange, object: self)
            if oldState.fbTokenString != newState.fbTokenString {
                print("Notifying data changed")
                self.notificationCenter.post(name: .FacebookFriendsListListDataDidChange, object: self)
            }
        }
    }
    
    private func requestContactList(freshness: ContactListFreshness) {
        switch internalState {
        case .stop:
            print("Request of contact list ignored in state: \(internalState)")
            
        case let .startUp(fbTokenString), let .error(fbTokenString, _, _), .success(let fbTokenString, _, _, true):
            connectToFacebook(freshness: freshness, completion: { (outcome) in
                switch self.internalState {
                case let .stop(newFbTokenString, _), let .startUp(newFbTokenString), let .error(newFbTokenString, _, _), let .success(newFbTokenString, _, _, _):
                     if newFbTokenString != fbTokenString {
                        print("Request of contact list ignored: detected new credentials")
                            if case .startUp = self.internalState {
                                print("Detected new credential in startup state: new request of server contact list started")
                                self.requestContactList(freshness: freshness)
                            }
                            return
                    }
                }
                
                switch outcome {
                case let .transitoryError(error):
                    switch self.internalState {
                    case .stop:
                        print("Request failed due to a transitory error: \(error)")
                        
                    case .error, .startUp,.success:
                        print("Request failed due to a transitory error: \(error)")
                        self.tryNewRequest(freshness: freshness)
                    }
                    
                case let .persistentError(errorCondition):
                    switch self.internalState {
                    case .stop, .success:
                        print("Request failed due to a persistent error: \(errorCondition.error)")
                        
                    case let .startUp(credentials):
                        print( "Initial request failed due to a persistent error: \(errorCondition.error)")
                        self.setInternalState(.error(credentials, errorCondition, freshness))
                        
                    case let .error(credentials, _, currentFreshness):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("Updating fatal error: \(errorCondition.error) ")
                            self.setInternalState(.error(credentials, errorCondition, freshness))
                        }
                    }
                    
                case let .success(fbFriendsList):
                    switch self.internalState {
                    case .stop:
                        print("Server contact list ignored in state \(self.internalState)")
                        
                    case let .startUp(fbTokenString), let .error(fbTokenString, _, _):
                        print("Initial contact list request was succes")
                        self.setInternalState(.success(fbTokenString, fbFriendsList, freshness, online: true))
                        
                    case let .success(credentials, _, currentFreshness, online):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("Contact list updated")
                            self.setInternalState(.success(credentials, fbFriendsList, freshness, online: online))
                        } else {
                            print("Server contact list ignored: current contact list was fresher")
                        }
                    }
                }
            })
            
        case .success(_, _, _, false):
            print("Request of contact list ignored due to lost network connection")
        }
    }
    
    private var pendingRequests = 0
    
    private func connectToFacebook(freshness: ContactListFreshness, completion: @escaping (RequestOutcome) -> ()) {
        if  case .localCache = freshness{
            if let fbFriendsList = CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: self.userId!){
                completion(.success(fbFriendsList))
            }
        }
        else if case .fresh = freshness {
            CoreDataController.sharedIstance.deleteFriends((self.user?.idApp)!)
            let parameters_friend = ["fields" : "name, first_name, last_name, id, email, gender, picture.type(large)"]
            
            FBSDKGraphRequest(graphPath: "me/friends", parameters: parameters_friend, tokenString: fbTokenString, version: nil, httpMethod: "GET").start(completionHandler: {(connection,result,error) -> Void in
                self.pendingRequests -= 1
                print("Pendig request with freshness level \(freshness), served!. Actual pending requests: \(self.pendingRequests)")
                if ((error) != nil) {
                    print("Error: \(error!)")
                    completion(.persistentError(.generalError(error!)))
                }
                //numbers of total friends
                let newResult = result as! NSDictionary
                let summary = newResult["summary"] as! NSDictionary
                let counts = summary["total_count"] as! NSNumber
                
                print("Totale amici letti:  \(counts)")
                var contFriends = 0
                
                //self.startActivityIndicator("Carico lista amici...")
                let dati: NSArray = newResult.object(forKey: "data") as! NSArray
                
                guard dati.count != 0 else {
                    completion(.persistentError(.generalError(error!)))
                    return
                }
                
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
                    
                    FirebaseData.sharedIstance.readUserIdAppFromIdFB(node: "users", child: "idFB", idFB: idFB, onCompletion: { (error,idApp) in
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        guard idApp != nil else {return}
                        FirebaseData.sharedIstance.readUserCityOfRecidenceFromIdFB(node: "users/\(idApp!)", onCompletion: { (error, cityOfRecidence) in
                            CoreDataController.sharedIstance.addFriendInUser(idAppUser: (self.user?.idApp)!, idFB: idFB, mail: self.user?.email, fullName: name, firstName: firstName, lastName: lastName, gender: nil, pictureUrl: url, cityOfRecidence: cityOfRecidence)
                            if i == (dati.count - 1) {
                                if let fbFriendsList = CoreDataController.sharedIstance.loadAllFriendsOfUser(idAppUser: self.userId!){
                                    completion(.success(fbFriendsList))
                                }
                            }
                        })
                    })
                    
                }
                print("Aggiornamento elenco amici di Facebook completato!. Inseriti \(contFriends) amici")
                
            })
            pendingRequests += 1
            print("New request with freshness level \(freshness). Actual pending requests: \(self.pendingRequests)")
    
            dispatchQueue.async {
                print("Server Contact List state did change")
                self.notificationCenter.post(name: .FacebookFriendsListStateDidChange, object: self)
            }
        }
    }
    
   
    
    private func tryNewRequest(freshness: ContactListFreshness) {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + FacebookFriendsListManager.requestRetryDelay , execute: {
            print("Trying a new request of Contact List afer 10 seconds")
            switch self.internalState {
            case .stop, .success(_, _, _, false):
                print("Reconnect to server request ingored: network connection or credentials error")
                break
            case .startUp, .error, .success(_, _, _, true):
                if self.uiApplication.applicationState == .active {
                    print("Automatic refresh of Contact List correctly aperformed afer 10 seconds")
                    self.requestContactList(freshness: freshness)
                }
                else {
                    print("Automatic refresh of Contact List won't be performed in background mode")
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
        print("Refresh requested")
        
        dispatchQueue.async {
            self.requestContactList(freshness: .fresh)
        }
    }
    
    public func readContactList()-> FacebookFriendsList {
        return FacebookFriendsList(contactList: internalState.facebookFriendsList)
    }
}
