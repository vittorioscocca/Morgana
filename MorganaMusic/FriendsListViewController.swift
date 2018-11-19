//
//  FriendsListViewController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 03/05/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import UIKit
import FBSDKLoginKit

//User Facebook Friends List that use the app
class FriendsListViewController: UIViewController,UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

    @IBOutlet weak var myTable: UITableView!
    @IBOutlet weak var numAmici: UIBarButtonItem!
    @IBOutlet weak var myActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loading_label: UILabel!
    
    var segueFrom: String?
    var resultSearchController: UISearchController?
    
    var friendsList: [Friend]? = []
    var filteredList = [Friend]()
    var start = 0
    var end = 0
    var page:Int?, friendsForPage:Int?, lastPageFriends:Int?
    var currentPage = 0
    var numberOfFriends = 0
    var forwardOrder: Order?
   
    var user: User?
    var controller :UIAlertController?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.myTable.dataSource = self
        self.myTable.delegate = self
        
    
        resultSearchController = ({
            // creo un oggetto di tipo UISearchController
            let controller = UISearchController(searchResultsController: nil)
            // remove the  background tableView to show finded elements
            controller.dimsBackgroundDuringPresentation = false
            controller.searchResultsUpdater = self
            controller.searchBar.sizeToFit()
            
            // set searchBar to Table Header View
            self.myTable.tableHeaderView = controller.searchBar
            
            return controller
        })()
       
        myTable.addSubview(refreshControl1)
        friendsList = deleteForwardFriend(friendListPass: FacebookFriendsListManager.instance.readContactList().facebookFriendsList)
        guard let fbFriendsList = friendsList else { return }
        self.numAmici.title = String(fbFriendsList.count)
        
        NotificationCenter.default.addObserver(self,
                                       selector: #selector(FacebookFriendsListStateDidChange),
                                       name: .FacebookFriendsListStateDidChange,
                                       object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FacebookFriendsListStateDidChange()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @objc func FacebookFriendsListStateDidChange(){
        if case .loading = FacebookFriendsListManager.instance.state{
            myActivityIndicator.startAnimating()
            refreshControl1.beginRefreshing()
            myTable.isUserInteractionEnabled = false
            print("*-*- passato")
        } else {
            myActivityIndicator.stopAnimating()
            loading_label.isHidden = true
        }
        
        if case let .fatalError(error) = FacebookFriendsListManager.instance.state {
            generateAlert(error: error.error)
        }
        
        if case .success = FacebookFriendsListManager.instance.state{
            refreshControl1.endRefreshing()
            myTable.isUserInteractionEnabled = true
            friendsList = deleteForwardFriend(friendListPass: FacebookFriendsListManager.instance.readContactList().facebookFriendsList)
            guard let fbFriendsList = friendsList else { return }
            numAmici.title = String(fbFriendsList.count)
            myTable.reloadData()
        }
    }
    
    private func deleteForwardFriend(friendListPass: [Friend]?) -> [Friend]? {
        if let order = forwardOrder {
            return friendListPass?.filter({$0.idFB != order.userDestination?.idFB})
        }
        return friendListPass
    }
    
    func generateAlert(error: Error){
        controller = UIAlertController(title: "Impossibile caricare i contatti",
                                       message: error.localizedDescription,
                                       preferredStyle: .alert)
        let action = UIAlertAction(title: "CHIUDI", style: UIAlertActionStyle.default, handler:
        {(paramAction:UIAlertAction!) in
            
            print("Il messaggio di chiusura è stato premuto")
        })
        
        controller!.addAction(action)
        self.present(controller!, animated: true, completion: nil)
        
    }
    
    func contentsFilter(text: String) {
        filteredList.removeAll(keepingCapacity: true)
        guard let fbFriendsList = friendsList else { return }
        for friend in fbFriendsList {
            if friend.fullName?.localizedLowercase.range(of: text.localizedLowercase) != nil {
                filteredList.append(friend)
            }
            self.myTable.reloadData()
        }
    }
    
    func updateSearchResults(for: UISearchController){
        contentsFilter(text: (resultSearchController?.searchBar.text!)!)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let result = resultSearchController else {
            return 0
        }
        if result.isActive {
            return filteredList.count
        } else {
            guard let list = friendsList else { return 0 }
            return list.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let friend: Friend?
        // if searchBar is active, listafiltrata is source data
        if self.resultSearchController!.isActive {
            friend = filteredList[indexPath.row]
        } else {
            // search bar is no active,friendsListPaginated is data source
            friend = self.friendsList?[indexPath.row]
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "friendsCell", for: indexPath)
        
        (cell as! FirendsListTableViewCell).friendName.text = friend?.fullName
        (cell as! FirendsListTableViewCell).friendImageView.image = UIImage(named: "userDefault")
        (cell as! FirendsListTableViewCell).idFB = friend?.idFB
        (cell as! FirendsListTableViewCell).friendImageUrl = friend?.pictureUrl
        if friend?.cityOfRecidence != nil {
            (cell as! FirendsListTableViewCell).cityOfRecidence.text = friend?.cityOfRecidence
            (cell as! FirendsListTableViewCell).cityOfRecidence.isHidden = false
        } else {
            (cell as! FirendsListTableViewCell).cityOfRecidence.isHidden = true
        }
        
        if self.segueFrom == "myDrinks" {
            (cell as! FirendsListTableViewCell).forwardButton.isHidden = false
            (cell as! FirendsListTableViewCell).forwardButton.tag = indexPath.row
            (cell as! FirendsListTableViewCell).forwardButton.addTarget(self, action: #selector(forwardAction(_:)), for: .touchUpInside)
        } else {
            (cell as! FirendsListTableViewCell).forwardButton.isHidden = true
        }

        CacheImage.getImage(url: friend?.pictureUrl, onCompletion: { (image) in
            guard image != nil else {
                print("immagine utente non reperibile")
                return
            }
            DispatchQueue.main.async(execute: {
                if let cellToUpdate = tableView.cellForRow(at: indexPath) {
                    (cellToUpdate as! FirendsListTableViewCell).friendImageView.image = image
                }
            })
        })
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thisCell = tableView.cellForRow(at: indexPath)
        if self.segueFrom == "offerView" {
            performSegue(withIdentifier: "unwindToOfferfromListFriend", sender: thisCell)
        }
        
    }
    
    
    @objc func forwardAction(_ sender: UIButton!) {
        performSegue(withIdentifier: "unwindFromFriendsListToMyDrinks", sender: sender)
    }
    

    
    lazy var refreshControl1: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(FriendsListViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        refreshControl.beginRefreshing()
        myTable.isUserInteractionEnabled = false
        FacebookFriendsListManager.instance.refreshContactList()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
        switch identifier {
        case "unwindToOfferfromListFriend":
            guard let isSenderEmpty = sender else {
                return
            }
            let userDestination = UserDestination(nil,nil,nil,nil,nil)
            userDestination.fullName = (isSenderEmpty as! FirendsListTableViewCell).friendName.text
            userDestination.pictureUrl = (isSenderEmpty as! FirendsListTableViewCell).friendImageUrl
            userDestination.idFB = (isSenderEmpty as! FirendsListTableViewCell).idFB
            Order.sharedIstance.userDestination = userDestination
            break
        case "unwindFromFriendsListToMyDrinks":
            guard let isSenderEmpty = sender else {
                return
            }
            let friend = self.friendsList?[(isSenderEmpty as! UIButton).tag]
            let userDestination = UserDestination(friend?.fullName,friend?.idFB,friend?.pictureUrl,nil,nil)
            (segue.destination as! MyOrderViewController).forwardOrder?.userDestination = userDestination
            
            //Order.sharedIstance.userDestination = userDestination
            break
        default:
            break
        }
        
    }
    
    @IBAction func unwindToProfile(_ sender: UIBarButtonItem) {
        if self.segueFrom == "userView" {
            performSegue(withIdentifier: "unwindToProfile", sender: nil)
            
        }else if self.segueFrom == "offerView" {
            performSegue(withIdentifier: "unwindToOfferfromListFriendWithoutValue", sender: nil)
            
        }else if self.segueFrom == "myDrinks" {
            performSegue(withIdentifier: "unwidToMyDrinksWithoutValue", sender: nil)
        }
        
    }
    
}

    

