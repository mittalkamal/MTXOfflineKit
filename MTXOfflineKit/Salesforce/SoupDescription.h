/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "SoupPropertyDescription.h"
@import SmartStore;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kSObjectIdField;

@class SoupObject;

@interface SoupDescription : NSObject

@property (nonatomic, copy) NSString *objectType;
@property (nonatomic, strong) NSArray<SoupPropertyDescription *> *objectFieldSpecs;
@property (nonatomic, strong) NSArray<SFSoupIndex *> *indexSpecs;
@property (nonatomic, copy) NSString *soupName;
@property (nullable, nonatomic, copy) NSString *orderByFieldName;

@property (nonatomic, readonly) NSArray *fieldNames;
@property (nonatomic, readonly) NSArray *soupFieldNames;

// updatableFieldNames is an array of field names that can be
// updated on the server. It is lazily populated by the data manager
// when needed.
@property (nullable, nonatomic, copy) NSArray<NSString*> *updatableFieldNames;

// creatableFieldNames is an array of field names that can be
// created on the server. It is lazily populated by the data manager
// when needed.
@property (nullable, nonatomic, copy) NSArray<NSString*> *creatableFieldNames;

- (instancetype)initWithObjectType:(NSString *)objectType
        objectFieldSpecs:(NSArray<SoupPropertyDescription *> *)objectFieldSpecs
              indexSpecs:(NSArray<SFSoupIndex *> *)indexSpecs
                soupName:(NSString *)soupName
        orderByFieldName:(nullable NSString *)orderByFieldName;

+ (SoupObject *)createSoupObject:(NSDictionary *)soupDict;

@end

NS_ASSUME_NONNULL_END
