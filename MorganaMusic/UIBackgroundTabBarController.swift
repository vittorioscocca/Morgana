//
//  UIBackgroundTabBarController.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 08/03/18.
//  Copyright © 2018 Vittorio Scocca. All rights reserved.
//

import UIKit

fileprivate extension UITabBarController {
    
    func indexOfItem(withTag tag: Int) -> Int? {
        return tabBar.items?.index(where: { $0.tag == tag })
    }
    
    func viewController(withTag tag: Int) -> UIViewController? {
        guard let index = indexOfItem(withTag: tag) else {
            return nil
        }
        
        guard let viewControllers = viewControllers else {
            return nil
        }
        
        return viewControllers[index]
    }
}

class UIBackgroundTabBarController: UITabBarController {
    // NOTE: keep the raw values in sync with the storyboard
    enum ViewControllerTags: Int {
        case order = 4
        case userPoints = 1
        case myOrder = 2
        case eventsViewController = 3
    }
    
    var orderViewController: UINavigationController! //OrderViewController!
    var userPointsViewController: UserPointsViewController!
    var myOrderViewController: UINavigationController! //MyOrderViewController!
    var eventsViewController:EventsViewController!
    var final = UserDefaults.standard
    var lastViewControllerOnQuick = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()

        orderViewController = viewController(withTag: ViewControllerTags.order.rawValue) as? UINavigationController
        userPointsViewController = viewController(withTag: ViewControllerTags.userPoints.rawValue) as? UserPointsViewController
        myOrderViewController = viewController(withTag: ViewControllerTags.myOrder.rawValue) as? UINavigationController
        eventsViewController = viewController(withTag: ViewControllerTags.eventsViewController.rawValue) as? EventsViewController
        
        NotificationCenter.default.addObserver(self, selector: #selector(setViewControllerForLetOrderShortCutNotification),
                                               name: .didOpenApplicationFromLetOrderShortCutNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setViewControllerForUserPointsShortCutNotification),
                                               name: .didOpenApplicationFromUserPointsShortCutNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setViewControllerMyOrderShortCutNotification),
                                               name: .didOpenApplicationFromMyOrderShortCutNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setViewControllerForEventsShortCutNotification),
                                               name: .didOpenApplicationFromEventsShortCutNotification,
                                               object: nil)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)

        guard final.object(forKey: "selectedViewController") != nil else {
            return
        }
        switch final.object(forKey: "selectedViewController") as! Int {
        case 0:
            final.set(nil, forKey: "selectedViewController")
            self.selectedViewController = orderViewController
        case 1:
            final.set(nil, forKey: "selectedViewController")
            self.selectedViewController = userPointsViewController
        case 2:
            final.set(nil, forKey: "selectedViewController")
            self.selectedViewController = myOrderViewController
        case 3:
            final.set(nil, forKey: "selectedViewController")
            self.selectedViewController = eventsViewController
        default:
            return
        }
    }
    
    override func viewDidLayoutSubviews() {
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        switch self.selectedIndex {
        case 0:
            lastViewControllerOnQuick.set(ViewControllerTags.order.rawValue, forKey: "lastViewControllerOnQuick")
            print("**** last tab item: Order")
        case 1:
            lastViewControllerOnQuick.set(ViewControllerTags.userPoints.rawValue, forKey: "lastViewControllerOnQuick")
            print("**** last tab item: user points")
        case 2:
            lastViewControllerOnQuick.set(ViewControllerTags.myOrder.rawValue, forKey: "lastViewControllerOnQuick")
            print("**** last tab item: my order")
        case 3:
            lastViewControllerOnQuick.set(ViewControllerTags.eventsViewController.rawValue, forKey: "lastViewControllerOnQuick")
            print("**** last tab item: events")
        default :
            break
        }
    }
    
    @objc func setViewControllerForLetOrderShortCutNotification(){
        final.set(ViewControllerTags.order.rawValue, forKey: "selectedViewController")
    }
    
    @objc func setViewControllerForUserPointsShortCutNotification(){
        final.set(ViewControllerTags.userPoints.rawValue, forKey: "selectedViewController")
    }
    
    @objc func setViewControllerMyOrderShortCutNotification(){
        
        final.set(ViewControllerTags.myOrder.rawValue, forKey: "selectedViewController")
    }
    
    @objc func setViewControllerForEventsShortCutNotification(){
        
        final.set(ViewControllerTags.eventsViewController.rawValue, forKey: "selectedViewController")
    }
}
