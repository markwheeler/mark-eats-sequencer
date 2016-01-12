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

- (id) init
{
    self = [super init];
    if( !self )
        return nil;

    NSMutableArray *pages = [NSMutableArray arrayWithCapacity:kSequencerNumberOfPages];
    for( int i = 0; i < kSequencerNumberOfPages; i++ ) {
        SequencerPageState *pageState = [[SequencerPageState alloc] init];
        pageState.playMode = EatsSequencerPlayMode_Pause;
        pageState.inLoop = YES;
        pageState.pageTick = -1;
        [pages addObject:pageState];
    }
    self.pageStates = [NSArray arrayWithArray:pages];
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, CurrentPageId: %i, PageStates: %@>", NSStringFromClass([self class]), self, self.currentPageId, self.pageStates];
}

@end
