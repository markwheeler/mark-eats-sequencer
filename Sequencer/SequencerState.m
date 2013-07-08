//
//  SequencerState.m
//  Sequencer
//
//  Created by Mark Wheeler on 27/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerState.h"
#import "SequencerPageState.h"

@implementation SequencerState

+ (id) sharedSequencerState
{
    static SequencerState *sharedSequencerState = nil;
    @synchronized(self) {
        if (sharedSequencerState == nil)
            sharedSequencerState = [[self alloc] init];
    }
    return sharedSequencerState;
}

- (void) createPageStates:(uint)numberOfPages
{
    NSMutableArray *pages = [NSMutableArray arrayWithCapacity:numberOfPages];
    for( int i = 0; i < numberOfPages; i++ ) {
        SequencerPageState *pageState = [[SequencerPageState alloc] init];
        pageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
        pageState.currentPatternId = [NSNumber numberWithInt:0];
        [pages addObject:pageState];
    }
    self.pageStates = [NSArray arrayWithArray:pages];
}

@end
