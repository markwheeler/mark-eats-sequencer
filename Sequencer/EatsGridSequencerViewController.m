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
#import "SequencerState.h"
#import "SequencerPageState.h"
#import "Preferences.h"

#define ANIMATION_FRAMERATE 15
#define NOTE_EDIT_FADE_AMOUNT 6

@interface EatsGridSequencerViewController ()

@property Preferences                   *sharedPreferences;

@property SequencerPattern              *pattern;
@property SequencerState                *sequencerState;
@property SequencerNote                 *activeEditNote;
@property BOOL                          lastDownWasInEditMode;

@property EatsGridPatternView           *patternView;
@property EatsGridHorizontalSliderView  *velocityView;
@property EatsGridHorizontalSliderView  *lengthView;

@property NSTimer                       *animationTimer;
@property uint                          animationFrame;

@end

@implementation EatsGridSequencerViewController

- (void) setupView
{
    _sharedPreferences = [Preferences sharedPreferences];
    
    _sequencerState = [self.delegate valueForKey:@"sequencerState"];
    _pattern = [self.delegate valueForKey:@"currentPattern"];
    
    // Create the sub views
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.x = 0;
    _patternView.y = 0;
    _patternView.width = self.width;
    _patternView.height = self.height;
    _patternView.mode = EatsPatternViewMode_Edit;
    _patternView.managedObjectContext = self.managedObjectContext;
    _patternView.sequencerState = _sequencerState;
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
    if( _patternView.mode == EatsPatternViewMode_Locked ) return;
    
    _patternView.mode = EatsPatternViewMode_Locked;
    
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        _animationFrame = 0;
        
        __block int noteRow;
        __block int noteVelocity;
        __block float noteLength;
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            noteRow = note.row.intValue;
            noteVelocity = note.velocity.intValue;
            noteLength = note.length.floatValue;
        }];
        
        // Display sliders at bottom
        if( noteRow > ( self.height / 2 ) - 1 ) {
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
        
        _patternView.noteBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
        _patternView.noteLengthBrightness -= NOTE_EDIT_FADE_AMOUNT / 2;
        
        _activeEditNote = note;
        
        
        // Set sliders
        
        float oneStepOf127 = 127.0  / _velocityView.width;
        float range = 127.0 - oneStepOf127;
        
        float percentageForVelocitySlider = 100.0 * ( (noteVelocity - oneStepOf127 ) / range );
        if( percentageForVelocitySlider < 0 )
            percentageForVelocitySlider = 0;
        
        //NSLog(@"Percentage for slider %f velocity %i", percentageForVelocitySlider, noteVelocity);
        _velocityView.percentage = percentageForVelocitySlider;
        
        float stepPercentage = ( 100.0 / _velocityView.width );
        _lengthView.percentage = ( ( ( ( noteLength / _lengthView.width )  * 100.0) - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
        
    });
    
    [self updateView];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateInNoteEditMode:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_animationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_animationTimer forMode: NSEventTrackingRunLoopMode];
        
    });
}

- (void) exitNoteEditMode
{
    if( _patternView.mode == EatsPatternViewMode_Locked ) return;
    
    _patternView.mode = EatsPatternViewMode_Locked;
    
    dispatch_async(self.bigSerialQueue, ^(void) {
    
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
        
    });
    
    [self updateView];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
    
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_FRAMERATE
                                                               target:self
                                                             selector:@selector(animateOutNoteEditMode:)
                                                             userInfo:nil
                                                              repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_animationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_animationTimer forMode: NSEventTrackingRunLoopMode];
        
    });
}

- (void) animateInNoteEditMode:(NSTimer *)timer
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
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
        
        if( _animationFrame == 1 ) { // Final frame

            _patternView.mode = EatsPatternViewMode_NoteEdit;
            
            [timer invalidate];
            _animationTimer = nil;
        }
        
    });
    
    [self updateView];

}

- (void) animateOutNoteEditMode:(NSTimer *)timer
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
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
        
        if( _animationFrame == 1 ) { // Final frame
            
            _patternView.activeEditNote = nil;
            _patternView.mode = EatsPatternViewMode_Edit;
            
            _activeEditNote = nil;

            
            [timer invalidate];
            _animationTimer = nil;
        }
    });
    
    [self updateView];
}

- (void) updateView
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            if( _pattern != [self.delegate valueForKey:@"currentPattern"] )
                _pattern = [self.delegate valueForKey:@"currentPattern"];
            
            // Update PatternView sub view
            NSError *requestError = nil;
            NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
            patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", _pattern];
            NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);
            
            _patternView.pattern = [patternMatches lastObject];
        }];
        
        [super updateView];
        
    });
}

- (SequencerNote *) checkForNoteAtX:(uint)x y:(uint)y
{
    // See if there's a note there

    // If we are showing note length on the grid then then we need to look through all the notes on the row, checking their length
    if( _sharedPreferences.showNoteLengthOnGrid ) {
    
        NSError *requestError;
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (row == %u)", _pattern, y];
        
        SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:_pattern.inPage.id.unsignedIntegerValue];
        
        BOOL sortDirection = ( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) ? NO : YES;
        noteRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"step" ascending:sortDirection]];
        
        NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);

        for( SequencerNote *note in noteMatches ) {
            
            int endPoint;
            
            // When in reverse
            if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
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
        
    // If we're not showing note length on the grid then this is much simpler!
    } else {
        
        NSError *requestError;
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern == %@) AND (step == %u) AND (row == %u)", _pattern, x, y];
        
        NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
        
        if( noteMatches.count )
            return [noteMatches lastObject];
    }
    
    // Return nil if we didn't find one
    return nil;
}



#pragma mark - Sub view delegate methods

// Both sliders
- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        [self.managedObjectContext performBlock:^(void) {
            
            // Re-build the notes set but with the adjusted note
            NSMutableSet *newNotes = [NSMutableSet setWithCapacity:_pattern.notes.count];
            
            for( SequencerNote *note in _pattern.notes ) {
                
                SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                
                newNote.row = note.row;
                newNote.step = note.step;
                newNote.length = note.length;
                newNote.velocity = note.velocity;
                
                if( note == _activeEditNote ) {
                    
                    // Velocity
                    if(sender == _velocityView) {
                        
                        float oneStepOf127 = 127.0 / sender.width;
                        float range = 127.0 - oneStepOf127;
                        
                        float newVelocity = range * (sender.percentage / 100.0);
                        newVelocity += oneStepOf127;
                        
                        newNote.velocity = [NSNumber numberWithInt:roundf( newVelocity ) ];
                        //NSLog(@"Velocity %@ / Percentage %f", _activeEditNote.velocity, sender.percentage);
                        
                    // Length
                    } else if(sender == _lengthView) {
                        newNote.length = [NSNumber numberWithInt:roundf( ( sender.width - 1 ) * ( sender.percentage / 100.0 ) ) + 1 ];
                        //NSLog(@"Percentage %f Length %@", sender.percentage, _activeEditNote.length);
                    }
                    
                    _patternView.activeEditNote = newNote;
                    _activeEditNote = newNote;
                }
                
                [newNotes addObject:newNote];
            }
            _pattern.notes = newNotes;
            
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
    });
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    if( _patternView.mode == EatsPatternViewMode_Locked ) return;
    
    dispatch_async(self.bigSerialQueue, ^(void) {

        uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
        uint y = [[xyDown valueForKey:@"y"] unsignedIntValue];
        BOOL down = [[xyDown valueForKey:@"down"] boolValue];
        
        // Down
        if( down ) {
        
            // Edit mode
            if( sender.mode == EatsPatternViewMode_Edit ) {
                
                _lastDownWasInEditMode = YES;
                
                [self updateView];
                
            // Note edit mode
            } else if ( sender.mode == EatsPatternViewMode_NoteEdit ) {
                
                _lastDownWasInEditMode = NO;
                
                [self exitNoteEditMode];
            }
            
        }
        
        // Release
        if( !down && sender.mode == EatsPatternViewMode_Edit && _lastDownWasInEditMode ) {
                
                [self.managedObjectContext performBlock:^(void) {
                    
                    // See if we have a note there
                    SequencerNote *foundNote = [self checkForNoteAtX:x y:self.height - 1 - y];
                    
                    // Remove
                    if( foundNote ) {
                        
                        // Re-build the notes set but without the deleted note so that KVO gets updated
                        NSMutableSet *newNotes = [NSMutableSet setWithCapacity:_pattern.notes.count];
                        
                        for( SequencerNote *note in _pattern.notes ) {
                            if( note != foundNote ) {
                                SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                                newNote.row = note.row;
                                newNote.step = note.step;
                                newNote.length = note.length;
                                newNote.velocity = note.velocity;
                                [newNotes addObject:newNote];
                            } else {
                                [self.managedObjectContext deleteObject:foundNote];
                            }
                        }
                        _pattern.notes = newNotes;

                        
                    // Add
                    } else {
                        
                        // Re-build the set
                        NSMutableSet *newNotes = [NSMutableSet setWithCapacity:_pattern.notes.count + 1];
                        
                        for( SequencerNote *note in _pattern.notes ) {
                            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                            newNote.row = note.row;
                            newNote.step = note.step;
                            newNote.length = note.length;
                            newNote.velocity = note.velocity;
                            [newNotes addObject:newNote];
                        }
                        
                        // Add the extra note
                        SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContext];
                        newNote.step = [NSNumber numberWithUnsignedInt:x];
                        newNote.row = [NSNumber numberWithUnsignedInt:self.height - 1 - y];
                        newNote.velocity = [_sharedPreferences.defaultMIDINoteVelocity copy];
                        [newNotes addObject:newNote];
                        
                        _pattern.notes = newNotes;
                    }
                    
                    NSError *saveError = nil;
                    [self.managedObjectContext save:&saveError];
                    if( saveError )
                        NSLog(@"Save error: %@", saveError);
                }];
        }
        
    });

}

- (void) eatsGridPatternViewLongPressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender
{
    uint x = [[xy valueForKey:@"x"] unsignedIntValue];
    uint y = [[xy valueForKey:@"y"] unsignedIntValue];
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            // See if we have a note there
            SequencerNote *foundNote = [self checkForNoteAtX:x y:self.height - 1 - y];
            
            if( foundNote )
                [self enterNoteEditModeFor:foundNote];
            else
                [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
        }];
    });
}

@end