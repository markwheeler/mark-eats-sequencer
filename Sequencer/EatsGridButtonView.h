//
//  EatsGridButtonView.h
//  Sequencer
//
//  Created by Mark Wheeler on 23/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridButtonView;

@protocol EatsGridButtonViewDelegateProtocol
- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender;
@end

typedef enum EatsButtonViewState {
    EatsButtonViewState_Inactive,
    EatsButtonViewState_Down,
    EatsButtonViewState_Active
} EatsButtonViewState;

@interface EatsGridButtonView : EatsGridSubView

@property EatsButtonViewState   buttonState;

@property uint                  inactiveBrightness; // 0 - 15
@property uint                  downBrightness; // 0 - 15
@property uint                  activeBrightness; // 0 - 15

@end
