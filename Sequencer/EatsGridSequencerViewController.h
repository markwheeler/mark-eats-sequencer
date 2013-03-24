//
//  EatsGridSequencerViewController.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EatsGridView.h"
#import "EatsGridPatternView.h"
#import "EatsGridHorizontalSliderView.h"

@interface EatsGridSequencerViewController : EatsGridView <EatsGridSubViewDelegateProtocol, EatsGridPatternViewDelegateProtocol, EatsGridHorizontalSliderViewDelegateProtocol>

- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender;

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender;
- (void) eatsGridPatternViewDoublePressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender;

@end
