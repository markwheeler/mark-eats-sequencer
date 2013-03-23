//
//  EatsGridPatternView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPatternView.h"
#import "SequencerNote.h"
#import "EatsGridNavigationController.h"


@interface EatsGridPatternView ()

@property NSDictionary          *lastPressedKey;
@property uint                  playheadBrightness;
@property uint                  noteBrightness;
@property uint                  noteLengthBrightness;

@end

@implementation EatsGridPatternView

@synthesize mode = _mode;

- (EatsPatternViewMode ) mode
{
    return _mode;
}

- (void) setMode:(EatsPatternViewMode)mode
{
    _mode = mode;
    if( mode == EatsPatternViewMode_NoteEdit ) {
        self.playheadBrightness = 8;
        self.noteBrightness = 10;
        self.noteLengthBrightness = 8;
    } else {
        self.playheadBrightness = 8;
        self.noteBrightness = 15;
        self.noteLengthBrightness = 10;
    }
}



- (id) init
{
    self = [super init];
    if (self) {
        self.playheadBrightness = 8;
        self.noteBrightness = 10;
        self.noteLengthBrightness = 8;
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            if(x == self.currentStep)
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:8 * self.opacity] atIndex:y];
            else
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    noteRequest.predicate = [NSPredicate predicateWithFormat:@"inPattern == %@", self.pattern];
    NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
    
    for(SequencerNote *note in noteMatches) {
        if( [note.step intValue] < self.width && [note.row intValue] < self.height )
            [[viewArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:[note.row intValue] withObject:[NSNumber numberWithInt:15 * self.opacity]];
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Edit sequence mode
    if( self.mode == EatsPatternViewMode_Edit ) {
    
        // Down
        if( down ) {
            
            // See if there's a note there
            NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
            noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", self.pattern, x, y];

            NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
            
            if( [noteMatches count] ) {
                
                // Remove a note
                [self.managedObjectContext deleteObject:[noteMatches lastObject]];
                
            } else {
                
                // Add a note
                NSMutableSet *newNotesSet = [self.pattern.notes mutableCopy];
                SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                newNote.step = [NSNumber numberWithUnsignedInt:x];
                newNote.row = [NSNumber numberWithUnsignedInt:y];
                [newNotesSet addObject:newNote];
                self.pattern.notes = newNotesSet;
                
            }
            
            if([self.delegate respondsToSelector:@selector(updateView)])
                [self.delegate performSelector:@selector(updateView)];
        
        // Release
        } else {
        
            // Check for double presses
            if(self.lastPressedKey
               && [[self.lastPressedKey valueForKey:@"time"] timeIntervalSinceNow] > -0.4
               && [[self.lastPressedKey valueForKey:@"x"] intValue] == x
               && [[self.lastPressedKey valueForKey:@"y"] intValue] == y) {
                
                // See if there's a note there
                NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
                noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", self.pattern, x, y];
                
                NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
                
                if( [noteMatches count] ) {
                    if([self.delegate respondsToSelector:@selector(enterNoteEditMode)])
                        [self.delegate performSelector:@selector(enterNoteEditMode)];
                    return;
                } else {
                    if([self.delegate respondsToSelector:@selector(showView:)])
                        [self.delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridViewType_Play]];
                    return;
                }
                
            } else {
                // Log the last press
                self.lastPressedKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", [NSDate date], @"time", nil];
            }
            
        }
        
    // Edit note mode
    } else if( self.mode == EatsPatternViewMode_NoteEdit ) {
        // Down
        if( down ) {
            if([self.delegate respondsToSelector:@selector(exitNoteEditMode)])
                [self.delegate performSelector:@selector(exitNoteEditMode)];
            return;
        }
        
    // Play mode
    } else if( self.mode == EatsPatternViewMode_Play ) {
        // Down
        if( down ) {
            // Scrub
        }
    }
}


@end
