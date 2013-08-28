//
//  EatsGridHorizontalShiftView.h
//  Sequencer
//
//  Created by Mark Wheeler on 20/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridHorizontalShiftView;

@protocol EatsGridHorizontalShiftViewDelegateProtocol
- (void) eatsGridHorizontalShiftViewUpdated:(EatsGridHorizontalShiftView *)sender;
@end

@interface EatsGridHorizontalShiftView : EatsGridSubView

@property uint      zeroStep;
@property int       shift;
@property BOOL      useWideBrightnessRange;

@end
