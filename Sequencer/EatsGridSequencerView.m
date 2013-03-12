//
//  EatsGridSequencerView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerView.h"
#import "SequencerPage.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"
#import "EatsGridNavigationController.h"

@interface EatsGridSequencerView ()

@property SequencerPage     *page;

@property NSDictionary      *lastPressedKey;

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
        
        // Get the page
        NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
        pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == 0"];
        
        NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
        self.page = [pageMatches lastObject];

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
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            if(x == [self.page.currentStep intValue])
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:8] atIndex:y];
            else
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    noteRequest.predicate = [NSPredicate predicateWithFormat:@"inPattern == %@", [self.page.patterns objectAtIndex:0]];     // TODO
    
    NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
    for(SequencerNote *note in noteMatches) {
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
    
    NSNumber *x = [notification.userInfo valueForKey:@"x"];
    NSNumber *y = [notification.userInfo valueForKey:@"y"];
    
    // Down
    if([[notification.userInfo valueForKey:@"down"] boolValue]) {
        
        SequencerPattern *pattern = [self.page.patterns objectAtIndex:0];
        
        // See if there's a note there
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step == %@) AND (row == %@)", x, y]; //
        //noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %@) AND (row == %@)", [self.page.patterns objectAtIndex:0], x, y]; // TODO
        
        NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

        if( [noteMatches count] ) {
                        
            // Remove a note
            [self.managedObjectContext deleteObject:[noteMatches lastObject]];
            
        } else {
            
            // Add a note
            NSMutableSet *newNotesSet = [pattern.notes mutableCopy];
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
            newNote.step = x;
            newNote.row = y;
            [newNotesSet addObject:newNote];
            pattern.notes = newNotesSet;
            
        }
        
        [self updateView];
        
    // Release
    } else {
        
        // Check for double presses
        if(self.lastPressedKey
           && [[self.lastPressedKey valueForKey:@"time"] timeIntervalSinceNow] > -0.4
           && [[self.lastPressedKey valueForKey:@"x"] isEqualTo:x]
           && [[self.lastPressedKey valueForKey:@"y"] isEqualTo:y]) {
            
            // Tell the delegate we're done
            if([self.delegate respondsToSelector:@selector(showView:)])
                [self.delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridView_Play]];
            return;
            
        } else {
            // Log the last press
            self.lastPressedKey = [NSDictionary dictionaryWithObjectsAndKeys:x, @"x", y, @"y", [NSDate date], @"time", nil];
        }
    }
}

@end