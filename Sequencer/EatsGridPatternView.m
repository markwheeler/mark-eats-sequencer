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
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerNote.h"
#import "SequencerState.h"
#import "SequencerPageState.h"


#define PLAYHEAD_BRIGHTNESS 8
#define NEXT_STEP_BRIGHTNESS 8
#define NOTE_BRIGHTNESS 15
#define NOTE_LENGTH_BRIGHTNESS 10
#define PRESS_BRIGHTNESS 15
#define LONG_PRESS_TIME 0.4

@interface EatsGridPatternView ()

@property Preferences           *sharedPreferences;

@property NSDictionary          *lastLongPressKey;
@property NSMutableOrderedSet   *currentlyDownKeys;

@property NSTimer               *longPressTimer;

@end

@implementation EatsGridPatternView

- (id) init
{
    self = [super init];
    if (self) {
        _sharedPreferences = [Preferences sharedPreferences];
        
        _playheadBrightness = PLAYHEAD_BRIGHTNESS;
        _nextStepBrightness = NEXT_STEP_BRIGHTNESS;
        _noteBrightness = NOTE_BRIGHTNESS;
        _noteLengthBrightness = NOTE_LENGTH_BRIGHTNESS;
        _pressBrightness = PRESS_BRIGHTNESS;
        
        _currentlyDownKeys = [[NSMutableOrderedSet alloc] initWithCapacity:4];
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    __block NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        
        // Get the NSNumber objects ready so we don't have to create loads of them in the for loops
        NSNumber *wipeBrighnessResult = [NSNumber numberWithInt:15 * self.opacity];
        NSNumber *playheadBrighnessResult = [NSNumber numberWithInt:_playheadBrightness * self.opacity];
        NSNumber *nextStepBrighnessResult = [NSNumber numberWithInt:_nextStepBrightness * self.opacity];
        NSNumber *noteBrightnessResult = [NSNumber numberWithInt:_noteBrightness * self.opacity];
        NSNumber *noteLengthBrightnessResult = [NSNumber numberWithInt:_noteLengthBrightness * self.opacity];
        NSNumber *zero = [NSNumber numberWithUnsignedInt:0];
        
        SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:_pattern.inPage.id.unsignedIntegerValue];
    
        // Generate the columns with playhead and nextStep
        for(uint x = 0; x < self.width; x++) {
            [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
            // Generate the rows
            for(uint y = 0; y < self.height; y++) {
                if( self.width * _wipe / 100 >= x + 1 )
                    [[viewArray objectAtIndex:x] insertObject:wipeBrighnessResult atIndex:y];
                else if( pageState.currentPatternId.intValue == _pattern.id.intValue && x == pageState.currentStep.intValue )
                    [[viewArray objectAtIndex:x] insertObject:playheadBrighnessResult atIndex:y];
                else if( pageState.nextStep && x == pageState.nextStep.intValue )
                    [[viewArray objectAtIndex:x] insertObject:nextStepBrighnessResult atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:zero atIndex:y];
            }
        }
        
        
        // Work out how much we need to fold
        int scaleDifference = _patternHeight - self.height;
        
        for(SequencerNote *note in _pattern.notes) {

            if( scaleDifference < 0 ) scaleDifference = 0;
            
            if( note.step.intValue < self.width && note.row.intValue < _patternHeight ) {
                
                uint originalRow = _patternHeight - 1 - note.row.unsignedIntValue; // Flip axes here
                uint row = originalRow;
                
                float divisionFactorFloat = (float)_patternHeight / self.height;
                int divisionFactor = ceilf(divisionFactorFloat);
                if ( divisionFactor % 2 )
                    divisionFactor ++;
                
                // Note that pattern folding beyond half size is only supported 'from top'
                
                // Fold from top
                if( _foldFrom == EatsPatternViewFoldFrom_Top ) {
                    
                    for( int i = 1; i <= divisionFactor / 2; i ++ ) {
                        
                        int scaleDifferenceThisLoop = scaleDifference - ((self.height - 1) * (i - 1));
                        if( originalRow < scaleDifferenceThisLoop * 2 ) {
                            row = row / 2;
                            
                        } else {
                            row -= scaleDifferenceThisLoop / i;
                        }

                    }
                    
                // Fold from bottom
                } else if( _foldFrom == EatsPatternViewFoldFrom_Bottom ) {
                    if( row >= _patternHeight - (scaleDifference * 2) )
                        row = (row / 2) + ((_patternHeight - (scaleDifference * 2)) / 2);
                    
                }
                
                // Put in the active note while editing
                if( note == _activeEditNote && _mode == EatsPatternViewMode_NoteEdit ) {
                    [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:15 * self.opacity]];
                    noteLengthBrightnessResult = [NSNumber numberWithInt:12 * self.opacity];
                }
                
                // Put the rest in (unless there's something brighter there)
                else if( [[[viewArray objectAtIndex:note.step.intValue] objectAtIndex:row] intValue] < _noteBrightness * self.opacity )
                    [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:row withObject:noteBrightnessResult];
                
                // Put the length tails in
                int tailDraw = note.step.intValue;
                int length =  note.length.intValue - 1;
                if( length > self.width - 1)
                    length = self.width - 1;
                
                
                
                for( int i = 0; i < length; i++ ) {
                    if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse )
                        tailDraw --;
                    else
                        tailDraw ++;
                    
                    if( tailDraw < 0 )
                        tailDraw += self.width;
                    else if( tailDraw >= self.width )
                        tailDraw -= self.width;
                    
                    if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:row] intValue] < noteLengthBrightnessResult.intValue )
                        [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:row withObject:noteLengthBrightnessResult];
                    
                }
            }
        }
        
    }];
    
    // Put in any down keys
    if( _mode == EatsPatternViewMode_Edit ) {
        
        NSNumber *pressBrightnessResult = [NSNumber numberWithInt:_pressBrightness * self.opacity];
        
        NSDictionary *currentlyDownKeys = [_currentlyDownKeys copy]; // Copy it so it can't get mutated while we're enumerating
        for( NSDictionary *key in currentlyDownKeys ) {
            [[viewArray objectAtIndex:[[key valueForKey:@"x"] intValue]] replaceObjectAtIndex:[[key valueForKey:@"y"] intValue] withObject:pressBrightnessResult];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Remove down keys
    if( !down && ( _mode == EatsPatternViewMode_Play || _mode == EatsPatternViewMode_Edit ) ) {
        [self removeDownKeyAtX:x y:y];
    }
    
    // In play mode we check for selections
    if( _mode == EatsPatternViewMode_Play ) {
        
        // Down
        if( down ) {
            
            if( _sharedPreferences.loopFromScrubArea && _currentlyDownKeys.count ) {
                
                // Set a selection
                int loopEndX = x - 1;
                if( loopEndX < 0 )
                    loopEndX += self.width;
                
                NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[[_currentlyDownKeys lastObject] valueForKey:@"x"], @"start",
                                           [NSNumber numberWithInt:loopEndX], @"end",
                                           nil];
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                
                
            } else {
                
                if( _sharedPreferences.loopFromScrubArea ) {
                    
                    // Reset the loop
                    NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"start",
                                               [NSNumber numberWithUnsignedInt:self.width], @"end",
                                               nil];
                    if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                        [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                    
                    
                }
                
                // Send the press to delegate
                NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                        [NSNumber numberWithUnsignedInt:y], @"y",
                                        [NSNumber numberWithBool:down], @"down",
                                        nil];
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
            }
            
            
            
        // Release
        } else {
            
            // Send the press to delegate
            NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                    [NSNumber numberWithUnsignedInt:y], @"y",
                                    [NSNumber numberWithBool:down], @"down",
                                    nil];
            if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
            
        }
        
    }
    
    // Clear up
    if( _mode != EatsPatternViewMode_Edit ) {
        _lastLongPressKey = nil;
    }
    
    // In edit mode we check for long presses
    if ( _mode == EatsPatternViewMode_Edit ) {
        
        // Down
        if( down ) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                [_longPressTimer invalidate];
                _longPressTimer = [NSTimer scheduledTimerWithTimeInterval:LONG_PRESS_TIME
                                                                   target:self
                                                                 selector:@selector(longPressTimeout:)
                                                                 userInfo:nil
                                                                  repeats:NO];
                NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                
                // Make sure we fire even when the UI is tracking mouse down stuff
                [runloop addTimer:_longPressTimer forMode: NSRunLoopCommonModes];
                [runloop addTimer:_longPressTimer forMode: NSEventTrackingRunLoopMode];
            });
            
            // Log the last press
            _lastLongPressKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
            
        // Release
        } else {
            if( _lastLongPressKey && [[_lastLongPressKey valueForKey:@"x"] intValue] == x && [[_lastLongPressKey valueForKey:@"y"] intValue] == y ) {
                _lastLongPressKey = nil;
                [_longPressTimer invalidate];
            }
        }
    }
    
    // These two modes always receive all presses
    if( _mode == EatsPatternViewMode_Edit || _mode == EatsPatternViewMode_NoteEdit ) {
        // Send the press to delegate
        NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                [NSNumber numberWithUnsignedInt:y], @"y",
                                [NSNumber numberWithBool:down], @"down",
                                nil];
        if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
            [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
    }
    
    // Add down keys
    if( down && ( _mode == EatsPatternViewMode_Play || _mode == EatsPatternViewMode_Edit ) ) {
        [_currentlyDownKeys addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil]];
        
    }
    
}

- (void) longPressTimeout:(NSTimer *)sender
{
    if( _lastLongPressKey ) {
        // Send the long press to delegate
        if([self.delegate respondsToSelector:@selector(eatsGridPatternViewLongPressAt: sender:)])
            [self.delegate performSelector:@selector(eatsGridPatternViewLongPressAt: sender:) withObject:_lastLongPressKey withObject:self];
        
        [self removeDownKeyAtX:[[_lastLongPressKey valueForKey:@"x"] unsignedIntValue] y:[[_lastLongPressKey valueForKey:@"y"] unsignedIntValue]];
        
        _lastLongPressKey = nil;
    }
}

- (void) removeDownKeyAtX:(uint)x y:(uint)y
{
    NSDictionary *keyToRemove;
    
    for( NSDictionary *key in _currentlyDownKeys ) {
        if( [[key valueForKey:@"x"] intValue] == x && [[key valueForKey:@"y"] intValue] == y ) {
            keyToRemove = key;
            break;
        }
    }
    
    if( keyToRemove )
        [_currentlyDownKeys removeObject:keyToRemove];
}

@end
