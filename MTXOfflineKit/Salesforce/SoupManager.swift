//
//  SoupManager.swift
//  APPSOfflineKit
//
//  Created by Ken Grigsby on 2/12/16.
//  Copyright © 2016 Appstronomy. All rights reserved.
//

import SmartStore
import SmartSync

public extension Notification.Name {
    public static let SoupManagerDidSaveNotification = Notification.Name("DidSaveNotification")
}
// Keys used in userInfo of SoupManagerDidSaveNotification notification
public let SoupManagerInsertedObjectsKey  = "InsertedObjectsKey" // Set<SoupObject>
public let SoupManagerDeletedObjectsKey   = "DeletedObjectsKey" // Set<SoupObject>
public let SoupManagerUpdatedObjectsKey   = "UpdatedObjectsKey" // Set<SoupObject>


public let SoupManagerMaxQueryPageSize = UInt(5000)
public let SoupManagerSyncLimit = UInt(10000)

public let logger = SFSDKLogger.sharedInstance(withComponent: "SoupManager")


open class SoupManager<T:SoupObject>: NSObject {


    public typealias SoupDictionary = [AnyHashable: Any]
    public typealias SyncCompletionBlock = (_ success: Bool) -> Void
    
    let syncMgr: SFSmartSyncSyncManager
    open let soupDescription: SoupDescription
    var syncDownId = 0
    
    public init(soupDescription: SoupDescription) {
        self.syncMgr = SFSmartSyncSyncManager.sharedInstance(SFUserAccountManager.sharedInstance().currentUser)
        self.soupDescription = soupDescription
        super.init()
        
        if !self.store.soupExists(soupDescription.soupName) {
            registerSoup()
        } else {
            _ = alterSoupIfNecessaryWithIndexSpecs(soupDescription.indexSpecs)
        }
        /**
         Calling describe prints out to the console all the attributes of all the properties
         of the given object type. This is useful to find the data types to use in the data
         models.
         */
//        describe("Licensing_Transaction__c")
    }
    
    open var store: SFSmartStore {
        return SFSmartStore.sharedStore(withName: kDefaultSmartStoreName) as! SFSmartStore
    }

    
    func describe(_ objectType: String) {
        
        SFRestAPI.sharedInstance().performDescribe(withObjectType: objectType, fail: {_ in } ) { (dict) -> Void in
            
            guard let fields = dict?["fields"] as? [NSDictionary] else { return }
            
            print("Describe ObjectType:\(objectType)")
            print("\(fields)")
        }
    }

    
    open var count: Int {
        let querySpec = SFQuerySpec.newAllQuerySpec(soupDescription.soupName, withOrderPath: soupDescription.orderByFieldName, with: .ascending, withPageSize: UInt(SoupManagerMaxQueryPageSize))
        let count = store.count(with: querySpec, error: nil)
        return Int(count)
    }
    
    
    /**
     Updates the cache of creatable and updatable field names if not already set
     */
    func updateChangeableFieldNames(_ completion: @escaping () -> Void) {
        
        if soupDescription.updatableFieldNames != nil && soupDescription.creatableFieldNames != nil {
            completion()
            return
        }

        SFRestAPI.sharedInstance().performDescribe(withObjectType: soupDescription.objectType, fail: { (error) -> Void in
            completion()
            }, complete: { [weak self] (dict) -> Void in
                guard let me = self else { return }
                
                guard let fields = dict?["fields"] as? [NSDictionary] else {
                    completion()
                    return
                }
                let dataSpecFieldsSet = Set(me.soupDescription.fieldNames as! [String])
                
                let updatableFields = fields.filter { ($0["updateable"] as? Bool) ?? false }
                var updatableFieldNames = Set(updatableFields.flatMap { $0["name"] as? String })
                updatableFieldNames.formIntersection(dataSpecFieldsSet)
                me.soupDescription.updatableFieldNames = Array(updatableFieldNames)
                
                let creatableFields = fields.filter { ($0["createable"] as? Bool) ?? false }
                var creatableFieldNames = Set(creatableFields.flatMap { $0["name"] as? String })
                creatableFieldNames.formIntersection(dataSpecFieldsSet)
                me.soupDescription.creatableFieldNames = Array(creatableFieldNames)
                
                completion()
            })
    }
    
    
    func alterSoupIfNecessaryWithIndexSpecs(_ indexSpecs: [SFSoupIndex]) -> Bool {
        
        let existingIndexSpecs = store.indices(forSoup: soupDescription.soupName) as! [SFSoupIndex]
        var didAlterSoup = false
        
        let specsAreEqual = SFSoupIndex.arrayOfIndexSpecs(indexSpecs, isEqualToIndexSpecs: existingIndexSpecs, withColumnName: false)
        if !specsAreEqual {
            store.alterSoup(soupDescription.soupName, withIndexSpecs: indexSpecs, reIndexData: true)
            didAlterSoup = true
        }
        return didAlterSoup
    }


    
    // MARK: - Fetch Local
    
    open func fetchAllLocalData() -> [T] {
        let querySpec = SFQuerySpec.newAllQuerySpec(soupDescription.soupName, withOrderPath: soupDescription.orderByFieldName, with: .ascending, withPageSize: SoupManagerMaxQueryPageSize)
        let dataRows: [T] = fetchLocalDataWithQuerySpec(querySpec!)
        return dataRows
    }
    
    
    open func fetchLocalDataById(_ identifier: String) -> T? {
        
        let dataRows: [T] = fetchLocalDataWithPath("Id", matchKey: identifier)
        assert(dataRows.count <= 1)
        return dataRows.first
    }
    
    
    open func fetchLocalDataBySoupId(_ soupId: SoupId) -> T? {
        
        let dataRows: [T] = fetchLocalDataWithPath(SOUP_ENTRY_ID, matchKey: soupId.stringValue)
        assert(dataRows.count <= 1)
        return dataRows.first
    }
    
    
    open func fetchLocalDataWithPath(_ path: String, matchKey: String) -> [T] {
        
        let querySpec = SFQuerySpec.newExactQuerySpec(soupDescription.soupName, withPath: path, withMatchKey: matchKey, withOrderPath: nil, with: .ascending, withPageSize: SoupManagerMaxQueryPageSize)
        
        let dataRows: [T] = fetchLocalDataWithQuerySpec(querySpec!)
        return dataRows
    }
    
    
    open func countLocalDataWithPath(_ path: String, matchKey: String) -> Int {
        let querySpec = SFQuerySpec.newExactQuerySpec(soupDescription.soupName, withPath: path, withMatchKey: matchKey, withOrderPath: nil, with: .ascending, withPageSize: SoupManagerMaxQueryPageSize)
        return countLocalDataWithQuerySpec(querySpec!)
    }
    
    
    open func countLocalDataWithQuerySpec(_ querySpec: SFQuerySpec) -> Int {
        
        var count: UInt = 0
        var error: NSError?
        
        count = store.count(with: querySpec, error: &error)
        if let error = error {
            logger.log(SoupManager.self, level: .error, message: "Error retrieving count of '\(soupDescription.objectType)' data from SmartStore: \(error.localizedDescription)")
            return 0
        }
        return Int(count)
    }
    
    
    open func fetchLocalDataWithQuerySpec(_ querySpec: SFQuerySpec) -> [T] {

        var queryResults: [SoupDictionary] = []
        do {
            let results = try store.query(with: querySpec, pageIndex: 0)
            let objects: [AnyObject]
            if querySpec.queryType == .smart {
                // Smart query returns an array of arrays with the first object
                // being the soup dictionary
                let arraysOfArrays = results as! [[AnyObject]]
                objects = arraysOfArrays.flatMap { $0.first }
            } else {
                objects = results as [AnyObject]
            }
            queryResults = objects as? [SoupDictionary] ?? []
        } catch let error as NSError {
            logger.log(SoupManager.self, level: .error, message: "Error retrieving '\(soupDescription.objectType)' data from SmartStore: \(error.localizedDescription)")
            
            return []
        }
        
        let dataRows: [T] = populateDataRows(queryResults)
        //log(.Debug, msg: "Finished generating data rows. Number of rows: \(dataRows.count).")
        return dataRows
    }
    
    
    
    // MARK: - Fetch Remote

    open func fetchAllRemoteDataCompletion(_ completionBlock: @escaping SyncCompletionBlock) {
        
        let updateBlock: SFSyncSyncManagerUpdateBlock = { (sync) -> Void in
            if (sync?.isDone())! || (sync?.hasFailed())! {
                DispatchQueue.main.async {
                    completionBlock((sync?.isDone())!)
                }
            }
        }
        
        if syncDownId == 0 {
            // first time
            let fieldNames = (soupDescription.fieldNames as NSArray).componentsJoined(by: ",")
            let soqlQuery = "SELECT \(fieldNames), LastModifiedDate FROM \(soupDescription.objectType) LIMIT \(SoupManagerSyncLimit)"
            let syncOptions = SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged)
            let syncTarget = SFSoqlSyncDownTarget.newSyncTarget(soqlQuery)

            syncMgr.syncDown(with: syncTarget, options: syncOptions, soupName: soupDescription.soupName, update: updateBlock)
        } else {
            // subsequent times
            syncMgr.reSync(syncDownId as NSNumber, update: updateBlock)
        }
    }
    
    
    open func fetchRemoteDataById(_ identifier: String, completion: @escaping SyncCompletionBlock) {
        let whereClause = "Id = '\(identifier)'"
        fetchRemoteDataWhere(whereClause, limit: 1, completion:completion)
    }
    
    
    open func fetchRemoteDataWhere(_ whereClause: String, completion: @escaping SyncCompletionBlock) {
        fetchRemoteDataWhere(whereClause, limit: SoupManagerMaxQueryPageSize, completion:completion)
    }
    

    open func fetchRemoteDataWhere(_ whereClause: String, limit: UInt, completion: @escaping SyncCompletionBlock) {
        let fieldNames = (soupDescription.fieldNames as NSArray).componentsJoined(by: ",")
        let soqlQuery = "SELECT \(fieldNames), LastModifiedDate FROM \(soupDescription.objectType) WHERE \(whereClause)  LIMIT \(limit)"
        fetchRemoteDataWithSoqlQuery(soqlQuery, completion: completion)
    }
    
    
    open func fetchRemoteDataWithSoqlQuery(_ soqlQuery: String, completion: @escaping SyncCompletionBlock) {

        let syncOptions = SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged)
        let syncTarget = SFSoqlSyncDownTarget.newSyncTarget(soqlQuery)
        syncMgr.syncDown(with: syncTarget, options: syncOptions, soupName: soupDescription.soupName) { (sync) -> Void in
            if (sync?.isDone())! || (sync?.hasFailed())! {
                DispatchQueue.main.async {
                    completion((sync?.isDone())!)
                }
            }
        }
    }
    
    
    // MARK: - Update Remote
    
    open func updateRemoteData(_ completion: @escaping SyncCompletionBlock) {
        
        let syncOptions = SFSyncOptions.newSyncOptions(forSyncUp: soupDescription.fieldNames, mergeMode: .overwrite)
        
        syncMgr.syncUp(with: syncOptions, soupName: soupDescription.soupName) { (sync) -> Void in
            if (sync?.isDone())! || (sync?.hasFailed())! {
                DispatchQueue.main.async(execute: { () -> Void in
                    completion((sync?.isDone())!)
                })
            }
        }
    }
    
    
    /**
     Update one remote object
     */
    open func updateRemoteDataWithSoupId(_ soupId: SoupId, completion: @escaping SyncCompletionBlock) {
        
        guard let soupObject = fetchLocalDataBySoupId(soupId) else {
            logger.log(SoupManager.self, level: .error, message: "Couldn't find object with soupId: \(soupId) in soup \(soupDescription.soupName)")
            completion(false)
            return
        }
        
        // Return early if not changed
        if !soupObject.isLocallyChanged {
            completion(true)
            return
        }
        
        updateChangeableFieldNames { [weak self] in
            
            guard let me = self else { return }
            
            var fieldNames: [String]?
            
            if soupObject.isLocallyCreated {
                
                fieldNames = me.soupDescription.creatableFieldNames
                logger.log(SoupManager.self, level: .error,
                           message:"\(fieldNames)--isLocallyCreated------")
            } else if soupObject.isLocallyUpdated {
              
                fieldNames = me.soupDescription.updatableFieldNames
                logger.log(SoupManager.self, level: .error,
                           message:"\(fieldNames)--isLocallyUpdated------")
            } else if soupObject.isLocallyDeleted {
                fieldNames = ["Id"]
            }
            
            if fieldNames == nil || fieldNames!.count == 0 {
                completion(false)
                return
            }
            
            let syncOptions = SFSyncOptions.newSyncOptions(forSyncUp: fieldNames!, mergeMode: .overwrite)
            
            logger.log(SoupManager.self, level: .error,
                       message:"SoupId:= \(soupId)-----before SyncUpIdTarget------")
        
            
           // let target = SyncUpIdTarget(soupId: soupId)
            
            logger.log(SoupManager.self, level: .error,
                       message:"SoupId:= \(soupId)-----after SyncUpIdTarget------")
            
            
            me.syncMgr.syncUp(with: syncOptions, soupName: me.soupDescription.soupName) { (sync) -> Void in
                if (sync?.isDone())! || (sync?.hasFailed())! {
                    DispatchQueue.main.async(execute: { () -> Void in
                        completion((sync?.isDone())!)
                    })
                }
            }
            
//            me.syncMgr.syncUp(with: target, options: syncOptions, soupName: me.soupDescription.soupName) { (sync) -> Void in
//                if (sync?.isDone())! || (sync?.hasFailed())! {
//                    DispatchQueue.main.async(execute: { () -> Void in
//                        completion((sync?.isDone())!)
//                    })
//                }
//            }
        }
    }



    // MARK: - Create Local
    
    open func createLocalData(_ newData: SoupObject) {
        newData.updateSoup(forFieldName: kSyncTargetLocal, fieldValue: true)
        newData.updateSoup(forFieldName: kSyncTargetLocallyCreated, fieldValue: true)
        let updatedEntry = (store.upsertEntries([newData.soupDict], toSoup: type(of: newData).dataSpec().soupName) as! [SoupDictionary]).first!
        newData.updateSoup(forFieldName: SOUP_ENTRY_ID, fieldValue: updatedEntry[SOUP_ENTRY_ID])
        newData.updateSoup(forFieldName: SOUP_LAST_MODIFIED_DATE, fieldValue: updatedEntry[SOUP_LAST_MODIFIED_DATE])
        SoupManager.recordChange(.inserted, object: newData)
    }
    
    
    
    // MARK: - Update Local
    
    open func updateLocalData(_ updatedData: SoupObject) {
        updatedData.updateSoup(forFieldName: kSyncTargetLocal, fieldValue: true)
        updatedData.updateSoup(forFieldName: kSyncTargetLocallyUpdated, fieldValue: true)
        // Save with the default externalIdPath of SOUP_ENTRY_ID instead of "Id" because the "Id" isn't
        // set until the entry is synced to the server. By using the SOUP_ENTRY_ID a newly added entry (but not uploaded)
        // can be edited again and saved locally. Using the externalIdPath of "Id" with an empty "Id"
        // the save would fail (with only console output
        let updatedEntry = (store.upsertEntries([updatedData.soupDict], toSoup: type(of: updatedData).dataSpec().soupName)as! [SoupDictionary]).first!
        updatedData.updateSoup(forFieldName: SOUP_ENTRY_ID, fieldValue: updatedEntry[SOUP_ENTRY_ID])
        updatedData.updateSoup(forFieldName: SOUP_LAST_MODIFIED_DATE, fieldValue: updatedEntry[SOUP_LAST_MODIFIED_DATE])
        SoupManager.recordChange(.updated, object: updatedData)
    }
    
    
    
    // MARK: - Delete Local
    
    open func deleteLocalData(_ dataToDelete: SoupObject) {
        if dataToDelete.isLocallyCreated {
            // Data was locally created and then deleted before being uploaded.
            // There's no need to tell the server about the object.
            // Just delete it locally.
            store.removeEntries([dataToDelete.soupId], fromSoup: type(of: dataToDelete).dataSpec().soupName)
        } else {
            dataToDelete.updateSoup(forFieldName: kSyncTargetLocal, fieldValue: true)
            dataToDelete.updateSoup(forFieldName: kSyncTargetLocallyDeleted, fieldValue: true)
            store.upsertEntries([dataToDelete.soupDict], toSoup: type(of: dataToDelete).dataSpec().soupName)
        }
        
        // Notify observers (i.e. viewControllers) so they can remove item from their lists
        SoupManager.recordChange(.deleted, object: dataToDelete)
    }

    
    // MARK: - Remove Local
    
    open func removeLocalData(_ soupId: SoupId) {
        store.removeEntries([soupId], fromSoup: soupDescription.soupName)
    }
    
    
    // MARK: - Private
    
    fileprivate func registerSoup() {
        let soupName = soupDescription.soupName
        let indexSpecs = soupDescription.indexSpecs
        //let errorPtr = NSErrorPointer()?
        //let _ = try? store.registerSoup(soupName, withIndexSpecs: indexSpecs)
        let _ = try? store.registerSoup(soupName, withIndexSpecs: indexSpecs, error: ())
    }
    
    
    fileprivate func populateDataRows(_ queryResults: [SoupDictionary]) -> Array<T> {
        return queryResults.map { type(of: soupDescription).createSoupObject($0) as! T }
    }

}


extension SoupManager {
    
    class fileprivate func recordChange(_ change: UpdateRecorder.ChangeType, object: NSObject) {
        if let recorder = currentUpdateRecorder {
            recorder.recordChange(change, object: object)
        } else {
            performBatchUpdates { currentUpdateRecorder!.recordChange(change, object: object) }
        }
    }
    
    /**
     Performs multiple insert, update, and delete operations as a group and posts one SoupManagerDidSaveNotification.
     
     - parameter updates: The block that performs the relevant createLocalData, updateLocalData, and deleteLocalData operations.
     */
    class public func performBatchUpdates(_ updates: (() -> Void)) {
        UpdateRecorder.updateRecorders.append(UpdateRecorder())
        
        updates()
        
        if let recorder = UpdateRecorder.updateRecorders.popLast() {
            recorder.postNotifications()
        }
    }
    
    
}



// MARK: - Update Recorder

/**
The update recorder provides a way to post one SoupManagerDidSaveNotification notification for
multiple save (insert, update, delete) operations.
*/

private final class UpdateRecorder {
    
    static fileprivate var updateRecorders: [UpdateRecorder] = []
    
    enum ChangeType {
        case inserted
        case updated
        case deleted
    }
    
    func recordChange(_ change: ChangeType, object: NSObject) {
        switch change {
        case.inserted:
            insertedObjects.insert(object)
        case.updated:
            updatedObjects.insert(object)
        case.deleted:
            deletedObjects.insert(object)
        }
    }
    
    
    
    // MARK: - Notifications
    
    func postNotifications() {
        if !insertedObjects.isEmpty ||
            !updatedObjects.isEmpty ||
            !deletedObjects.isEmpty {
            postDidSaveNotificationForInsertedObjects(insertedObjects, updatedObjects: updatedObjects, deletedObjects: deletedObjects)
        }

    }
    
    func postDidSaveNotificationForInsertedObjects(_ insertedObjects: Set<NSObject>?, updatedObjects: Set<NSObject>?, deletedObjects: Set<NSObject>?) {
        
        var userInfo: [String: NSObject] = [:]
        
        if let insertedObjects = insertedObjects, !insertedObjects.isEmpty {
            userInfo[SoupManagerInsertedObjectsKey] = insertedObjects as NSObject
        }
        
        if let updatedObjects = updatedObjects, !updatedObjects.isEmpty {
            userInfo[SoupManagerUpdatedObjectsKey] = updatedObjects as NSObject
        }
        
        if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
            userInfo[SoupManagerDeletedObjectsKey] = deletedObjects as NSObject
        }
        
        if !userInfo.isEmpty {
            NotificationCenter.default.postNotificationOnMainThread(withName:  Notification.Name.SoupManagerDidSaveNotification.rawValue, object: nil, userInfo: userInfo)
        }
        
    }

    fileprivate(set) var insertedObjects: Set<NSObject> = []
    fileprivate(set) var updatedObjects: Set<NSObject> = []
    fileprivate(set) var deletedObjects: Set<NSObject> = []
}


private var currentUpdateRecorder: UpdateRecorder? {
    return UpdateRecorder.updateRecorders.last
}
