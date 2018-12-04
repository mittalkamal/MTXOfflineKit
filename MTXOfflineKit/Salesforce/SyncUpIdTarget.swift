//
//  SyncUpIdsTarget.swift
//  APPSOfflineKit
//
//  Created by Ken Grigsby on 1/29/16.
//  Copyright © 2016 Appstronomy. All rights reserved.
//

import UIKit
import SmartSync

/// Class to sync up individual records specified by id

final public class SyncUpIdTarget: SFSyncUpTarget {
    
    
    let syncTargetIdKey = "SyncUpIdTarget.targetIds"

    let soupId: SoupId
    
    
    // MARK: Initialization
    
    public init(soupId: SoupId) {

        self.soupId = soupId
        super.init()
        commonInit()
    }
    
    public override init!(createFieldlist: [Any]!, updateFieldlist: [Any]!) {

        soupId = 1
        super.init(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
        commonInit()
    }

   
    
    override public init!(dict: [AnyHashable: Any]!) {
        
        soupId = dict[syncTargetIdKey] as! SoupId
        super.init(dict: dict)
        commonInit()
    }
    
    
    func commonInit() {
        targetType = .custom;
    }
    
    
    override public func getIdsOfRecords(toSyncUp syncManager: SFSmartSyncSyncManager!, soupName: String!) -> [Any]! {
        guard let dirtyIds = super.getIdsOfRecords(toSyncUp: syncManager, soupName: soupName) as? [SoupId] else { return [] }
        
        // Verify dirty target Id
        return dirtyIds.contains(soupId) ? [soupId] : []
    }
    
    override public func asDict() -> NSMutableDictionary! {
        let dict = super.asDict()
        dict?[kSFSyncTargetiOSImplKey] = NSStringFromClass(type(of: self))
        dict?[syncTargetIdKey] = soupId
        return dict
    }
}
