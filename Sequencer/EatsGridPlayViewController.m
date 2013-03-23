//
//  EatsGridPlayViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPlayViewController.h"
#import "SequencerPage.h"
#import "SequencerNote.h"
#import "EatsGridNavigationController.h"

@implementation EatsGridPlayViewController

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

- (void) showView:(NSNumber *)gridView
{
    // Pass the message up
    if([self.delegate respondsToSelector:@selector(showView:)])
        [self.delegate performSelector:@selector(showView:) withObject:gridView];
}

- (void) updateView
{
    
    NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
    pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == 0"];
    
    NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
    SequencerPage *page = [pageMatches lastObject];
    
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            if(x >= [page.loopStart intValue] && x <= [page.loopEnd intValue] && y == self.height / 2 - 1)
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15] atIndex:y];
            else if(x == [page.currentStep intValue] && y > self.height / 2 - 1)
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:8] atIndex:y];
            else
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    noteRequest.predicate = [NSPredicate predicateWithFormat:@"inPattern == %@", [page.patterns objectAtIndex:0]];
    
    NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
    for(SequencerNote *note in noteMatches) {
        [[gridArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:floor([note.row intValue] / 2) + self.height / 2 withObject:[NSNumber numberWithInt:15]];
    }
    
    // Put some buttons in
    [[gridArray objectAtIndex:self.width - 1] replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:8]]; // Exit
    [[gridArray objectAtIndex:self.width - 2] replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:8]]; // Clear
    
    // Send msg to delegate
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
            [self.delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
    }
}

@end
