//
//  EatsNSTableCellViewLightBackground.m
//  Sequencer
//
//  Created by Mark Wheeler on 25/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsNSTableCellViewLightBackground.h"

@implementation EatsNSTableCellViewLightBackground

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle: NSBackgroundStyleLight];
}

- (void) removeAutomationButtonClick:(NSDictionary *)automationType {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"removeAutomationButtonClickedNotification" object:automationType];
}

@end
