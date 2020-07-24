//
//  Database.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import CoreData
import os

protocol Database {
    func insert(_ event: String)
    func exportEvents()
}

class MockDatabase: Database {
    func insert(_ event: String) {
    }
    func exportEvents() {
    }
}

@available(iOS 10.0, *)
class ConcreteDatabase: Database {
    private let logger = ConcreteLogger(subsystem: "Data", category: "Database")
    private let dispatchQueue = DispatchQueue(label: "Database")
    private var persistentContainer: NSPersistentContainer
    private var events: [Event] = []

    init() {
        persistentContainer = NSPersistentContainer(name: "_SENSOR_iOS")
        let storeDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = storeDirectory.appendingPathComponent("_SENSOR_iOS.sqlite")
        let description = NSPersistentStoreDescription(url: url)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores { description, error in
            description.options.forEach() { option in
                self.logger.log(.debug, "Loaded persistent stores (key=\(option.key),value=\(option.value.description))")
            }
            if let error = error {
                fatalError("Unable to load persistent stores: \(error.localizedDescription)")
            }
        }
        load()
    }
    
    func insert(_ event: String) {
        do {
            let managedContext = persistentContainer.viewContext
            let object = NSEntityDescription.insertNewObject(forEntityName: "Event", into: managedContext) as! Event
            object.setValue(Date(), forKey: "time")
            object.setValue(event, forKey: "event")
            try managedContext.save()
            events.append(object)
        } catch {
            logger.log(.fault, "insert failed (event=\(event),error=\(error.localizedDescription))")
        }
    }
    
    /// Requires : Info.plist : Application supports iTunes file sharing = YES
    func exportEvents() {
        dispatchQueue.async {
            do {
                let fileURL = try FileManager.default
                    .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("events.csv")
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                var string = "time,event\n"
                self.events.forEach() { event in
                    guard let time = event.time, let eventText = event.event else {
                        return
                    }
                    let timestamp = dateFormatter.string(from: time)
                    let row = timestamp + ",\"" + eventText + "\"\n"
                    string.append(row)
                }
                print(string)
                try string.write(to: fileURL, atomically: true, encoding: .utf8)
                self.logger.log(.debug, "export")
            } catch {
                self.logger.log(.fault, "export failed (error=\(error.localizedDescription))")
            }
        }
    }

    
    private func load() {
        let managedContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<Event>(entityName: "Event")
        do {
            events = try managedContext.fetch(fetchRequest)
            logger.log(.debug, "Loaded (count=\(events.count))")
        } catch let error as NSError {
            logger.log(.fault, "Load failed (error=\(error.description))")
        }
    }
}
