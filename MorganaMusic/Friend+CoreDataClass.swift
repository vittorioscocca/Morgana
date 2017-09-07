//
//  Friend+CoreDataClass.swift
//  MorganaMusic
//
//  Created by Vittorio Scocca on 10/04/17.
//  Copyright © 2017 Vittorio Scocca. All rights reserved.
//

import Foundation
import CoreData


public class Friend: NSManagedObject {
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
