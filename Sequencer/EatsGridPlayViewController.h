//
//  EatsGridPlayViewController.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EatsGridView.h"
#import "EatsGridButtonView.h"
#import "EatsGridHorizontalSelectionView.h"
#import "EatsGridPatternView.h"

@interface EatsGridPlayViewController : EatsGridView <EatsGridSubViewDelegateProtocol, EatsGridButtonViewDelegateProtocol, EatsGridHorizontalSelectionViewDelegateProtocol, EatsGridPatternViewDelegateProtocol>

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender;
- (void) eatsGridHorizontalSelectionViewUpdated:(EatsGridHorizontalSelectionView *)sender;
- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender;

@end