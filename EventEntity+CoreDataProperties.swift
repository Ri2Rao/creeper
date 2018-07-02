//
//  EventEntity+CoreDataProperties.swift
//  Creeper
//
//  Created by Deepti Pandey on 24/04/18.
//  Copyright © 2018 Tapzo. All rights reserved.
//
//

import Foundation
import CoreData


extension EventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EventEntity> {
        return NSFetchRequest<EventEntity>(entityName: "EventEntity")
    }

    @NSManaged public var eventName: String?
    @NSManaged public var messageId: String?
    @NSManaged public var originalTimestamp: NSDate?
    @NSManaged public var properties: [String: AnyObject]?
    @NSManaged public var sentAt: NSDate?
    @NSManaged public var status: String?
    @NSManaged public var type: String?

}
