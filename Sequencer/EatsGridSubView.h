//
//  EatsGridSubView.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsGridSubView : NSObject


@property (weak) id                 delegate;

@property int                       x;
@property int                       y;
@property uint                      width;
@property uint                      height;
@property float                     opacity; // 0 - 1
@property BOOL                      visible;
@property BOOL                      enabled;

- (NSArray *) viewArray;
- (void) inputX:(uint)x y:(uint)y down:(BOOL)down;

@end
