//
//  NetworkStatus.swift
//  PYN
//
//  Created by a on 11/04/2017.
//  Copyright © 2017 Pynlab. All rights reserved.
//

import Foundation
import SystemConfiguration

public extension NSNotification.Name {
    static let NetworkStatusWillChange = NSNotification.Name("NetworkStatusWillChangeNotification")
    static let NetworkStatusDidChange = NSNotification.Name("NetworkStatusDidChangeNotification")
}

private extension SCNetworkReachabilityFlags
{
    var online: Bool {
        get {
            return contains(.reachable) && !contains(.connectionRequired)
        }
    }
    
    var mobile: Bool {
        get {
            return contains(.isWWAN)
        }
    }
    
    var onDemand: Bool {
        get {
            return contains([.connectionRequired, .connectionOnDemand])
        }
    }
    
    private static let flagNames: [(key: SCNetworkReachabilityFlags, value: String)] =
        [(.transientConnection, "T"),
         (.reachable, "R"),
         (.connectionRequired, "C"),
         (.connectionOnTraffic, "A"),
         (.interventionRequired, "U"),
         (.connectionOnDemand, "D"),
         (.isLocalAddress, "l"),
         (.isDirect, "d"),
         (.isWWAN, "w")]
    
    var description: String {
        get {
            var string = ""
            
            for flag in SCNetworkReachabilityFlags.flagNames {
                if contains(flag.key) {
                    string += flag.value
                }
                else {
                    string += "-"
                }
            }
            
            return string
        }
    }
}

public class NetworkStatus : NSObject
{
    @objc
    public static let `default` = NetworkStatus(runLoop: RunLoop.main,
                                                notificationCenter: NotificationCenter.default)
    
    
    private let runLoop: RunLoop
    private let notificationCenter: NotificationCenter
    private let reachability: SCNetworkReachability?
    
    private var _versionStamp: UInt64 = 0
    private var _reachabilityFlags: SCNetworkReachabilityFlags = []
    
    private class Callback
    {
        private weak var service: NetworkStatus?
        
        init(service: NetworkStatus) {
            self.service = service
        }
        
        public func reachabilityDidChange(flags: SCNetworkReachabilityFlags) {
            service?.reachabilityDidChange(flags: flags)
        }
    }
    
    public init(runLoop: RunLoop, notificationCenter: NotificationCenter) {
        
        self.runLoop = runLoop
        self.notificationCenter = notificationCenter
        
        var nullAddress = sockaddr_in()
        
        nullAddress.sin_len = UInt8(exactly: MemoryLayout.stride(ofValue: nullAddress))!
        nullAddress.sin_family = sa_family_t(exactly: AF_INET)!
        
        reachability = withUnsafePointer(to: &nullAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
        super.init()
        
        if reachability != nil {
            let callback = Callback(service: self)
            
            var context = SCNetworkReachabilityContext(version: 0,
                                                       info: Unmanaged.passUnretained(callback).toOpaque(),
                                                       retain: { return UnsafeRawPointer(Unmanaged<Callback>.fromOpaque($0).retain().toOpaque()) },
                                                       release: {
                                                        Unmanaged<Callback>.fromOpaque($0).release() },
                                                       copyDescription: nil)
            
            if !SCNetworkReachabilitySetCallback(reachability!, { (_, flags: SCNetworkReachabilityFlags, context: UnsafeMutableRawPointer?) in
                let object = Unmanaged<Callback>.fromOpaque(context!).takeUnretainedValue()
                object.reachabilityDidChange(flags: flags)
            }, &context) {
                print("SCNetworkReachabilitySetCallback failed, reachability updates will be unavailable")
            }
            else if !SCNetworkReachabilityScheduleWithRunLoop(reachability!, self.runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue) {
                print("SCNetworkReachabilityScheduleWithRunLoop failed, reachability updates will be unavailable")
            }
            
            if !SCNetworkReachabilityGetFlags(reachability!, &_reachabilityFlags) {
                print("SCNetworkReachabilityGetFlags failed, initial reachability unknown")
            }
        }
        
        logReachability(flags: _reachabilityFlags)
    }
    
    deinit {
        if reachability != nil {
            if !SCNetworkReachabilityUnscheduleFromRunLoop(reachability!, self.runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue) {
                print("SCNetworkReachabilityUnscheduleFromRunLoop failed")
            }
        }
    }
    
    private func reachabilityDidChange(flags: SCNetworkReachabilityFlags) {
        assert(RunLoop.current == runLoop)
        
        notificationCenter.post(name: .NetworkStatusWillChange, object: self)
        
        objc_sync_enter(self)
        _versionStamp += 1
        _reachabilityFlags = flags
        objc_sync_exit(self)
        
        notificationCenter.post(name: .NetworkStatusDidChange, object: self)
        
        logReachability(flags: flags)
    }
    
    @objc
    public var versionStamp: UInt64 {
        get {
            objc_sync_enter(self)
            
            defer {
                objc_sync_exit(self)
            }
            
            return _versionStamp
        }
    }
    
    private var reachabilityFlags: SCNetworkReachabilityFlags {
        get {
            objc_sync_enter(self)
            
            defer {
                objc_sync_exit(self)
            }
            
            return _reachabilityFlags
        }
    }
    
    @objc
    public var online: Bool {
        get {
            return reachabilityFlags.online
        }
    }
    
    @objc
    public var mobile: Bool {
        get {
            return reachabilityFlags.mobile
        }
    }
    
    @objc
    public var onDemand: Bool {
        get {
            return reachabilityFlags.onDemand
        }
    }
    
    private func logReachability(flags: SCNetworkReachabilityFlags) {
        print("Reachability flags: \(flags.description); online: \(flags.online); mobile: \(flags.mobile); on demand: \(flags.onDemand)")
    }
}
