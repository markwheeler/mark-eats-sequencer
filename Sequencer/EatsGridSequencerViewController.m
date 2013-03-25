//
//  EatsGridSequencerViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerViewController.h"
#import "EatsGridNavigationController.h"
#import "SequencerPage.h"
#import "SequencerNote.h"

#define ANIMATION_FRAMERATE 15
#define NOTE_EDIT_FADE_AMOUNT 6

@interface EatsGridSequencerViewController ()

@property SequencerPage                 *page;
@property SequencerPattern              *pattern;
@property SequencerNote                 *activeEditNote;
@property NSDictionary                  *lastRemovedNoteInfo;

@property EatsGridPatternView           *patternView;
@property EatsGridHorizontalSliderView  *velocityView;
@property EatsGridHorizontalSliderView  *lengthView;

@property NSTimer                       *animationTimer;
@property uint                          animationFrame;

@end

@implementation EatsGridSequencerViewController

- (void) setupView
{

    // Get the page
    NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
    pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == 0"];
    
    NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
    self.page = [pageMatches lastObject];
    
    // Get the pattern
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"(inPage == %@) AND (id == 0)", self.page];
    
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
    self.pattern = [patternMatches lastObject];
    
    // Create the sub views
    self.patternView = [[EatsGridPatternView alloc] init];
    self.patternView.delegate = self;
    self.patternView.x = 0;
    self.patternView.y = 0;
    self.patternView.width = self.width;
    self.patternView.height = self.height;
    self.patternView.mode = EatsPatternViewMode_Edit;
    self.patternView.pattern = self.pattern;
    self.patternView.patternHeight = self.height;
    
    self.velocityView = [[EatsGridHorizontalSliderView alloc] init];
    self.velocityView.delegate = self;
    self.velocityView.x = 0;
    self.velocityView.y = 0;
    self.velocityView.width = self.width;
    self.velocityView.height = 1;
    self.velocityView.fillBar = YES;
    self.velocityView.visible = NO;
    
    self.lengthView = [[EatsGridHorizontalSliderView alloc] init];
    self.lengthView.delegate = self;
    self.lengthView.x = 0;
    self.lengthView.y = 1;
    self.lengthView.width = self.width;
    self.lengthView.height = 1;
    self.lengthView.fillBar = YES;
    self.lengthView.visible = NO;
    
    self.subViews = [[NSSet alloc] initWithObjects:self.patternView,
                                                          self.velocityView,
                                                          self.lengthView,
                                                          nil];
}

- (void) enterNoteEditModeFor:(SequencerNote *)note
{
    if( self.animationTimer ) return;
    self.animationFrame = 0;
    
    // Display sliders at bottom
    if( [note.row intValue] < self.height / 2 ) {
        self.patternView.foldFrom = EatsPatternViewFoldFrom_Bottom;
        self.velocityView.y = self.height - 1;
        self.velocityView.visible = YES;

    // Display sliders at top
    } else {
        self.patternView.foldFrom = EatsPatternViewFoldFrom_Top;
        self.patternView.y = 1;
        self.lengthView.y = 0;
        self.lengthView.visible = YES;
    }
    
    self.patternView.height = self.height - 1;
    self.patternView.activeEditNote = note;
    self.patternView.mode = EatsPatternViewMode_NoteEdit;
    
    self.patternView.noteBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    self.patternView.noteLengthBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    
    self.activeEditNote = note;
    
    float stepPercentage = ( 100.0 / self.velocityView.width );
    self.velocityView.percentage = ( ( [note.velocityAsPercentage floatValue] - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
    stepPercentage = ( 100.0 / self.lengthView.width );
    self.lengthView.percentage = ( ( [note.lengthAsPercentage floatValue] - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
    
    [self updateView];
    
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateInNoteEditMode:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) exitNoteEditMode
{
    if( self.animationTimer ) return;
    self.animationFrame = 0;
    
    // To bottom
    if( self.patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
        
        self.velocityView.y ++;
        self.lengthView.visible = NO;
        
    // To top
    } else {
        
        self.patternView.y --;
        self.velocityView.visible = NO;
        self.lengthView.y --;
        
    }
    
    self.patternView.height = self.height - 1;
    
    self.patternView.noteBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    self.patternView.noteLengthBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    
    [self updateView];
    
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateOutNoteEditMode:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) animateInNoteEditMode:(NSTimer *)timer
{
    self.animationFrame ++;
    
    // From bottom
    if( self.patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {

        self.velocityView.y --;
        self.lengthView.y = self.height - 1;
        self.lengthView.visible = YES;

    // From top
    } else {
        
        self.patternView.y ++;
        self.velocityView.y = 0;
        self.lengthView.y ++;
        self.velocityView.visible = YES;
        
    }
    
    self.patternView.height --;
    
    self.patternView.noteBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    self.patternView.noteLengthBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    
    [self updateView];
    
    if( self.animationFrame == 1 ) { // Final frame
        [timer invalidate];
        self.animationTimer = nil;
    }
}

- (void) animateOutNoteEditMode:(NSTimer *)timer
{
    self.animationFrame ++;
    
    // To bottom
    if( self.patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
        
        self.velocityView.visible = NO;
        
    // To top
    } else {
        
        self.patternView.y --;
        self.lengthView.visible = NO;
        
    }
    
    self.patternView.height ++;
    
    self.patternView.noteBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    self.patternView.noteLengthBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    
    self.patternView.activeEditNote = nil;
    self.patternView.mode = EatsPatternViewMode_Edit;
    
    self.activeEditNote = nil;
    
    [self updateView];

    if( self.animationFrame == 1 ) { // Final frame
        [timer invalidate];
        self.animationTimer = nil;
    }
}

- (void) updateView
{
    // Update PatternView sub view
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", self.pattern];
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];

    self.patternView.pattern = [patternMatches lastObject];
    self.patternView.currentStep = [self.page.currentStep unsignedIntValue];
    
    [super updateView];
}



#pragma mark - Sub view delegate methods

// Both sliders
- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender
{
    // Velocity
    if(sender == self.velocityView) {
        self.activeEditNote.velocityAsPercentage = [NSNumber numberWithFloat:(100.0 - (100.0 / sender.width) ) * (sender.percentage / 100.0) + (100.0 / sender.width)];
        NSLog(@"Velocity %@", self.activeEditNote.velocityAsPercentage);
    
    // Length
    } else if(sender == self.lengthView) {
        self.activeEditNote.lengthAsPercentage = [NSNumber numberWithFloat:(100.0 - (100.0 / sender.width) ) * (sender.percentage / 100.0) + (100.0 / sender.width)];
        //NSLog(@"Length %@", self.activeEditNote.lengthAsPercentage);
    }
    
    [self updateView];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    uint y = [[xyDown valueForKey:@"y"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    // Edit mode
    if( sender.mode == EatsPatternViewMode_Edit ) {
       
        if( down ) {
            
            // See if there's a note there
            NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
            noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", self.pattern, x, y];

            NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

            if( [noteMatches count] ) {

                // Remove a note
                SequencerNote *noteToRemove = [noteMatches lastObject];
                
                // Make a record of it first in case it's a double tap
                self.lastRemovedNoteInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"step",
                                                                                      [NSNumber numberWithUnsignedInt:y], @"row",
                                                                                      noteToRemove.velocityAsPercentage, @"velocityAsPercentage",
                                                                                      noteToRemove.lengthAsPercentage, @"lengthAsPercentage",
                                                                                      nil];
                
                [self.managedObjectContext deleteObject:[noteMatches lastObject]];

            } else {

                // Add a note
                NSMutableSet *newNotesSet = [self.pattern.notes mutableCopy];
                SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                newNote.step = [NSNumber numberWithUnsignedInt:x];
                newNote.row = [NSNumber numberWithUnsignedInt:y];
                newNote.lengthAsPercentage = [NSNumber numberWithFloat:100.0 / self.width];
                [newNotesSet addObject:newNote];
                self.pattern.notes = newNotesSet;
                
            }

            [self updateView];
        }
        
    // Note edit mode
    } else if ( sender.mode == EatsPatternViewMode_NoteEdit ) {
        
        [self exitNoteEditMode];
       
    }
}

- (void) eatsGridPatternViewDoublePressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender
{
    uint x = [[xy valueForKey:@"x"] unsignedIntValue];
    uint y = [[xy valueForKey:@"y"] unsignedIntValue];
    
    if( sender.mode == EatsPatternViewMode_Edit ) {
        
        // See if there's a note there
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", self.pattern, x, y];

        NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

        if( [noteMatches count] && self.lastRemovedNoteInfo ) {
            
            // Put the old note back in
            [self.managedObjectContext deleteObject:[noteMatches lastObject]];
            NSMutableSet *newNotesSet = [self.pattern.notes mutableCopy];
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
            
            newNote.step = [self.lastRemovedNoteInfo valueForKey:@"step"];
            newNote.row = [self.lastRemovedNoteInfo valueForKey:@"row"];
            newNote.velocityAsPercentage = [self.lastRemovedNoteInfo valueForKey:@"velocityAsPercentage"];
            newNote.lengthAsPercentage = [self.lastRemovedNoteInfo valueForKey:@"lengthAsPercentage"];
            
            [newNotesSet addObject:newNote];
            self.pattern.notes = newNotesSet;
            self.lastRemovedNoteInfo = nil;
            
            [self enterNoteEditModeFor:newNote];
            
        } else {
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }
        
    }
}

@end