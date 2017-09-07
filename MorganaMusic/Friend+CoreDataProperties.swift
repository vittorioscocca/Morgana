//
//  Friend+CoreDataProperties.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 10/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import CoreData


extension Friend {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Friend> {
        return NSFetchRequest<Friend>(entityName: "Friend")
    }

    @NSManaged public var firstName: String?
    @NSManaged public var fullName: String?
    @NSManaged public var gender: String?
    @NSManaged public var idFB: String?
    @NSManaged public var lastName: String?
    @NSManaged public var pictureUrl: String?
    @NSManaged public var user: User?

}
