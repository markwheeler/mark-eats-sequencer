//
//  EatsGridSequencerViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerViewController.h"
#import "EatsGridNavigationController.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerNote.h"

#define ANIMATION_FRAMERATE 15
#define NOTE_EDIT_FADE_AMOUNT 6
#define DOUBLE_PRESS_TIME 0.4

@interface EatsGridSequencerViewController ()

@property SequencerPattern              *pattern;
@property SequencerNote                 *activeEditNote;
//@property NSDictionary                  *lastRemovedNoteInfo;
@property NSMutableArray                *lastPressedNotes;
@property uint                          lastX;
@property uint                          lastY;

@property EatsGridPatternView           *patternView;
@property EatsGridHorizontalSliderView  *velocityView;
@property EatsGridHorizontalSliderView  *lengthView;

@property NSTimer                       *animationTimer;
@property uint                          animationFrame;

@end

@implementation EatsGridSequencerViewController

- (void) setupView
{
    _lastPressedNotes = [NSMutableArray arrayWithCapacity:2];
    
    _pattern = [self.delegate valueForKey:@"pattern"];
    
    // Create the sub views
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.x = 0;
    _patternView.y = 0;
    _patternView.width = self.width;
    _patternView.height = self.height;
    _patternView.mode = EatsPatternViewMode_Edit;
    _patternView.doublePressTime = DOUBLE_PRESS_TIME;
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
    if( [note.row intValue] < 32 - ( self.height / 2 ) ) {
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

- (SequencerNote *) checkForNoteAtX:(uint)x y:(uint)y
{
    // See if there's a note there
    NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (row == %u)", _pattern, y + 32 - self.height];
    
    BOOL sortDirection = ( _pattern.inPage.playMode.intValue == EatsSequencerPlayMode_Reverse ) ? NO : YES;
    noteRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"step" ascending:sortDirection]];
    
    NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
    
    // Look through all the notes on the row, checking their length
    for( SequencerNote *note in noteMatches ) {
        int endPoint;
        
        // When in reverse
        if( _pattern.inPage.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
            endPoint = note.step.intValue - note.length.intValue + 1;
            
            // If it's wrapping
            if( endPoint < 0 && ( x <= note.step.intValue || x >= endPoint + self.width ) ) {
                return note;
            
            // If it's not wrapping
            } else if( x <= note.step.intValue && x >= endPoint ) {
                return note;
            }
            
        // When playing forwards
        } else {
            endPoint = note.step.intValue + note.length.intValue - 1;
            
            // If it's wrapping and we're going forwards
            if( endPoint >= self.width && ( x >= note.step.intValue || x <= endPoint - self.width ) ) {
                return note;
                
            // If it's not wrapping
            } else if( x >= note.step.intValue && x <= endPoint ) {
                return note;
            }
        }
    }
    
    // Return nil if we didn't find one
    return nil;
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
            
            SequencerNote *foundNote = [self checkForNoteAtX:x y:y];
            
            BOOL lastPressedIsOld = YES;
            if( _lastPressedNotes.lastObject && _lastPressedNotes.lastObject != [NSNull null]) {
                if( [[_lastPressedNotes.lastObject valueForKey:@"time"] timeIntervalSinceNow] > - DOUBLE_PRESS_TIME )
                    lastPressedIsOld = NO;
            }
            
            // TODO Sanity check this!
            
            if( foundNote ) {
                
                // Make a record of it first in case it's a double tap
                SequencerNote *lastNote = [NSDictionary dictionaryWithObjectsAndKeys:foundNote.step, @"step",
                                                                                  foundNote.row, @"row",
                                                                                  foundNote.velocityAsPercentage, @"velocityAsPercentage",
                                                                                  foundNote.length, @"length",
                                                                                  [NSDate date], @"time",
                                                                                  nil];
                [_lastPressedNotes addObject:lastNote];
                
                if( lastPressedIsOld || _lastX != x || _lastY != y )
                    [self.managedObjectContext deleteObject:foundNote];
                
            } else {

                if( lastPressedIsOld || _lastX != x || _lastY != y ) {
                    // Add a note
                    NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
                    SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                    newNote.step = [NSNumber numberWithUnsignedInt:x];
                    newNote.row = [NSNumber numberWithUnsignedInt:y + 32 - self.height];
                    [newNotesSet addObject:newNote];
                    _pattern.notes = newNotesSet;
                }
            
                [_lastPressedNotes addObject:[NSNull null]];
                
            }
            
            // Only keep track of the last two 'down' objects
            if( _lastPressedNotes.count > 2 )
                [_lastPressedNotes removeObjectAtIndex:0];
            
            [self updateView];
        }
        
    // Note edit mode
    } else if ( sender.mode == EatsPatternViewMode_NoteEdit ) {
        
        [self exitNoteEditMode];
       
    }
    
    _lastX = x;
    _lastY = y;
}

- (void) eatsGridPatternViewDoublePressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender
{
//    uint x = [[xy valueForKey:@"x"] unsignedIntValue];
//    uint y = [[xy valueForKey:@"y"] unsignedIntValue];
    
    if( sender.mode == EatsPatternViewMode_Edit ) {
        
        if( [_lastPressedNotes objectAtIndex:0] != [NSNull null] ) {
            
            // Put the old note back in
//            id lastPressed = ( _lastPressedNotes.count > 1 ) ? [_lastPressedNotes objectAtIndex:1] : [NSNull null];
//            SequencerNote *foundNote = [self checkForNoteAtX:x y:y];
//            if( foundNote && ( lastPressed == [NSNull null] || _lastX != x || _lastY != y ) )
//                [self.managedObjectContext deleteObject:foundNote];
            NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
            
            newNote.step = [[_lastPressedNotes objectAtIndex:0] valueForKey:@"step"];
            newNote.row = [[_lastPressedNotes objectAtIndex:0] valueForKey:@"row"];
            newNote.velocityAsPercentage = [[_lastPressedNotes objectAtIndex:0] valueForKey:@"velocityAsPercentage"];
            newNote.length = [[_lastPressedNotes objectAtIndex:0] valueForKey:@"length"];
            
            [newNotesSet addObject:newNote];
            _pattern.notes = newNotesSet;
//            _lastRemovedNoteInfo = nil;
            
            [self enterNoteEditModeFor:newNote];
            
        } else {
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }
        
    }
}

@end