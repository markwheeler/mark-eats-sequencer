//
//  EatsGridView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridView.h"
#import "EatsGridSubView.h"


@implementation EatsGridView

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        self.managedObjectContext = context;
        self.width = w;
        self.height = h;
        
        [self setupView];
        
        // Display and register for input
        [self updateView];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridInput:)
                                                     name:@"GridInput"
                                                   object:nil];
    }
    return self;
}

- (void) dealloc
{
    //[self stopAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) showView:(NSNumber *)gridView
{
    // Pass the message up
    if([self.delegate respondsToSelector:@selector(showView:)])
        [self.delegate performSelector:@selector(showView:) withObject:gridView];
}

- (void) setupView
{
    // Just for over-ride
}

- (void) updateView
{
    // Over-ride this
    
    // Displays all lights on
    
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15] atIndex:y];
        }
    }
    
    // Send msg to delegate
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

- (void) gridInput:(NSNotification *)notification
{
    // Ignore input if we're not active
    if( ![self.delegate performSelector:@selector(isActive)] )
        return;
    
    uint x = [[notification.userInfo valueForKey:@"x"] unsignedIntValue];
    uint y = [[notification.userInfo valueForKey:@"y"] unsignedIntValue];
    BOOL down = [[notification.userInfo valueForKey:@"down"] boolValue];
    
    // Pass the message down to the appropriate sub view
    
    BOOL foundSubView = NO;
    NSEnumerator *enumerator = [self.subViews objectEnumerator];
    EatsGridSubView *subView;
    
    while ( (subView = [enumerator nextObject]) && !foundSubView) {
        if(x >= subView.x && x < subView.x + subView.width && y >= subView.y && y < subView.y + subView.height && subView.visible) {
            [subView inputX:x - subView.x y:y - subView.y down:down];
            foundSubView = YES;
        }
    }
}

@end
