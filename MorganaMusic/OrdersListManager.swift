//
//  OrdersListManager.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 07/03/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import Foundation
import Firebase
import FBSDKLoginKit

public extension NSNotification.Name {
    static let OrdersListStateDidChange = NSNotification.Name("OrdersListStateDidChangeNotification")
    static let OrdersListDataDidChange = NSNotification.Name("OrdersListDataDidChangeNotification")
}

class OrdersList {
    private let ordersSentList: [Order]
    private let ordersReceivedList: [Order]
    
    var isEmpty: Bool {
        return ordersSentList.isEmpty && ordersReceivedList.isEmpty
    }
    
    fileprivate init(ordersSentList: [Order], ordersReceivedList: [Order]){
        self.ordersSentList = ordersSentList
        self.ordersReceivedList = ordersReceivedList
    }
    
    var ordersList :(ordersSentList:[Order],ordersReceivedList:[Order]) {
        return (ordersSentList,ordersReceivedList)
    }
}

class OrdersListManager: NSObject {
    public static let instance = OrdersListManager(dispatchQueue: DispatchQueue.main,
                                                   networkStatus: NetworkStatus.default,
                                                   notificationCenter: NotificationCenter.default,
                                                   uiApplication: UIApplication.shared,
                                                   facebookFriendsListManager: FacebookFriendsListManager.instance)
    
    private var dispatchQueue: DispatchQueue
    private var networkStatus: NetworkStatus
    private var notificationCenter: NotificationCenter
    private let uiApplication: UIApplication
    private let facebookFriendsListManager: FacebookFriendsListManager
    private static let requestRetryDelay: DispatchTimeInterval = DispatchTimeInterval.seconds(10)
    private var user: User?
    private var friendsList: [Friend]
    
    init(dispatchQueue: DispatchQueue, networkStatus: NetworkStatus, notificationCenter: NotificationCenter, uiApplication: UIApplication, facebookFriendsListManager: FacebookFriendsListManager) {
        self.dispatchQueue = dispatchQueue
        self.networkStatus = networkStatus
        self.notificationCenter = notificationCenter
        self.uiApplication = uiApplication
        self.facebookFriendsListManager = facebookFriendsListManager
        self.friendsList = facebookFriendsListManager.readContactList().facebookFriendsList
        internalState = OrdersListManager.setInitialState(friendslist: friendsList,networkStatus: networkStatus)
        self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
        
        super.init()
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(networkStatusDidChange),
                                            name: .NetworkStatusDidChange,
                                            object: self.networkStatus)
        
        
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationWillEnterForeground),
                                            name: .UIApplicationWillEnterForeground,
                                            object: uiApplication)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(FacebookFriendsListStateDidChange),
                                               name: .FacebookFriendsListStateDidChange,
                                               object: nil)
        
        requestOrdersList(freshness: .fresh)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    private static func setInitialState(friendslist: [Friend], networkStatus: NetworkStatus) -> InternalState {
        
        if !friendslist.isEmpty && networkStatus.online{
            return .startUp(friendslist)
        }
        return .stop(friendslist, online: networkStatus.online)
    }
    
    // MARK: Internal
    @objc private func FacebookFriendsListStateDidChange(){
        let newFriendsList = facebookFriendsListManager.readContactList().facebookFriendsList
        
        dispatchQueue.async {
            switch self.internalState {
            case let .stop(_, online):
                if !newFriendsList.isEmpty && online {
                    print("[OrdersListManager]: Facebbok Friends List is complete and network is online, starting up")
                    self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
                    self.setInternalState(.startUp(newFriendsList))
                }
                else {
                    print("[OrdersListManager]: Facebbok Friends List is incomplete or network is offline, won't start up")
                    self.setInternalState(.stop(newFriendsList,online: online))
                }
                
            case .startUp:
                if newFriendsList.isEmpty {
                    print("[OrdersListManager]: Facebbok Friends List is incomplete, stopping")
                    self.setInternalState(.stop(newFriendsList, online: true))
                }
                else {
                    print("[OrdersListManager]: Facebbok Friends List is complete, starting up")
                    self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
                    self.setInternalState(.startUp(newFriendsList))
                }
                
            case let .error(_, errorCondition, freshness):
                if newFriendsList.isEmpty {
                    print("[OrdersListManager]: Facebbok Friends List is incomplete, stopping")
                    self.setInternalState(.stop(newFriendsList, online: true))
                }
                else {
                    print("[OrdersListManager]: Facebbok Friends List is complete, update credentials")
                    self.setInternalState(.error(newFriendsList, errorCondition, freshness))
                }
                
            case let .success(friendsList, _, _, _, online):
                if newFriendsList.isEmpty {
                    print("[OrdersListManager]: Facebbok Friends List is incomplete, stopping")
                    self.setInternalState(.stop(friendsList, online: online))
                }
                else if newFriendsList != friendsList {
                    if online {
                        print("[OrdersListManager]: New Friends List detected, starting up with new credentials")
                        self.user = CoreDataController.sharedIstance.findUserForIdApp(Auth.auth().currentUser?.uid)
                        self.setInternalState(.startUp(newFriendsList))
                    }
                    else {
                        print("[OrdersListManager]: Network is offline, stopping")
                        self.setInternalState(.stop(newFriendsList, online: online))
                    }
                }
            }
            print("[OrdersListManager]:Order request started due to Facebook Friends List updated")
            self.requestOrdersList(freshness: .fresh)
        }
    }
    
    @objc private func networkStatusDidChange() {
        let online = networkStatus.online
        
        dispatchQueue.async {
            switch self.internalState {
            case let .stop(friendsList, _):
                if !friendsList.isEmpty && online {
                    print("[OrdersListManager]: Facebook Friends List is complete and network is online, starting up")
                    self.setInternalState(.startUp(friendsList))
                }
                else {
                    print("[OrdersListManager]: Facebook Friends List is incomplete or network is offline, won't start up")
                    self.setInternalState(.stop(friendsList,online: online))
                }
                
            case let .startUp(friendsList), let .error(friendsList, _, _):
                if !online {
                    print("[OrdersListManager]: Network offline, stopping")
                    self.setInternalState(.stop(friendsList, online: false))
                }
                else {
                    print("[OrdersListManager]: Network is now online, all processes restored ")
                }
                
            case let .success(friendsList, ordersSentList, ordersReceivedList, freshness, _):
                print("[OrdersListManager]: Network is online, network status updated")
                self.setInternalState(.success(friendsList, ordersSentList, ordersReceivedList, freshness, online: online))
            }
            print("[OrdersListManager]: Automatic refresh started, due to the switch to a different network connection")
            self.requestOrdersList(freshness: .localCache)
        }
    }
    
    @objc func applicationWillEnterForeground() {
        guard Auth.auth().currentUser != nil else {
            return
        }
        dispatchQueue.async {
            print("[OrdersListManager]: Application will enter foreground: automatic refresh started")
            self.requestOrdersList(freshness: .fresh)
        }
    }
    
    enum InternalError: Error {
        case unexpectedError(String)
        
        public var localizedDescription: String {
            get {
                switch self {
                case let .unexpectedError(description):
                    return "[OrdersListManager]:  Unexpected error: \(description)"
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
        case success([Order],[Order])
    }
    
    enum ContactListFreshness: Int {
        case localCache = 0
        case fresh
    }
    
    enum InternalState: CustomStringConvertible {
        case stop([Friend], online: Bool)
        case startUp([Friend])
        case error([Friend],ErrorCondition, ContactListFreshness)
        case success([Friend], [Order], [Order], ContactListFreshness, online: Bool)
        
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
        
        var ordersList: (ordersSentList: [Order],ordersReceivedList: [Order]) {
            switch self {
            case let .success(_, ordersSentList, ordersReceivedList, _, online: _):
                return (ordersSentList,ordersReceivedList)
            case .stop, .startUp, .error:
                return ([],[])
            }
        }
        
        var friendsList: [Friend] {
            switch self {
            case let .stop(friendsList, _), let .startUp(friendsList), let .error(friendsList, _, _), let .success(friendsList, _, _, _, _):
                return friendsList
            }
        }
    }
    
    private var internalState: InternalState
    
    private func setInternalState(_ newState: InternalState) {
        let oldState = internalState
        
        print("[OrdersListManager]: Internal state did change: \(oldState) -> \(newState)")
        internalState = newState
        
        dispatchQueue.async {
            print("[OrdersListManager]: Notifying state changed")
            
            if oldState.friendsList != newState.friendsList {
                self.notificationCenter.post(name: .OrdersListStateDidChange, object: self)
                print("[OrdersListManager]: Notifying data changed")
                self.notificationCenter.post(name: .OrdersListDataDidChange, object: self)
            }
            
        }
    }
    
    private func requestOrdersList(freshness: ContactListFreshness) {
        switch internalState {
        case .stop:
            print("[OrdersListManager]: Request of contact list ignored in state: \(internalState)")
            
        case let .startUp(friendsList), let .error(friendsList, _, _), .success(let friendsList, _, _, _, true):
            guard pendingRequests == 0 else {
                print("[OrdersListManager]:order request ignored due to another pending request")
                return
            }
            connectToFirebase(freshness: freshness, currentFriendsList: friendsList, completion: { (outcome) in
                switch self.internalState {
                case let .stop(newFriendsList, _), let .startUp(newFriendsList), let .error(newFriendsList, _, _), let .success(newFriendsList, _, _, _, _):
                    if newFriendsList != friendsList {
                        print("[OrdersListManager]: Request of contact list ignored: detected new friends list")
                        if case .startUp = self.internalState {
                            print("[OrdersListManager]: Detected new friends list in startup state: new request of orders list started")
                            self.requestOrdersList(freshness: freshness)
                        }
                        return
                    }
                }
                
                switch outcome {
                case let .transitoryError(error):
                    switch self.internalState {
                    case .stop:
                        print("[OrdersListManager]: Request failed due to a transitory error: \(error)")
                        
                    case .error, .startUp,.success:
                        print("[OrdersListManager]: Request failed due to a transitory error: \(error)")
                        self.tryNewRequest(freshness: freshness)
                    }
                    
                case let .persistentError(errorCondition):
                    switch self.internalState {
                    case .stop, .success:
                        print("[OrdersListManager]: Request failed due to a persistent error: \(errorCondition.error)")
                        
                    case let .startUp(friendsList):
                        print("[OrdersListManager]: Initial request failed due to a persistent error: \(errorCondition.error)")
                        self.setInternalState(.error(friendsList, errorCondition, freshness))
                        
                    case let .error(friendsList, _, currentFreshness):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("[OrdersListManager]: Updating fatal error: \(errorCondition.error) ")
                            self.setInternalState(.error(friendsList, errorCondition, freshness))
                        }
                    }
                    
                case let .success(ordersSentList, orderReceivedList):
                    switch self.internalState {
                    case .stop:
                        print("[OrdersListManager]: Server orders list ignored in state \(self.internalState)")
                        
                    case let .startUp(friendsList), let .error(friendsList, _, _):
                        print("[OrdersListManager]: Initial orders list request was succes")
                        self.setInternalState(.success(friendsList, ordersSentList, orderReceivedList, freshness, online: true))
                        
                    case let .success(friendsList, _, _, currentFreshness, online):
                        if freshness.rawValue >= currentFreshness.rawValue {
                            print("[OrdersListManager]: Contact list updated")
                            self.setInternalState(.success(friendsList, ordersSentList, orderReceivedList, freshness, online: online))
                        } else {
                            print("[OrdersListManager]: Server contact list ignored: current contact list was fresher")
                        }
                    }
                }
            })
            
        case .success(_, _, _, _, false):
            print("[OrdersListManager]: Request of contact list ignored due to lost network connection")
        }
    }
    
    private var pendingRequests = 0
    
    private func connectToFirebase(freshness: ContactListFreshness, currentFriendsList: [Friend], completion: @escaping (RequestOutcome) -> ()) {
        if  case .localCache = freshness{
            switch internalState{
            case let .success(_, ordersSentList,ordersReceivedList,_ ,_):
                completion(.success(ordersSentList,ordersReceivedList))
            case .error, .stop, .startUp:
                completion(.success([], []))
            }
        }
        else if case .fresh = freshness {
            guard let currentUser = self.user else {
                //completion(.persistentError(OrdersListManager.ErrorCondition.generalError("errore")))
                return
            }
            pendingRequests += 1
            print("[OrdersListManager]: New request with freshness level \(freshness). Actual pending requests: \(self.pendingRequests)")
            
            FirebaseData.sharedIstance.readOrdersSentOnFireBase(user: currentUser, friendsList: currentFriendsList, onCompletion: { (ordersSent)  in
                FirebaseData.sharedIstance.readOrderReceivedOnFireBase(user: currentUser, onCompletion: { (ordersReceived) in
                    if self.pendingRequests > 0 {
                        self.pendingRequests -= 1
                        print("[OrdersListManager]: Pendig request with freshness level \(freshness), served!. Actual pending requests: \(self.pendingRequests)")
                    }
                    
                    self.dispatchQueue.async {
                        print("[OrdersListManager]: Order List state did change")
                        self.notificationCenter.post(name: .OrdersListStateDidChange, object: self)
                    }
                    completion(.success(ordersSent, ordersReceived))
                })
            })
        }
    }
    
    private func tryNewRequest(freshness: ContactListFreshness) {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + OrdersListManager.requestRetryDelay , execute: {
            print("[OrdersListManager]: Trying a new request of Contact List afer 10 seconds")
            switch self.internalState {
            case .stop, .success(_, _, _, _, false):
                print("[OrdersListManager]: Reconnect to server request ingored: network connection or credentials error")
                break
            case .startUp, .error, .success(_, _, _, _, true):
                if self.uiApplication.applicationState == .active {
                    print("[OrdersListManager]: Automatic refresh of Contact List correctly aperformed afer 10 seconds")
                    self.requestOrdersList(freshness: freshness)
                }
                else {
                    print("[OrdersListManager]: Automatic refresh of Contact List won't be performed in background mode")
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
                return  .loading
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
    
    public func refreshOrdersList(){
        print("[OrdersListManager]: Refresh requested")
        
        dispatchQueue.async {
            self.requestOrdersList(freshness: .fresh)
        }
    }
    
    public func readOrdersList()-> OrdersList {
        return OrdersList(ordersSentList: internalState.ordersList.ordersSentList,
                          ordersReceivedList: internalState.ordersList.ordersReceivedList)
    }
}
