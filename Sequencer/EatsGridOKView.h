//
//  EatsGridOKView.h
//  Sequencer
//
//  Created by Mark Wheeler on 19/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridOKView;

@protocol EatsGridOKViewDelegateProtocol
- (void) eatsGridOKViewPressAt:(NSDictionary *)xyDown sender:(EatsGridOKView *)sender;
@end

@interface EatsGridOKView : EatsGridSubView

@property uint                  currentFrame;
@property uint                  trailLength; // Won't show past 15

@end
