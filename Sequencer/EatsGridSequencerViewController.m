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

@interface EatsGridSequencerViewController ()

@property SequencerPage                 *page;
@property SequencerPattern              *pattern;
@property SequencerNote                 *activeEditNote;

@property EatsGridPatternView           *patternView;
@property EatsGridHorizontalSliderView  *velocityView;
@property EatsGridHorizontalSliderView  *lengthView;

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
    self.velocityView.visible = NO;
    
    self.lengthView = [[EatsGridHorizontalSliderView alloc] init];
    self.lengthView.delegate = self;
    self.lengthView.x = 0;
    self.lengthView.y = 1;
    self.lengthView.width = self.width;
    self.lengthView.height = 1;
    self.lengthView.visible = NO;
    
    self.subViews = [[NSSet alloc] initWithObjects:self.patternView,
                                                          self.velocityView,
                                                          self.lengthView,
                                                          nil];
}

- (void) enterNoteEditModeFor:(SequencerNote *)note
{
    // Display sliders at bottom
    if( [note.row intValue] < self.height / 2 ) {
        self.patternView.foldFrom = EatsPatternViewFoldFrom_Bottom;
        self.velocityView.y = self.height - 2;
        self.lengthView.y = self.height - 1;

    // Display sliders at top
    } else {
        self.patternView.foldFrom = EatsPatternViewFoldFrom_Top;
        self.patternView.y = 2;
        self.velocityView.y = 0;
        self.lengthView.y = 1;
    }
    
    self.velocityView.visible = YES;
    self.lengthView.visible = YES;
    
    self.patternView.height = self.height - 2;
    self.patternView.activeEditNote = note;
    self.patternView.mode = EatsPatternViewMode_NoteEdit;
    
    self.activeEditNote = note;
    self.velocityView.percentage = ([note.velocity floatValue] / 127) * 100;
    self.lengthView.percentage = [note.lengthAsPercentage floatValue];
    
    [self updateView];
}

- (void) exitNoteEditMode
{
    self.velocityView.visible = NO;
    self.lengthView.visible = NO;
    
    self.patternView.y = 0;
    self.patternView.height = self.height;
    self.patternView.activeEditNote = nil;
    self.patternView.mode = EatsPatternViewMode_Edit;
    
    self.activeEditNote = nil;
    
    [self updateView];
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
        self.activeEditNote.velocity = [NSNumber numberWithInt: (127 - (127 / sender.width) ) * (sender.percentage / 100) + (127 / sender.width) ];
        NSLog(@"velocity %@", self.activeEditNote.velocity);
    
    // Length
    } else if(sender == self.lengthView) {
        self.activeEditNote.lengthAsPercentage = [NSNumber numberWithFloat:(100 - (100 / sender.width) ) * (sender.percentage / 100) + (100 / sender.width)];
        NSLog(@"length %@", self.activeEditNote.lengthAsPercentage);
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

        if( [noteMatches count] ) {
            [self enterNoteEditModeFor:[noteMatches lastObject]];
        } else {
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }
        
    }
}

@end