//
//  EatsGridHorizontalSelectionView.h
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@class EatsGridHorizontalSelectionView;

@protocol EatsGridHorizontalSelectionViewDelegateProtocol
- (void) eatsGridHorizontalSelectionViewUpdated:(EatsGridHorizontalSelectionView *)sender;
@end

@interface EatsGridHorizontalSelectionView : EatsGridSubView

@property float     startPercentage;
@property float     endPercentage;

@property BOOL      fillBar;

@end