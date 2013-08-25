//
//  EatsGridView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridView.h"
#import "EatsGridSubView.h"
#import "EatsGridUtils.h"


@implementation EatsGridView

- (id) initWithDelegate:(id)delegate andSequencer:(Sequencer *)sequencer width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _sequencer= sequencer;
        _width = w;
        _height = h;
        
        [self setupView];
        
        // Display and register for input
        [self updateView];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridInput:)
                                                     name:kInputGridNotification
                                                   object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) showView:(NSNumber *)gridView
{
    // Pass the message up
    if([_delegate respondsToSelector:@selector(showView:)])
        [_delegate performSelector:@selector(showView:) withObject:gridView];
}

- (void) setupView
{
    // Just for over-ride
}

- (void) updateView
{
    // Over-ride this
    
    // Generate and combine all the sub views

    NSArray *gridArray = [EatsGridUtils combineSubViews:_subViews gridWidth:_width gridHeight:_height];
    
    // Send msg to delegate
    if([_delegate respondsToSelector:@selector(updateGridWithArray:)])
        [_delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

- (void) gridInput:(NSNotification *)notification
{
    // Ignore input if we're not active
    if( ![_delegate performSelector:@selector(isActive)] )
        return;
    
    uint x = [[notification.userInfo valueForKey:@"x"] unsignedIntValue];
    uint y = [[notification.userInfo valueForKey:@"y"] unsignedIntValue];
    BOOL down = [[notification.userInfo valueForKey:@"down"] boolValue];
    
    // Pass the message down to the appropriate sub view
    
    BOOL foundSubView = NO;
    NSEnumerator *enumerator = [_subViews objectEnumerator];
    EatsGridSubView *subView;
    
    while ( (subView = [enumerator nextObject]) && !foundSubView) {
        if(x >= subView.x && x < subView.x + subView.width && y >= subView.y && y < subView.y + subView.height && subView.visible) {
            [subView inputX:x - subView.x y:y - subView.y down:down];
            foundSubView = YES;
        }
    }
}

@end
