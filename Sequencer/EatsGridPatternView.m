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

@interface EatsGridPatternView ()

@property Preferences           *sharedPreferences;
@property SequencerState        *sharedSequencerState;

@property NSDictionary          *lastReleasedKey;

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridPatternView

- (id) init
{
    self = [super init];
    if (self) {
        _sharedPreferences = [Preferences sharedPreferences];
        _sharedSequencerState = [SequencerState sharedSequencerState];
        
        _playheadBrightness = PLAYHEAD_BRIGHTNESS;
        _nextStepBrightness = NEXT_STEP_BRIGHTNESS;
        _noteBrightness = NOTE_BRIGHTNESS;
        _noteLengthBrightness = NOTE_LENGTH_BRIGHTNESS;
        _doublePressTime = 0.4; // Default
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    __block NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        
        [self.managedObjectContext refreshObject:_pattern mergeChanges:YES];
    
        SequencerPageState *pageState = [_sharedSequencerState.pageStates objectAtIndex:_pattern.inPage.id.unsignedIntegerValue];
    
        // Generate the columns with playhead and nextStep
        for(uint x = 0; x < self.width; x++) {
            [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
            // Generate the rows
            for(uint y = 0; y < self.height; y++) {
                if( self.width * _wipe / 100 >= x + 1 )
                    [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:15 * self.opacity] atIndex:y];
                else if( pageState.currentPatternId.intValue == _pattern.id.intValue && x == pageState.currentStep.intValue )
                    [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:_playheadBrightness * self.opacity] atIndex:y];
                else if( pageState.nextStep && x == pageState.nextStep.intValue )
                    [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:_nextStepBrightness * self.opacity] atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
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
                
                int lengthBrightness = _noteLengthBrightness;
                
                // Put in the active note while editing
                if( note == _activeEditNote && _mode == EatsPatternViewMode_NoteEdit ) {
                    [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:15 * self.opacity]];
                    lengthBrightness = 12;
                }
                
                // Put the rest in (unless there's something brighter there)
                else if( [[[viewArray objectAtIndex:note.step.intValue] objectAtIndex:row] intValue] < _noteBrightness * self.opacity )
                    [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:_noteBrightness * self.opacity]];
                
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
                    
                    if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:row] intValue] < lengthBrightness * self.opacity )
                        [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:lengthBrightness * self.opacity]];
                    
                }
            }
        }
        
    }];
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // In play mode we check for selections
    if( _mode == EatsPatternViewMode_Play ) {
        
        // Down
        if( down ) {
            
            if( _sharedPreferences.loopFromScrubArea && _lastDownKey ) {
                
                // Set a selection
                int loopEndX = x - 1;
                if( loopEndX < 0 )
                    loopEndX += self.width;
                
                _setSelection = YES;
                
                NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[_lastDownKey valueForKey:@"x"], @"start",
                                           [NSNumber numberWithInt:loopEndX], @"end",
                                           nil];
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                
            } else {
                
                // Send the press to delegate
                NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                        [NSNumber numberWithUnsignedInt:y], @"y",
                                        [NSNumber numberWithBool:down], @"down",
                                        nil];
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
                
                if( _sharedPreferences.loopFromScrubArea ) {
                    // Log the last press
                    _lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
                }
            }
            
            
            
        // Release
        } else {
            
            // Remove lastDownKey if it's this one and set the selection to all
            if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] intValue] == x && [[_lastDownKey valueForKey:@"y"] intValue] == y ) {
                if (!_setSelection ) {
                    
                    NSDictionary *selection = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"start",
                                                                                         [NSNumber numberWithUnsignedInt:self.width], @"end",
                                                                                         nil];
                    if([self.delegate respondsToSelector:@selector(eatsGridPatternViewSelection: sender:)])
                        [self.delegate performSelector:@selector(eatsGridPatternViewSelection: sender:) withObject:selection withObject:self];
                    
                }
                _lastDownKey = nil;
                _setSelection = NO;
            }
            
            // Send the press to delegate
            NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                    [NSNumber numberWithUnsignedInt:y], @"y",
                                    [NSNumber numberWithBool:down], @"down",
                                    nil];
            if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
                [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];
            
        }
        
    }
    
    // Clear up after tracking selection
    if( _mode != EatsPatternViewMode_Play ) {
        _lastDownKey = nil;
        _setSelection = NO;
    }
    
    // In edit mode we check for double presses
    if ( _mode == EatsPatternViewMode_Edit ) {
        
        if( !down ) {
            
            // Check for double presses
            if(_lastReleasedKey
               && [[_lastReleasedKey valueForKey:@"time"] timeIntervalSinceNow] > -_doublePressTime
               && [[_lastReleasedKey valueForKey:@"x"] intValue] == x
               && [[_lastReleasedKey valueForKey:@"y"] intValue] == y) {
                
                // Send the double press to delegate
                NSDictionary *xy = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                    [NSNumber numberWithUnsignedInt:y], @"y",
                                    nil];
                if([self.delegate respondsToSelector:@selector(eatsGridPatternViewDoublePressAt: sender:)])
                    [self.delegate performSelector:@selector(eatsGridPatternViewDoublePressAt: sender:) withObject:xy withObject:self];
                
            } else {
                // Log the last release
                _lastReleasedKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                    [NSNumber numberWithUnsignedInt:y], @"y",
                                    [NSDate date], @"time",
                                    nil];
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

}


@end
