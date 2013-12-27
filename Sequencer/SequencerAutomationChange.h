//
//  SequencerAutomationChange.h
//  Sequencer
//
//  Created by Mark Wheeler on 24/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Sequencer.h"

@interface SequencerAutomationChange : NSObject <NSCoding, NSCopying>

@property uint                          tick; // 0-X, measured in 64ths, max value dependent on automation loop length
@property uint                          pageId;
@property EatsSequencerAutomationType   automationType;
@property NSDictionary                  *values;

@end