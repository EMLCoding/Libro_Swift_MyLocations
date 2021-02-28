//
//  Location+CoreDataProperties.swift
//  MyLocations
//
//  Created by Eduardo Martin Lorenzo on 23/02/2021.
//
//

// Archivo creado desde el DataModel con Editor > Create NSManagedObject Subclass...

import Foundation
import CoreData
import CoreLocation // Añadido a mano


extension Location {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var date: Date?
    @NSManaged public var locationDescription: String
    @NSManaged public var category: String
    @NSManaged public var placemark: CLPlacemark? // Cambiado a mano
    @NSManaged public var photoID: NSNumber?

}

extension Location : Identifiable {

}
