//
//  EatsGridLoopBraceView.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridLoopBraceView;

@protocol EatsGridLoopBraceViewDelegateProtocol
- (void) eatsGridLoopBraceViewUpdated:(EatsGridLoopBraceView *)sender;
@end

@interface EatsGridLoopBraceView : EatsGridSubView

@property float     startPercentage;
@property float     endPercentage;

@property BOOL      fillBar;

@end
