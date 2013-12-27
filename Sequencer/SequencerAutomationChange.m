//
//  SequencerAutomationChange.m
//  Sequencer
//
//  Created by Mark Wheeler on 24/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerAutomationChange.h"

@implementation SequencerAutomationChange

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Tick: %u, PageId: %u, AutomationType: %u, Values: %@>", NSStringFromClass([self class]), self, self.tick, self.pageId, self.automationType, self.values];
}

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    self.tick = [decoder decodeInt32ForKey:@"tick"];
    self.pageId = [decoder decodeInt32ForKey:@"pageId"];
    self.automationType = [decoder decodeInt32ForKey:@"automationType"];
    self.values = [decoder decodeObjectForKey:@"newValue"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.tick forKey:@"tick"];
    [encoder encodeInt32:self.pageId forKey:@"pageId"];
    [encoder encodeInt32:self.automationType forKey:@"automationType"];
    [encoder encodeObject:self.values forKey:@"newValue"];
}

- (id) copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] alloc] init];
    
    if( copy ) {
        [copy setTick:self.tick];
        [copy setPageId:self.pageId];
        [copy setAutomationType:self.automationType];
        [copy setValues:self.values];
    }
    
    return copy;
}

@end