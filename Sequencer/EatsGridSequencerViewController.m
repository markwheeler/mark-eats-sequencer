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
@property NSMutableArray                *lastTwoPresses;
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
    _lastTwoPresses = [NSMutableArray arrayWithCapacity:2];
    
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



#pragma mark - Private methods

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
    // The logic in this function is kind of messy given how complex it is to know when a user is double pressing vs adding/removing
    
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    uint y = [[xyDown valueForKey:@"y"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
    
        // Edit mode
        if( sender.mode == EatsPatternViewMode_Edit ) {
                
                // We check if the last press was a note and if it is a note, if it was pressed a while ago or recently
                BOOL lastPressedIsOld = YES;
                if( _lastTwoPresses.lastObject && [[_lastTwoPresses.lastObject valueForKey:@"type"] isEqualToString:@"note"]) {
                    if( [[_lastTwoPresses.lastObject valueForKey:@"time"] timeIntervalSinceNow] > - DOUBLE_PRESS_TIME )
                        lastPressedIsOld = NO;
                }
                
                // See if we have a note there
                SequencerNote *foundNote = [self checkForNoteAtX:x y:y];
                
                if( foundNote ) {
                    
                    // Make a record of it first for keeping track of double taps
                    SequencerNote *lastNote = [NSDictionary dictionaryWithObjectsAndKeys:@"note", @"type",
                                                                                         foundNote.step, @"step",
                                                                                         foundNote.row, @"row",
                                                                                         foundNote.velocityAsPercentage, @"velocityAsPercentage",
                                                                                         foundNote.length, @"length",
                                                                                         [NSDate date], @"time",
                                                                                         nil];
                    [_lastTwoPresses addObject:lastNote];
                    
                    // If we're not in a double press remove the note (ie, the last note is recent, or we're in a different place on the grid)
                    if( lastPressedIsOld || _lastX != x || _lastY != y )
                        [self.managedObjectContext deleteObject:foundNote];
                    
                } else {
                    
                    // If we're not in a double press then add a new note
                    if( lastPressedIsOld || _lastX != x || _lastY != y ) {
                        
                        NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
                        SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                        newNote.step = [NSNumber numberWithUnsignedInt:x];
                        newNote.row = [NSNumber numberWithUnsignedInt:y + 32 - self.height];
                        [newNotesSet addObject:newNote];
                        _pattern.notes = newNotesSet;
                    }
                    
                    // Make a record that we pressed an empty point on the grid
                    [_lastTwoPresses addObject:[NSDictionary dictionaryWithObject:@"none" forKey:@"type"]];
                    
                }
            
                [self updateView];
            
        // Note edit mode
        } else if ( sender.mode == EatsPatternViewMode_NoteEdit ) {
            
            // Keep track of presses to exit edit mode so that we don't trigger another view change if you double press to exit
            [_lastTwoPresses addObject:[NSDictionary dictionaryWithObject:@"editMode" forKey:@"type"]];
            [self exitNoteEditMode];
           
        }
        
        // Keep track of this for detecting when we're in the middle of a double press
        _lastX = x;
        _lastY = y;
            
        // Only keep track of the last two pressed objects
        if( _lastTwoPresses.count > 2 )
            [_lastTwoPresses removeObjectAtIndex:0];

        //NSLog(@"%@", _lastTwoPresses);
        
    }


    
}

- (void) eatsGridPatternViewDoublePressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender
{
    
    if( sender.mode == EatsPatternViewMode_Edit ) {
        
        // Check to see if we have a note to put back
        if( [[[_lastTwoPresses objectAtIndex:0] valueForKey:@"type"] isEqualToString:@"note"] ) {
            
            // Put the old note back in
            NSMutableSet *newNotesSet = [_pattern.notes mutableCopy];
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
            
            newNote.step = [[_lastTwoPresses objectAtIndex:0] valueForKey:@"step"];
            newNote.row = [[_lastTwoPresses objectAtIndex:0] valueForKey:@"row"];
            newNote.velocityAsPercentage = [[_lastTwoPresses objectAtIndex:0] valueForKey:@"velocityAsPercentage"];
            newNote.length = [[_lastTwoPresses objectAtIndex:0] valueForKey:@"length"];
            
            [newNotesSet addObject:newNote];
            _pattern.notes = newNotesSet;
            
            [self enterNoteEditModeFor:newNote];
        
        // If not then we enter the other view
        } else if( [[[_lastTwoPresses objectAtIndex:0] valueForKey:@"type"] isEqualToString:@"none"] ) {
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }
        
    }
}

@end