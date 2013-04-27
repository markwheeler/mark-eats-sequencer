//
//  SequencerState.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SequencerState : NSObject

@property NSArray   *pageStates;

+ (id) sharedSequencerState;
- (void) createPageStates:(uint)numberOfPages;

@end
