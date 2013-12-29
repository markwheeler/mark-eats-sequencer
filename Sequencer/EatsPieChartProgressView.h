//
//  EatsPieChartProgressView.h
//  Sequencer
//
//  Created by Mark Wheeler on 29/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EatsPieChartProgressView : NSView

@property float     progress; // 0-1
@property NSColor   *activeSliceColor;
@property NSColor   *inactiveSliceColor;

@end
