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

#import "SoupObject+Internal.h"
@import SalesforceSDKCore;
@import SmartStore;
@import SmartSync;


@interface SoupObject ()
@property (nonatomic, strong) NSMutableDictionary *mutableSoup;
@end

@implementation SoupObject

- (instancetype)initWithSoupDict:(NSDictionary *)soupDict {
    self = [self init];
    if (self) {
        if (soupDict != nil) {
            for (NSString *fieldName in [soupDict allKeys]) {
                [self updateSoupForFieldName:fieldName fieldValue:soupDict[fieldName]];
            }
        }
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mutableSoup = [[NSMutableDictionary alloc] initWithCapacity:10];
        for (NSString *fieldName in [[self class] dataSpec].fieldNames) {
            [self updateSoupForFieldName:fieldName fieldValue:[NSNull null]];
        }
        [self updateSoupForFieldName:@"attributes" fieldValue:@{ @"type": [[self class] dataSpec].objectType }];
    }
    return self;
}


- (id)copyWithZone:(NSZone *)zone {
    SoupObject *result = [[[self class] allocWithZone:zone] initWithSoupDict:_mutableSoup];
    return result;
}


#pragma mark - Property Overrides

- (NSDictionary *)soupDict {
    return [_mutableSoup copy];
}

- (SoupId)soupId {
    return [self fieldValueForFieldName:SOUP_ENTRY_ID];
}

- (BOOL)isLocallyCreated {
    return [[self fieldValueForFieldName:kSyncTargetLocallyCreated] boolValue];
}

- (BOOL)isLocallyDeleted {
    return [[self fieldValueForFieldName:kSyncTargetLocallyDeleted] boolValue];
}

- (BOOL)isLocallyUpdated {
    return [[self fieldValueForFieldName:kSyncTargetLocallyUpdated] boolValue];
}

- (BOOL)isLocallyChanged {
    return [[self fieldValueForFieldName:kSyncTargetLocal] boolValue];
}


- (void)updateSoupForFieldName:(NSString *)fieldName fieldValue:(id)fieldValue  {
    [self.mutableSoup setNullObject:fieldValue forKeyPath:fieldName];
}

- (id)fieldValueForFieldName:(NSString *)fieldName {
    return [self nonNullFieldValue:fieldName];
}

- (id)nonNullFieldValue:(NSString *)fieldName {
    return [self.mutableSoup nonNullObjectForKeyPath:fieldName];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p> %@", [self class], self, self.soupDict];
}

- (BOOL)isRelatedFieldName:(NSString *)fieldName {
    BOOL isRelatedFieldName = [fieldName containsString:@"."];
    return isRelatedFieldName;
}

// dataSpec is abstract.
+ (SoupDescription *)dataSpec {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end


@implementation NSMutableDictionary (SoupObject)

/**
 Given a keyPath with embedded "." this method
 will create nested NSMutableDictionaries in which
 to put the object so that the object can be retrieved
 with nonNullObjectForKeyPath. If the object is nil then
 NSNull to stored.
 */
- (void)setNullObject:(id)object forKeyPath:(NSString *)keyPath {
    
    if ([keyPath containsString:@"."]) {
        NSMutableArray *comps = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
        NSString *firstFieldName = comps.firstObject;
        [comps removeObjectAtIndex:0];
        NSString *remainingFieldName = [comps componentsJoinedByString:@"."];
        
        id subDict = [self valueForKey:firstFieldName];
        if (subDict == [NSNull null]) {
            // Cause NSNull to be replaced with dictionary
            subDict = nil;
        }
        if (!subDict) {
            subDict = [NSMutableDictionary dictionary];
            self[firstFieldName] = subDict;
        }
        [subDict setNullObject:object forKeyPath:remainingFieldName];
    } else {
        if (object == nil)
            object = [NSNull null];
        [self setObject:object forKey:keyPath];
    }
}

@end


@implementation NSDictionary (SoupObject)

- (id)nonNullObjectForKeyPath:(NSString *)keyPath {
    id result = [self valueForKeyPath:keyPath];
    if (result == [NSNull null]) {
        return nil;
    }
    if ([result isKindOfClass:[NSString class]] && ([result isEqualToString:@"<nil>"] || [result isEqualToString:@"<null>"])) {
        return nil;
    }
    
    return result;
}


@end
