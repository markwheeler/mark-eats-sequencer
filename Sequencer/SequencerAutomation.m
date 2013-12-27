//
//  SequencerAutomation.m
//  Sequencer
//
//  Created by Mark Wheeler on 24/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerAutomation.h"

@implementation SequencerAutomation

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, CurrentTick: %u, Mode: %i, LoopLength: %u, Changes: %@>", NSStringFromClass([self class]), self, self.currentTick, self.mode, self.loopLength, self.changes];
}

- (id) init
{
    self = [super init];
    if( !self )
        return nil;
    
    self.automationTypes = [self automationTypesArray];
    
    return self;
}

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    // Note: We've skipped saving tick and mode
    
    self.automationTypes = [self automationTypesArray];
    
    self.loopLength = [decoder decodeInt32ForKey:@"loopLength"];
    self.changes = [decoder decodeObjectForKey:@"changes"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.loopLength forKey:@"loopLength"];
    [encoder encodeObject:self.changes forKey:@"changes"];
}

- (NSArray *) automationTypesArray {
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EatsSequencerAutomationType_SetNextPatternId], @"automationType",
                                                                                [NSString stringWithFormat:@"Change pattern"], @"typeName", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EatsSequencerAutomationType_SetNextStep], @"automationType",
                                                                                [NSString stringWithFormat:@"Scrub pattern"], @"typeName", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EatsSequencerAutomationType_SetLoop], @"automationType",
                                                                                [NSString stringWithFormat:@"Loop"], @"typeName", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EatsSequencerAutomationType_SetTranspose], @"automationType",
                                                                                [NSString stringWithFormat:@"Transpose"], @"typeName", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EatsSequencerAutomationType_SetPlayMode], @"automationType",
                                                                                [NSString stringWithFormat:@"Play mode"], @"typeName", nil],
                                     nil];
}

@end