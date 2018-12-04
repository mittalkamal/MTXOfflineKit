//
//  MTXOfflineKit.h
//  MTXOfflineKit
//
//  Created by Kamal on 03/12/18.
//  Copyright © 2018 mtx. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for MTXOfflineKit.
FOUNDATION_EXPORT double MTXOfflineKitVersionNumber;

//! Project version string for MTXOfflineKit.
FOUNDATION_EXPORT const unsigned char MTXOfflineKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MTXOfflineKit/PublicHeader.h>

#import <MTXOfflineKit/SoupObject.h>
#import <MTXOfflineKit/SoupDescription.h>
#import <MTXOfflineKit/SoupPropertyDescription.h>

// Private header - imported here because bridging headers aren't allowed in frameworks
// and the header is needed in a swift test file.
#import <MTXOfflineKit/SoupObject+Internal.h>


// Salesforce

#import <SalesforceAnalytics/SalesforceAnalytics.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SmartStore/SmartStore.h>
#import <SmartSync/SmartSync.h>

