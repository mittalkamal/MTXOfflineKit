//
//  SyncOperation.swift
//  APPSOfflineKit
//
//  Created by Kamal on 3/12/18.
//  Copyright © 2018 Kamal. All rights reserved.
//
import PSOperations

open class SyncOperation<T:SoupObject>: PSOperation {
    
    /**
     Set to true to treat any errors as success.
     Because Salesforce doesn't return any errors, only success/fail, sometimes
     you might want to ignore the error to keep further operations running.
     */
    open var ignoreErrors = false
    
    fileprivate let soupId: SoupId?
    fileprivate let soupManager: SoupManager<T>
    
    public let logger = SFSDKLogger.sharedInstance(withComponent: "SyncOperation")

    
    // MARK: - Initialization
    
    /**
     Sync object with soupId belonging to SoupManager.
     */
    public init(soupId: SoupId, soupManager: SoupManager<T>) {
        self.soupId = soupId
        self.soupManager = soupManager
    }
    
    
    /**
     Sync all objects belonging to SoupManager.
     */
    public init(soupManager: SoupManager<T>) {
        self.soupId = nil
        self.soupManager = soupManager
    }
    
    
    override open func execute() {
        
        if let soupId = soupId {
            
            self.logger.log(SyncOperation.self, level: .error,
                                   message:"'\(self.soupManager.soupDescription.soupName)------' updateRemoteDataWithSoupId:\(soupId)------")
            
            soupManager.updateRemoteDataWithSoupId(soupId) { [weak self] (success) -> Void in
                guard let strongSelf = self else { return }
                
                strongSelf.logger.log(SyncOperation.self, level: .debug,
                                      message:"'\(strongSelf.soupManager.soupDescription.soupName)' updateRemoteDataWithSoupId:\(soupId)  completed: \(success ? "success" : "failed")")
                let error = strongSelf.operationError(success: success)
                strongSelf.finishWithError(error)
            }
        }
        else {
            
            
            self.logger.log(SyncOperation.self, level: .error,
                            message:"'\(self.soupManager.soupDescription.soupName)------' updateRemoteData:------")
            
            soupManager.updateRemoteData { [weak self] (success) -> Void in
                guard let strongSelf = self else { return }
                
                strongSelf.logger.log(SyncOperation.self, level: .debug,
                                      message: "'\(strongSelf.soupManager.soupDescription.soupName)' updateRemoteData completed: \(success ? "success" : "failed")")
                let error = strongSelf.operationError(success: success)
                strongSelf.finishWithError(error)
            }
        }
    }
    
    open func operationError(success: Bool) -> NSError? {
        guard !success else { return nil }
        
        if ignoreErrors {
            if let soupId = soupId {
                logger.log(SyncOperation.self, level: .debug,
                                      message: "ignoring error for SoupId:\(soupId) soupName: '\(soupManager.soupDescription.soupName)'")
            }
            else {
                logger.log(SyncOperation.self, level: .debug,
                                      message: "ignoring error for soupName: '\(soupManager.soupDescription.soupName)'")
            }
            return nil
        }
        
        let key = "sync-operation.error-message"
        
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
