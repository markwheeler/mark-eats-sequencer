//
//  EatsGridSequencerView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerView.h"
#import "SequencerNote.h"
#import "EatsGridNavigationController.h"

@interface EatsGridSequencerView ()

@property NSDictionary *lastPressedKey;

@end

@implementation EatsGridSequencerView

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
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    //request.predicate = [NSPredicate predicateWithFormat:@"inPattern IS 0"];
    
    NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:nil];
    for(SequencerNote *note in matches) {
        [[gridArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:[note.row intValue] withObject:[NSNumber numberWithInt:15]];
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
    

    if(![[notification.userInfo valueForKey:@"down"] boolValue]) {
        
        // Check for double presses
        if(self.lastPressedKey
           && [[self.lastPressedKey valueForKey:@"time"] timeIntervalSinceNow] > -0.4
           && [[self.lastPressedKey valueForKey:@"x"] isEqualTo:[notification.userInfo valueForKey:@"x"]]
           && [[self.lastPressedKey valueForKey:@"y"] isEqualTo:[notification.userInfo valueForKey:@"y"]]) {
            
            // Tell the delegate we're done
            if([self.delegate respondsToSelector:@selector(showView:)])
                [self.delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridView_Play]];
            
        }
        
        // Log the last press
        self.lastPressedKey = [NSDictionary dictionaryWithObjectsAndKeys:[notification.userInfo valueForKey:@"x"], @"x",
                                                                         [notification.userInfo valueForKey:@"y"], @"y",
                                                                         [NSDate date], @"time",
                                                                         nil];
    }
}

@end