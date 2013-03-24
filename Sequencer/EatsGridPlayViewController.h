//
//  EatsGridPlayViewController.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EatsGridView.h"
#import "EatsGridPatternView.h"
#import "EatsGridButtonView.h"

@interface EatsGridPlayViewController : EatsGridView <EatsGridSubViewDelegateProtocol, EatsGridPatternViewDelegateProtocol, EatsGridButtonViewDelegateProtocol>

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender;
- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender;

@end
