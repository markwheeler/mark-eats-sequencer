//
//  EatsNSTextFieldWithDisabledColor.m
//  Sequencer
//
//  Created by Mark Wheeler on 16/09/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsNSTextFieldWithDisabledColor.h"

@implementation EatsNSTextFieldWithDisabledColor

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)setEnabled:(BOOL)flag
{
    [super setEnabled:flag];
    
    if (flag == NO) {
        [self setTextColor:[NSColor disabledControlTextColor]];
    } else {
        [self setTextColor:[NSColor controlTextColor]];
    }
}

@end
