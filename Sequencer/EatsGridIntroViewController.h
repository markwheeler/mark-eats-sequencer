//
//  EatsGridIntroViewController.h
//  Sequencer
//
//  Created by Mark Wheeler on 19/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridView.h"
#import "EatsGridOKView.h"

@interface EatsGridIntroViewController : EatsGridView <EatsGridSubViewDelegateProtocol, EatsGridOKViewDelegateProtocol>

- (void) eatsGridOKViewPressAt:(NSDictionary *)xyDown sender:(EatsGridOKView *)sender;
- (void) stopAnimation;

@end
