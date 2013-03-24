//
//  EatsGridHorizontalSliderView.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridHorizontalSliderView;

@protocol EatsGridHorizontalSliderViewDelegateProtocol
- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender;
@end

@interface EatsGridHorizontalSliderView : EatsGridSubView

@property float percentage;

@end
