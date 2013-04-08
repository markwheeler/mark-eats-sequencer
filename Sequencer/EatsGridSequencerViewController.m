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
    _pattern = [self.delegate valueForKey:@"pattern"];
    
    // Create the sub views
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.x = 0;
    _patternView.y = 0;
    _patternView.width = self.width;
    _patternView.height = self.height;
    _patternView.mode = EatsPatternViewMode_Edit;
    _patternView.pattern = _pattern;
    _patternView.patternHeight = self.height;
    
    _velocityView = [[EatsGridHorizontalSliderView alloc] init];
    _velocityView.delegate = self;
    _velocityView.x = 0;
    _velocityView.y = 0;
    _velocityView.width = self.width;
    _velocityView.height = 1;
    _velocityView.fillBar = YES;
    _velocityView.visible = NO;
    
    _lengthView = [[EatsGridHorizontalSliderView alloc] init];
    _lengthView.delegate = self;
    _lengthView.x = 0;
    _lengthView.y = 1;
    _lengthView.width = self.width;
    _lengthView.height = 1;
    _lengthView.fillBar = YES;
    _lengthView.visible = NO;
    
    self.subViews = [[NSMutableSet alloc] initWithObjects:_patternView,
                                                          _velocityView,
                                                          _lengthView,
                                                          nil];
}

- (void) enterNoteEditModeFor:(SequencerNote *)note
{
    if( _animationTimer ) return;
    _animationFrame = 0;
    
    // Display sliders at bottom
    if( [note.row intValue] < self.height / 2 ) {
        _patternView.foldFrom = EatsPatternViewFoldFrom_Bottom;
        _velocityView.y = self.height - 1;
        _velocityView.visible = YES;

    // Display sliders at top
    } else {
        _patternView.foldFrom = EatsPatternViewFoldFrom_Top;
        _patternView.y = 1;
        _lengthView.y = 0;
        _lengthView.visible = YES;
    }
    
    _patternView.height = self.height - 1;
    _patternView.activeEditNote = note;
    _patternView.mode = EatsPatternViewMode_NoteEdit;
    
    _patternView.noteBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    _patternView.noteLengthBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    
    _activeEditNote = note;
    
    float stepPercentage = ( 100.0 / _velocityView.width );
    _velocityView.percentage = ( ( note.velocityAsPercentage.floatValue - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
    _lengthView.percentage =     ( ( ( ( note.length.floatValue / _lengthView.width )  * 100.0) - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
    
    [self updateView];
    
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateInNoteEditMode:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) exitNoteEditMode
{
    if( _animationTimer ) return;
    _animationFrame = 0;
    
    // To bottom
    if( _patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
        
        _velocityView.y ++;
        _lengthView.visible = NO;
        
    // To top
    } else {
        
        _patternView.y --;
        _velocityView.visible = NO;
        _lengthView.y --;
        
    }
    
    _patternView.height = self.height - 1;
    
    _patternView.noteBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    _patternView.noteLengthBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    
    [self updateView];
    
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateOutNoteEditMode:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) animateInNoteEditMode:(NSTimer *)timer
{
    _animationFrame ++;
    
    // From bottom
    if( _patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {

        _velocityView.y --;
        _lengthView.y = self.height - 1;
        _lengthView.visible = YES;

    // From top
    } else {
        
        _patternView.y ++;
        _velocityView.y = 0;
        _lengthView.y ++;
        _velocityView.visible = YES;
        
    }
    
    _patternView.height --;
    
    _patternView.noteBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    _patternView.noteLengthBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
    
    [self updateView];
    
    if( _animationFrame == 1 ) { // Final frame
        [timer invalidate];
        _animationTimer = nil;
    }
}

- (void) animateOutNoteEditMode:(NSTimer *)timer
{
    _animationFrame ++;
    
    // To bottom
    if( _patternView.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
        
        _velocityView.visible = NO;
        
    // To top
    } else {
        
        _patternView.y --;
        _lengthView.visible = NO;
        
    }
    
    _patternView.height ++;
    
    _patternView.noteBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    _patternView.noteLengthBrightness += NOTE_EDIT_FADE_AMOUNT / 2;
    
    _patternView.activeEditNote = nil;
    _patternView.mode = EatsPatternViewMode_Edit;
    
    _activeEditNote = nil;
    
    [self updateView];

    if( _animationFrame == 1 ) { // Final frame
        [timer invalidate];
        _animationTimer = nil;
    }
}

- (void) updateView
{
    // Update PatternView sub view
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", _pattern];
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];

    _patternView.pattern = [patternMatches lastObject];
    _patternView.currentStep = [_pattern.inPage.currentStep unsignedIntValue];
    
    [super updateView];
}



#pragma mark - Sub view delegate methods

// Both sliders
- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender
{
    // Velocity
    if(sender == _velocityView) {
        _activeEditNote.velocityAsPercentage = [NSNumber numberWithFloat:(100.0 - (100.0 / sender.width) ) * (sender.percentage / 100.0) + (100.0 / sender.width)];
        //NSLog(@"Velocity %@", _activeEditNote.velocityAsPercentage);
    
    // Length
    } else if(sender == _lengthView) {
        _activeEditNote.length = [NSNumber numberWithInt:roundf( ( sender.width - 1 ) * ( sender.percentage / 100.0 ) ) + 1 ];
        //NSLog(@"Percentage %f Length %@", sender.percentage, _activeEditNote.length);
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
            noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", _pattern, x, y + 32 - self.height];

            NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

            // TODO make it so that notes under the trails of others are hidden and non-interactive
            
            if( [noteMatches count] ) {

                // Remove a note
                SequencerNote *noteToRemove = [noteMatches lastObject];
                
                // Make a record of it first in case it's a double tap
                _lastRemovedNoteInfo = [NSDictionary dictionaryWithObjectsAndKeys:noteToRemove.step, @"step",
                                                                                  noteToRemove.row, @"row",
                                                                                  noteToRemove.velocityAsPercentage, @"velocityAsPercentage",
                                                                                  noteToRemove.length, @"length",
                                                                                  nil];
                
                [self.managedObjectContext deleteObject:[noteMatches lastObject]];

            } else {

                // Add a note
                NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
                SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                newNote.step = [NSNumber numberWithUnsignedInt:x];
                newNote.row = [NSNumber numberWithUnsignedInt:y + 32 - self.height];
                [newNotesSet addObject:newNote];
                _pattern.notes = newNotesSet;
                
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
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", _pattern, x, y + 32 - self.height];

        NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

        if( [noteMatches count] && _lastRemovedNoteInfo ) {
            
            // Put the old note back in
            [self.managedObjectContext deleteObject:[noteMatches lastObject]];
            NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
            
            newNote.step = [_lastRemovedNoteInfo valueForKey:@"step"];
            newNote.row = [_lastRemovedNoteInfo valueForKey:@"row"];
            newNote.velocityAsPercentage = [_lastRemovedNoteInfo valueForKey:@"velocityAsPercentage"];
            newNote.length = [_lastRemovedNoteInfo valueForKey:@"length"];
            
            [newNotesSet addObject:newNote];
            _pattern.notes = newNotesSet;
            _lastRemovedNoteInfo = nil;
            
            [self enterNoteEditModeFor:newNote];
            
        } else {
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }
        
    }
}

@end