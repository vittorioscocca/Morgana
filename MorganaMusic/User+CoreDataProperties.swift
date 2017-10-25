//
//  User+CoreDataProperties.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 10/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var cityOfRecidence: String?
    @NSManaged public var birthday: String?
    @NSManaged public var email: String?
    @NSManaged public var firstName: String?
    @NSManaged public var fullName: String?
    @NSManaged public var gender: String?
    @NSManaged public var idApp: String?
    @NSManaged public var idFB: String?
    @NSManaged public var lastName: String?
    @NSManaged public var pictureUrl: String?
    @NSManaged public weak var friends: NSSet?

}

// MARK: Generated accessors for friends
extension User {

    @objc(addFriendsObject:)
    @NSManaged public func addToFriends(_ value: Friend)

    @objc(removeFriendsObject:)
    @NSManaged public func removeFromFriends(_ value: Friend)

    @objc(addFriends:)
    @NSManaged public func addToFriends(_ values: NSSet)

    @objc(removeFriends:)
    @NSManaged public func removeFromFriends(_ values: NSSet)

}
