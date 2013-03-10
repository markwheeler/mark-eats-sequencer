//
//  EatsGridPlayView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPlayView.h"
#import "EatsGridNavigationController.h"

@implementation EatsGridPlayView

#pragma mark - Public methods

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        self.managedObjectContext = context;
        self.width = w;
        self.height = h;
        
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

- (void) updateView
{
    
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    // Put some buttons in
    [[gridArray objectAtIndex:self.width - 1] replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:15]];
    
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

- (void) gridInput:(NSNotification *)notification
{
    // Ignore input if we're not active
    if( ![self.delegate performSelector:@selector(isActive)] )
        return;
    
    // Top right corner button
    if(![[notification.userInfo valueForKey:@"down"] boolValue]
       && [[notification.userInfo valueForKey:@"x"] intValue] == self.width - 1
       && [[notification.userInfo valueForKey:@"y"] intValue] == 0) {
        // Tell the delegate we're done
        if([self.delegate respondsToSelector:@selector(showView:)])
            [self.delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridView_Sequencer]];
    }
}

@end
