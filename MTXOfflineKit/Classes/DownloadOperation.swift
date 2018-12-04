//
//  DownloadOperation.swift
//  APPSOfflineKit
//
//  Created by Kamal on 3/12/18.
//  Copyright © 2018 Kamal. All rights reserved.
//

import PSOperations
/**
 This generic class allows the use of the fetchRemoteDataWhere method of a soupManager
 from an operation. It's intended to be subclassed as shown below. By specifying
 a concrete SoupObject the correct soupManager is created.
 
 final class DownloadStaffTrainingsOperation: DownloadOperation<StaffTrainingSoupObject> {
 
    init(inspectionId: String) {
        let whereClause = "\(StaffTrainingSoupDescription.FieldName.InspectionId.rawValue) = '\(inspectionId)'"
        super.init(whereClause: whereClause)
    }
 }
 */

open class DownloadOperation<SO: SoupObject>: GroupOperation {
    /**
     Download all objects of soup type.
     */
    public init() {
        let op = __DownloadOperation<SO>()
        super.init(operations: [op])
    }
    
    /**
     Download objects of soup type matching whereClause.
     */
    public init(whereClause: String) {
        let op = __DownloadOperation<SO>(whereClause: whereClause)
        super.init(operations: [op])
    }
    
    /**
     Download objects of soup type matching fieldName in matchSet.
     The set is split up into multiple operations because of
     a size limit in the Salesforce WHERE clause.
     */
    public init(fieldName: String, matchSet: Set<String>) {
        
        super.init(operations: [])

        // Salesforce's max size of WHERE clause is 4000 characters.
        // https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_soslsoql.htm
        // An id field with quotes and separator has a length of 21 ('a0bt00000004YamAAE',).
        // Therefore approximately 200 ids would be allowed in an IN query.
        // We'll set it to a smaller number to be safe.
        let maxSetSize = 100
        
        // Is the size of the match set greater than maxSetSize
        if matchSet.count <= maxSetSize {
            // NO: Create one operation for the query
            let op = __DownloadOperation<SO>(fieldName: fieldName, matchSet: matchSet)
            addOperation(op)
        }
        else {
            // YES: Make multiple queries each of maxSetSize
            let orderedSet = Array(matchSet)
            for groupIds in orderedSet.chunked(by: maxSetSize) {
                let op = __DownloadOperation<SO>(fieldName: fieldName, matchSet: Set(groupIds))
                addOperation(op)
            }
        }
    }
}


class __DownloadOperation<SO: SoupObject>: PSOperation {
    
    fileprivate let soupManager = SoupManager<SO>(soupDescription: SO.dataSpec())
    fileprivate let whereClause: String?
    fileprivate var skipExecute = false
    
    public let logger = SFSDKLogger.sharedInstance(withComponent: "DownloadOperation")

    
    /**
     Download all objects of soup type.
     */
    override init() {
        whereClause = nil
        super.init()
        
        commonInit()
    }
    
    /**
     Download objects of soup type matching whereClause.
     */
    init(whereClause: String) {
        self.whereClause = whereClause
        super.init()
        
        commonInit()
    }
    
    /**
     Download objects of soup type matching fieldName in matchSet.
     */
    init(fieldName: String, matchSet: Set<String>) {
        let matchList = matchSet.map { "'\($0)'" }.joined(separator: ",")
        whereClause = "\(fieldName) IN (\(matchList))"
        super.init()
        
        commonInit()
        
        if matchSet.isEmpty {
            skipExecute = true
        }
        
    }
    
    fileprivate func commonInit() {
        // Assign a name to the operation
        name = String(describing: type(of: self))
    }
    
    override func execute() {
        
        
        if skipExecute {
            finish()
            return
        }
        
        let completion: (_ success: Bool) -> Void = { [weak self] (success) in
            guard let strongSelf = self else { return }
            let error = strongSelf.operationError(success: success)
            strongSelf.finishWithError(error)
        }
        
        if let whereClause = whereClause {
            soupManager.fetchRemoteDataWhere(whereClause, completion: completion)
        }
        else {
            soupManager.fetchAllRemoteDataCompletion(completion)
        }
    }
    
    func operationError(success: Bool) -> NSError? {
        guard !success else { return nil }
        
        let key = "download-operation.error-message"
        
        // Look in app bundle
        var format = NSLocalizedString(key, comment: "")
        if format == key { // if not found look in our bundle for a backup message
            // Unable to use self.dynamicType because it returns the app bundle see: https://bugs.swift.org/browse/SR-1917
            // let bundle = NSBundle(forClass: self.dynamicType)
            if let bundle = Bundle(identifier: "com.appstronomy.APPSOfflineKit") {
                format = NSLocalizedString(key, bundle: bundle, comment: "")
            }
        }
        
        let message = String(format: format, soupManager.soupDescription.objectType)
        let userInfo = [NSLocalizedDescriptionKey: message]
        
        let error = NSError(code: .executionFailed, userInfo: userInfo)
        return error
    }
}

