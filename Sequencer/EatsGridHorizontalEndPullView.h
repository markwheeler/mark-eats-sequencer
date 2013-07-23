//
//  EatsGridHorizontalEndPullView.h
//  Sequencer
//
//  Created by Mark Wheeler on 21/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridHorizontalEndPullView;

@protocol EatsGridHorizontalEndPullViewDelegateProtocol
- (void) eatsGridHorizontalEndPullViewUpdated:(EatsGridHorizontalEndPullView *)sender;
@end

@interface EatsGridHorizontalEndPullView : EatsGridSubView

@property uint      leftValue;
@property uint      rightValue;

@end
