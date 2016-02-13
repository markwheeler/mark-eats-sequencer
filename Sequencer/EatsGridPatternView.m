//
//  EatsGridPatternView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPatternView.h"
#import "EatsGridNavigationController.h"
#import "EatsGridUtils.h"
#import "Preferences.h"

#define PLAYHEAD_BRIGHTNESS 8
#define NEXT_STEP_BRIGHTNESS 8
#define NOTE_BRIGHTNESS 15
#define NOTE_LENGTH_BRIGHTNESS 10
#define ACTIVE_EDIT_NOTE_BRIGHTNESS 15
#define ACTIVE_EDIT_NOTE_LENGTH_BRIGHTNESS 12
#define PRESS_BRIGHTNESS 15
#define NOTE_EDIT_FADE_AMOUNT 8
#define LONG_PRESS_TIME 0.4

@interface EatsGridPatternView ()

@property Preferences           *sharedPreferences;

@property NSDictionary          *lastLongPressKey;
@property NSMutableOrderedSet   *currentlyDownKeys;

@property NSTimer               *longPressTimer;

@end

@implementation EatsGridPatternView

// Put in this setter-alike so we can reset any down/selection stuff and not get into weird states

- (void) setEnabled:(BOOL)enabled
{
    super.enabled = enabled;
    
    if( self.lastLongPressKey )
        self.lastLongPressKey = nil;
    dispatch_sync(dispatch_get_main_queue(), ^(void) { // Added this in to try and avoid it getting mutated while removing all objects
       [self.currentlyDownKeys removeAllObjects];
    });
    [self.longPressTimer invalidate];
    self.longPressTimer = nil;
}

- (id) init
{
    self = [super init];
    if (self) {
        self.sharedPreferences = [Preferences sharedPreferences];
        
        self.noteEditModeAnimationAmount = 0.0;
        
        self.currentlyDownKeys = [[NSMutableOrderedSet alloc] initWithCapacity:4];
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible || self.width < 1 || self.height < 1 ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Get the NSNumber objects ready so we don't have to create loads of them in the for loops
    NSNumber *wipeBrightnessResult = [NSNumber numberWithInt:15 * self.opacity];
    NSNumber *playheadBrightnessResult = [NSNumber numberWithInt:PLAYHEAD_BRIGHTNESS * self.opacity];
    NSNumber *nextStepBrightnessResult = [NSNumber numberWithInt:NEXT_STEP_BRIGHTNESS * self.opacity];
    NSNumber *zero = [NSNumber numberWithUnsignedInt:0];
    
    // Generate the columns with playhead and nextStep
    for( uint x = 0; x < self.width; x ++ ) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for( uint y = 0; y < self.height; y ++ ) {
            if( self.width * self.wipe / 100 >= x + 1 )
                [(NSMutableArray *)[viewArray objectAtIndex:x] insertObject:wipeBrightnessResult atIndex:y];
            else if( x == self.currentStep )
                [(NSMutableArray *)[viewArray objectAtIndex:x] insertObject:playheadBrightnessResult atIndex:y];
            else if( self.nextStep && x == self.nextStep.intValue )
                [(NSMutableArray *)[viewArray objectAtIndex:x] insertObject:nextStepBrightnessResult atIndex:y];
            else
                [(NSMutableArray *)[viewArray objectAtIndex:x] insertObject:zero atIndex:y];
        }
    }
    
    
    // Work out how much we need to fold
    int scaleDifference = self.patternHeight - self.height;
    
    for( SequencerNote *note in self.notes ) {

        if( scaleDifference < 0 ) scaleDifference = 0;
        
        if( note.step < self.width && note.row < self.patternHeight ) {
            
            uint originalRow = self.patternHeight - 1 - note.row; // Flip axes here
            uint row = originalRow;
            
            float divisionFactorFloat = (float)self.patternHeight / self.height;
            int divisionFactor = ceilf(divisionFactorFloat);
            if ( divisionFactor % 2 )
                divisionFactor ++;
            
            // Note that pattern folding beyond half size is only supported 'from top'
            
            // Fold from top
            if( self.foldFrom == EatsPatternViewFoldFrom_Top ) {
                
                for( int i = 1; i <= divisionFactor / 2; i ++ ) {
                    
                    int scaleDifferenceThisLoop = scaleDifference - ((self.height - 1) * (i - 1));
                    if( originalRow < scaleDifferenceThisLoop * 2 ) {
                        row = row / 2;
                        
                    } else {
                        row -= scaleDifferenceThisLoop / i;
                    }

                }
                
            // Fold from bottom
            } else if( self.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
                if( row >= self.patternHeight - (scaleDifference * 2) )
                    row = (row / 2) + ((self.patternHeight - (scaleDifference * 2)) / 2);
                
            }
            
            // Calculate brightness based on note velocity if supported
            NSNumber *noteBrightnessWithVelocityAndFade;
            NSNumber *noteLengthBrightnessWithVelocityAndFade;
            
            uint noteBrightnessWithVelocity;
            uint noteLengthBrightnessWithVelocity;
            
            if( self.sharedPreferences.gridSupportsVariableBrightness ) {
                
                float velocityPercentage = (float)note.velocity / SEQUENCER_MIDI_MAX;
                
                float noteBrightnessWithFade = NOTE_BRIGHTNESS - NOTE_EDIT_FADE_AMOUNT * self.noteEditModeAnimationAmount;
                noteBrightnessWithFade = ( noteBrightnessWithFade / 2.0 ) + ( ( noteBrightnessWithFade / 2.0 ) * velocityPercentage );
                noteBrightnessWithVelocityAndFade = [NSNumber numberWithUnsignedInt:roundf( noteBrightnessWithFade * self.opacity )];
                
                noteBrightnessWithVelocity = roundf( ( ( NOTE_BRIGHTNESS / 2.0 ) + ( ( NOTE_BRIGHTNESS / 2.0 ) * velocityPercentage ) ) * self.opacity );
                
                float noteLengthBrightnessWithFade = NOTE_LENGTH_BRIGHTNESS - NOTE_EDIT_FADE_AMOUNT * self.noteEditModeAnimationAmount;
                noteLengthBrightnessWithFade = ( noteLengthBrightnessWithFade / 2.0 ) + ( ( noteLengthBrightnessWithFade / 2.0 ) * velocityPercentage );
                noteLengthBrightnessWithVelocityAndFade = [NSNumber numberWithUnsignedInt:roundf( noteLengthBrightnessWithFade * self.opacity )];
                
                noteLengthBrightnessWithVelocity = roundf( ( ( NOTE_LENGTH_BRIGHTNESS / 2.0 ) + ( ( NOTE_LENGTH_BRIGHTNESS / 2.0 ) * velocityPercentage ) ) * self.opacity );
                
            } else {
                
                noteBrightnessWithVelocityAndFade = [NSNumber numberWithUnsignedInt:NOTE_BRIGHTNESS * self.opacity];
                noteLengthBrightnessWithVelocityAndFade = [NSNumber numberWithUnsignedInt:NOTE_LENGTH_BRIGHTNESS * self.opacity];
                
                noteBrightnessWithVelocity = roundf( NOTE_BRIGHTNESS * self.opacity );
                noteLengthBrightnessWithVelocity = roundf( NOTE_LENGTH_BRIGHTNESS * self.opacity );
            }
            
            
            // DEBUG LOG
            // TODO remove debug code
            if( [viewArray count] <= note.step )
                NSLog( @"View array is %lu but note step is %u", (unsigned long)[viewArray count], note.step );
            if( [[viewArray objectAtIndex:note.step] count] <= row )
                NSLog( @"View array's column is %lu but note (folded) row is %u", (unsigned long)[[viewArray objectAtIndex:note.step] count], row );
            
            
            
            // Put in the active note while editing
            if( note.step == self.activeEditNote.step && note.row == self.activeEditNote.row && self.mode == EatsPatternViewMode_NoteEdit ) {
                
                // If animating in or out
                float editNoteDefaultBrightness;
                if( self.animatingIn )
                    editNoteDefaultBrightness = PRESS_BRIGHTNESS * self.opacity;
                else
                    editNoteDefaultBrightness = noteBrightnessWithVelocity;
                
                int activeEditNoteBrightness = roundf( ( ACTIVE_EDIT_NOTE_BRIGHTNESS * self.noteEditModeAnimationAmount * self.opacity ) + editNoteDefaultBrightness * ( 1.0 - self.noteEditModeAnimationAmount ) );
                int activeEditNoteLengthBrightness = roundf( ( ACTIVE_EDIT_NOTE_LENGTH_BRIGHTNESS * self.noteEditModeAnimationAmount * self.opacity ) + noteLengthBrightnessWithVelocity * ( 1.0 - self.noteEditModeAnimationAmount ) );
                
                [[viewArray objectAtIndex:note.step] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:activeEditNoteBrightness]];
                noteLengthBrightnessWithVelocityAndFade = [NSNumber numberWithInt:activeEditNoteLengthBrightness];
            }
            
            // Put the rest in (unless there's something brighter there)
            else if( [[[viewArray objectAtIndex:note.step] objectAtIndex:row] intValue] < noteBrightnessWithVelocityAndFade.intValue ) {
                
                [[viewArray objectAtIndex:note.step] replaceObjectAtIndex:row withObject:noteBrightnessWithVelocityAndFade];
            }
            
            // Put the length tails in when appropriate
            if( self.sharedPreferences.showNoteLengthOnGrid || ( note.step == self.activeEditNote.step && note.row == self.activeEditNote.row ) ) {
                
                int tailDraw = note.step;
                int length =  note.length - 1;
                if( length > self.width - 1)
                    length = self.width - 1;
                
                for( int i = 0; i < length; i++ ) {
                    if( self.drawNotesForReverse )
                        tailDraw --;
                    else
                        tailDraw ++;
                    
                    if( tailDraw < 0 )
                        tailDraw += self.width;
                    else if( tailDraw >= self.width )
                        tailDraw -= self.width;
                    
                    // DEBUG LOG
                    // TODO remove debug code
                    if( [viewArray count] <= tailDraw )
                        NSLog( @"View array is %lu but tailDraw is %u", (unsigned long)[viewArray count], tailDraw );
                    if( [[viewArray objectAtIndex:tailDraw] count] <= row )
                        NSLog( @"View array's column is %lu but tailDraw (folded) row is %u", (unsigned long)[[viewArray objectAtIndex:tailDraw] count], row );
                    
                    if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:row] intValue] < noteLengthBrightnessWithVelocityAndFade.intValue )
                        [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:row withObject:noteLengthBrightnessWithVelocityAndFade];
                    
                }
            }
        }
    }
    
    // Put in any down keys
    if( self.mode == EatsPatternViewMode_Edit ) {
        
        NSNumber *pressBrightnessResult = [NSNumber numberWithInt:PRESS_BRIGHTNESS * self.opacity];
        
        
        
        // TODO this following line may have crashed before (crash log "2015-05-10 Crash while adding note to grid? Or maybe held?")
        
        
        
        
        NSOrderedSet *currentlyDownKeys = [self.currentlyDownKeys copy]; // Copy it so it can't get mutated while we're enumerating (this should be unnecessary as we're always on gridQueue?)
        
        for( NSDictionary *key in currentlyDownKeys ) {
            
            int keyX = [[key valueForKey:@"x"] intValue];
            int keyY = [[key valueForKey:@"y"] intValue];
            
            // DEBUG LOG
            // TODO remove debug code
            if( [viewArray count] <= keyX )
                NSLog( @"View array is %lu but keyX is %u", (unsigned long)[viewArray count], keyX );
            if( [[viewArray objectAtIndex:keyX] count] <= keyY )
                NSLog( @"View array's column is %lu but keyY is %u", (unsigned long)[[viewArray objectAtIndex:keyX] count], keyY );
            
            
            [[viewArray objectAtIndex:keyX] replaceObjectAtIndex:keyY withObject:pressBrightnessResult];
        }
    }
    
    
    
    // DEBUG LOG
    // TODO remove this debug code
    NSUInteger noOfCols = [viewArray count];
    NSUInteger noOfRows = [[viewArray objectAtIndex:0] count];
    if( noOfCols != self.width || noOfRows != self.height )
        NSLog(@"Pattern viewArray is wrong size %u %u %@", self.width, self.height, viewArray );
    
    // DEBUG LOG
    // The following checks that all the columns have the correct number of rows in them
    for( int i = 0; i < viewArray.count; i ++ ) {
        if( [[viewArray objectAtIndex:i] count] != noOfRows ) {
            NSLog( @"Pattern viewArray rows are not equal! Should be %lu but col %i is %lu", (unsigned long)noOfRows, i, (unsigned long)[[viewArray objectAtIndex:i] count] );
            NSLog(@"DUMP OF viewArray %@", viewArray );
        }
    }
    
    
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    
    // Remove down keys
    if( !down && ( self.mode == EatsPatternViewMode_Play || self.mode == EatsPatternViewMode_Edit ) ) {
        [self removeDownKeyAtX:x y:y];
    }
    
    // In play mode we check for selections
    if( self.mode == EatsPatternViewMode_Play ) {
        
        // Down
        if( down ) {
            
            if( self.sharedPreferences.loopFromScrubArea && self.currentlyDownKeys.count ) {
                
                // Set a selection
                int loopEndX = x - 1;
                if( loopEndX < 0 )
                    loopEndX += self.width;
                
                NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[[self.currentlyDownKeys lastObject] valueForKey:@"x"], @"start",
                                           [NSNumber numberWithInt:loopEndX], @"end",
                                           nil];
                
                dispatch_async( dispatch_get_main_queue(), ^(void) {
                    if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                            [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                });
                
                
            } else {
                
                if( self.sharedPreferences.loopFromScrubArea ) {
                    
                    // Reset the loop
                    NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"start",
                                               [NSNumber numberWithUnsignedInt:self.width - 1], @"end",
                                               nil];
                    
                    dispatch_async( dispatch_get_main_queue(), ^(void) {
                        if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                            [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                    });
                    
                    
                }
                
                // Send the press to delegate
                NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                        [NSNumber numberWithUnsignedInt:y], @"y",
                                        [NSNumber numberWithBool:down], @"down",
                                        nil];
                
                dispatch_async( dispatch_get_main_queue(), ^(void) {
                    if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                        [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
                });
            }
            
            
            
        // Release
        } else {
            
            // Send the press to delegate
            NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                    [NSNumber numberWithUnsignedInt:y], @"y",
                                    [NSNumber numberWithBool:down], @"down",
                                    nil];
            dispatch_async( dispatch_get_main_queue(), ^(void) {
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
            });
            
        }
        
    }
    
    // Clear up
    if( self.mode != EatsPatternViewMode_Edit ) {
        self.lastLongPressKey = nil;
    }
    
    // In edit mode we check for long presses
    if ( self.mode == EatsPatternViewMode_Edit ) {
        
        // Down
        if( down ) {
            dispatch_async( dispatch_get_main_queue(), ^(void) {
                
                [self.longPressTimer invalidate];
                self.longPressTimer = [NSTimer scheduledTimerWithTimeInterval:LONG_PRESS_TIME
                                                                   target:self
                                                                 selector:@selector(longPressTimeout:)
                                                                 userInfo:nil
                                                                  repeats:NO];
                NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                
                // Make sure we fire even when the UI is tracking mouse down stuff
                [runloop addTimer:self.longPressTimer forMode: NSRunLoopCommonModes];
                [runloop addTimer:self.longPressTimer forMode: NSEventTrackingRunLoopMode];
            });
            
            // Log the last press
            self.lastLongPressKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
            
        // Release
        } else {
            if( self.lastLongPressKey && [[self.lastLongPressKey valueForKey:@"x"] intValue] == x && [[self.lastLongPressKey valueForKey:@"y"] intValue] == y ) {
                self.lastLongPressKey = nil;
                [self.longPressTimer invalidate];
            }
        }
    }
    
    // Add down keys
    if( down && ( self.mode == EatsPatternViewMode_Play || self.mode == EatsPatternViewMode_Edit ) ) {
        [self.currentlyDownKeys addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil]];
        
    }
    
    // These two modes always receive all presses
    if( self.mode == EatsPatternViewMode_Edit || self.mode == EatsPatternViewMode_NoteEdit ) {
        // Send the press to delegate
        NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                [NSNumber numberWithUnsignedInt:y], @"y",
                                [NSNumber numberWithBool:down], @"down",
                                nil];
        
        // TODO comment out of release
        NSLog(@"GridPatternView.eatsGridPatternViewPressAt:%u,%u,%i", x, y, down );
        
        dispatch_async( dispatch_get_main_queue(), ^(void) {
            if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
        });
    }
    
}

- (void) longPressTimeout:(NSTimer *)sender
{
    dispatch_async( self.gridQueue, ^(void) {
    
        if( self.lastLongPressKey ) {
            
            // Send the long press to delegate
            NSDictionary *copyOfLastLongPressKey = [self.lastLongPressKey copy];
            dispatch_async( dispatch_get_main_queue(), ^(void) {
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewLongPressAt: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewLongPressAt: sender:) withObject:copyOfLastLongPressKey withObject:self];
            });
            
            [self removeDownKeyAtX:[[self.lastLongPressKey valueForKey:@"x"] unsignedIntValue] y:[[self.lastLongPressKey valueForKey:@"y"] unsignedIntValue]];
            
            self.lastLongPressKey = nil;
        }
        
    });
}

- (void) removeDownKeyAtX:(uint)x y:(uint)y
{
    NSDictionary *keyToRemove;
    
    for( NSDictionary *key in self.currentlyDownKeys ) {
        if( [[key valueForKey:@"x"] intValue] == x && [[key valueForKey:@"y"] intValue] == y ) {
            keyToRemove = key;
            break;
        }
    }
    
    if( keyToRemove )
        [self.currentlyDownKeys removeObject:keyToRemove];
}

@end
