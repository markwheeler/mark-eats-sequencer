//
//  EatsGridPlayViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPlayViewController.h"
#import "EatsGridNavigationController.h"
#import "EatsGridUtils.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerNote.h"
#import "SequencerState.h"
#import "SequencerPageState.h"
#import "Preferences.h"

#define ANIMATION_FRAMERATE 15
#define ANIMATION_EASE 0.4

@interface EatsGridPlayViewController ()

@property Sequencer                         *sequencer;
@property SequencerPattern                  *currentPattern;
@property SequencerState                    *sharedSequencerState;
@property Preferences                       *sharedPreferences;

@property EatsGridLoopBraceView             *loopBraceView;
@property EatsGridPatternView               *patternView;

@property NSMutableArray                    *pageButtons;
@property NSMutableArray                    *patternButtons;
@property NSMutableArray                    *patternsOnOtherPagesButtons;
@property NSArray                           *playModeButtons;
@property NSArray                           *controlButtons;

@property EatsGridButtonView                *pauseButton;
@property EatsGridButtonView                *forwardButton;
@property EatsGridButtonView                *reverseButton;
@property EatsGridButtonView                *randomButton;
@property EatsGridButtonView                *bpmDecrementButton;
@property EatsGridButtonView                *bpmIncrementButton;
@property EatsGridButtonView                *clearButton;
@property EatsGridButtonView                *exitButton;

@property NSTimer                           *bpmRepeatTimer;
@property NSTimer                           *clearTimer;

@property NSTimer                           *animationTimer;
@property uint                              animationFrame;
@property int                               animationSpeedMultiplier;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    // Get the sequencer
    _sequencer = [self.delegate valueForKey:@"sequencer"];
    _sharedSequencerState = [SequencerState sharedSequencerState];
    
    // Get the pattern
    _currentPattern = [self.delegate valueForKey:@"currentPattern"];
    
    // Get prefs
    _sharedPreferences = [Preferences sharedPreferences];
    
    // Create the sub views
    
    // Page buttons
    _pageButtons = [[NSMutableArray alloc] initWithCapacity:8];
    for( int i = 0; i < 8; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height / 2) + 1;
        if( self.width < 16 )
            button.y ++;
        button.visible = NO;
        [_pageButtons addObject:button];
    }
    
    // Pattern buttons
    uint numberOfPatterns = self.width;
    if( numberOfPatterns > 16 )
        numberOfPatterns = 16;
    
    _patternButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
    for( int i = 0; i < numberOfPatterns; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height / 2) + 3;
        button.visible = NO;
        [_patternButtons addObject:button];
    }
    
    // Pattern buttons for other pages
    _patternsOnOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
    for( int i = 0; i < numberOfPatterns; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height / 2) + 2;
        button.visible = NO;
        button.inactiveBrightness = 5;
        [_patternsOnOtherPagesButtons addObject:button];
    }
    
    // Play mode buttons
    _pauseButton = [[EatsGridButtonView alloc] init];
    _pauseButton.x = self.width - 8;
    
    _forwardButton = [[EatsGridButtonView alloc] init];
    _forwardButton.x = self.width - 7;
    
    _reverseButton = [[EatsGridButtonView alloc] init];
    _reverseButton.x = self.width - 6;
    
    _randomButton = [[EatsGridButtonView alloc] init];
    _randomButton.x = self.width - 5;
    
    _playModeButtons = [NSArray arrayWithObjects:_pauseButton, _forwardButton, _reverseButton, _randomButton, nil];
    
    for( EatsGridButtonView *button in _playModeButtons ) {
        button.delegate = self;
        button.y = - (self.height / 2) + 1;
        button.inactiveBrightness = 5;
        button.visible = NO;
    }
    
    // Control buttons
    _bpmDecrementButton = [[EatsGridButtonView alloc] init];
    _bpmDecrementButton.x = self.width - 4;
    
    _bpmIncrementButton = [[EatsGridButtonView alloc] init];
    _bpmIncrementButton.x = self.width - 3;
    
    _clearButton = [[EatsGridButtonView alloc] init];
    _clearButton.x = self.width - 2;
    _clearButton.inactiveBrightness = 5;
    
    _exitButton = [[EatsGridButtonView alloc] init];
    _exitButton.x = self.width - 1;
    _exitButton.inactiveBrightness = 8;
    
    _controlButtons = [NSArray arrayWithObjects:_bpmDecrementButton, _bpmIncrementButton, _clearButton, _exitButton, nil];
    
    for( EatsGridButtonView *button in _controlButtons ) {
        button.delegate = self;
        button.y = - (self.height / 2) + 1;
        button.visible = NO;
    }
    
    // Loop length selection view
    _loopBraceView = [[EatsGridLoopBraceView alloc] init];
    _loopBraceView.delegate = self;
    _loopBraceView.x = 0;
    _loopBraceView.y = 0;
    _loopBraceView.width = self.width;
    _loopBraceView.height = 1;
    _loopBraceView.fillBar = YES;
    _loopBraceView.visible = NO;
    [self setLoopBraceViewStartAndEnd];
    
    // Pattern view
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.managedObjectContext = self.managedObjectContext;
    _patternView.x = 0;
    _patternView.y = 1;
    _patternView.width = self.width;
    _patternView.height = self.height - 1;
    _patternView.foldFrom = EatsPatternViewFoldFrom_Top;
    _patternView.mode = EatsPatternViewMode_Play;
    _patternView.pattern = _currentPattern;
    _patternView.patternHeight = self.height;
    
    // Set top left buttons correctly
    [self setActivePageButton];
    [self setPatternButtonState];
    
    // Make the correct playMode button active
    [self setPlayMode];
    
    // Add everything to sub views
    self.subViews = [[NSMutableSet alloc] initWithObjects:_loopBraceView, _patternView, nil];
    [self.subViews addObjectsFromArray:_pageButtons];
    [self.subViews addObjectsFromArray:_patternButtons];
    [self.subViews addObjectsFromArray:_patternsOnOtherPagesButtons];
    [self.subViews addObjectsFromArray:_playModeButtons];
    [self.subViews addObjectsFromArray:_controlButtons];
    
    // Start animateIn
    _animationFrame = 0;
    _animationSpeedMultiplier = 8 / self.height;
    [self animateIncrement:-1];
    [self scheduleAnimateInTimer];
    [self updateView];
}

- (void) dealloc
{
    if( _animationTimer )
        [_animationTimer invalidate];
    
    if( _bpmRepeatTimer )
        [_bpmRepeatTimer invalidate];
    
}

- (void) updateView
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        [self.managedObjectContext performBlockAndWait:^(void) {
            if( _currentPattern != [self.delegate valueForKey:@"currentPattern"] )
                _currentPattern = [self.delegate valueForKey:@"currentPattern"];
            
            // Update PatternView sub view
            NSError *requestError = nil;
            NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
            patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", _currentPattern];
            NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);
            
            _currentPattern = [patternMatches lastObject];
            
            _patternView.pattern = _currentPattern;
        }];
        
        // Set buttons etc
        [self setPlayMode];
        [self setActivePageButton];
        [self setPatternButtonState];
        [self setLoopBraceViewStartAndEnd];
        
        [super updateView];
                
    });
}

// Activates the playMode button
- (void) setPlayMode
{
    __block EatsSequencerPlayMode playMode;
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        SequencerPageState *pageState = [_sharedSequencerState.pageStates objectAtIndex:_currentPattern.inPage.id.unsignedIntegerValue];
        playMode = pageState.playMode.intValue;
    }];
    
    uint i = 0;
    for ( EatsGridButtonView *button in _playModeButtons ) {
        if( i == playMode )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) setActivePageButton
{
    __block int currentPageId;
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        currentPageId = _currentPattern.inPage.id.intValue;
    }];
    
    uint i = 0;
    for ( EatsGridButtonView *button in _pageButtons ) {
        if( i == currentPageId )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) setPatternButtonState
{
    // TODO put a dim light if there are notes in the pattern

    __block uint currentPageId;
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        currentPageId = _currentPattern.inPage.id.unsignedIntValue;
    }];
    
    uint pageId = 0;
    
    // Set all other page pattern buttons to 0
    for ( EatsGridButtonView *button in _patternsOnOtherPagesButtons ) {
        button.buttonState = EatsButtonViewState_Inactive;
        button.inactiveBrightness = 0;
    }
    
    for( SequencerPageState *pageState in _sharedSequencerState.pageStates ) {
        
        uint i;
        
        // For this page
        if( pageId == currentPageId ) {
            
            i = 0;
            for ( EatsGridButtonView *button in _patternButtons ) {
                if( i == pageState.currentPatternId.intValue )
                    button.buttonState = EatsButtonViewState_Active;
                else
                    button.buttonState = EatsButtonViewState_Inactive;
                
                __block BOOL isPatternAt = NO;
                
                [self.managedObjectContext performBlockAndWait:^(void) {
                    if( [[[_currentPattern.inPage.patterns objectAtIndex:i] notes] count] )
                        isPatternAt = YES;
                }];
                
                if( i == pageState.nextPatternId.intValue && pageState.nextPatternId )
                    button.inactiveBrightness = 8;
                else if( isPatternAt )
                    button.inactiveBrightness = 5;
                else
                    button.inactiveBrightness = 0;
                i++;
            }
            
        // For other pages
        } else if( pageState.playMode.intValue != EatsSequencerPlayMode_Pause )  {
            
            i = 0;
            for ( EatsGridButtonView *button in _patternsOnOtherPagesButtons ) {
                if( i == pageState.currentPatternId.intValue )
                    button.buttonState = EatsButtonViewState_Active;
                
                if( i == pageState.nextPatternId.intValue && pageState.nextPatternId )
                    button.inactiveBrightness = 8;
                i++;
            }
        }
        
        pageId ++;
    }
}

- (void) setLoopBraceViewStartAndEnd
{
    [self.managedObjectContext performBlockAndWait:^(void) {
        
        _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:_currentPattern.inPage.loopStart.intValue width:self.width];
        _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:_currentPattern.inPage.loopEnd.intValue width:self.width];
        
    }];
}

- (void) setLoopStart:(NSNumber *)startStep andEnd:(NSNumber *)endStep
{
    [self.managedObjectContext performBlockAndWait:^(void) {
        _currentPattern.inPage.loopStart = startStep;
        _currentPattern.inPage.loopEnd = endStep;
        [self.managedObjectContext save:nil];
    }];
}

- (void) animateIn:(NSTimer *)timer
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        _animationFrame ++;
        
        [timer invalidate];
        
        [self animateIncrement:1];
    });
    
    [self updateView];
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        // Final frame
        if( _animationFrame == self.height / 2 ) {
            _animationTimer = nil;
        } else {
            [self scheduleAnimateInTimer];
        }
    
    });

}

- (void) animateOut:(NSTimer *)timer
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        _animationFrame ++;
        
        [timer invalidate];
        
        // Final frame
        if( _patternView.height == self.height - 1 ) {
            _animationTimer = nil;
            
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
        } else {
            [self scheduleAnimateOutTimer];
        }
        
        [self animateIncrement:-1];
        
    });
    
    [self updateView];
}

- (void) scheduleAnimateInTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 1 + ANIMATION_EASE * _animationFrame ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateIn:)
                                                         userInfo:nil
                                                          repeats:NO];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_animationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_animationTimer forMode: NSEventTrackingRunLoopMode];
        
    });
}

- (void) scheduleAnimateOutTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 1 + ANIMATION_EASE * ( (self.height / 2) - 1 - _animationFrame) ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateOut:)
                                                         userInfo:nil
                                                          repeats:NO];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_animationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_animationTimer forMode: NSEventTrackingRunLoopMode];
    });
}

- (void) animateIncrement:(int)amount
{
    _loopBraceView.y += amount;
    if( _loopBraceView.y < 0 )
        _loopBraceView.visible = NO;
    else
        _loopBraceView.visible = YES;
    
    _patternView.y += amount;
    _patternView.height += amount * -1;
    
    for (EatsGridButtonView *button in _pageButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in _patternButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in _patternsOnOtherPagesButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in _playModeButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in _controlButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
}

- (void) decrementBPMRepeat:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [timer invalidate];
        _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(decrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_bpmRepeatTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
        
        [self decrementBPM];
    });
}

- (void) incrementBPMRepeat:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [timer invalidate];
        _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(incrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_bpmRepeatTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
        
        [self incrementBPM];
    });
}

- (void) decrementBPM
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        [self.managedObjectContext performBlockAndWait:^(void) {
            float newBPM = roundf( [_sequencer.bpm floatValue] ) - 1;
            if( newBPM < 20 )
                newBPM = 20;
            _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
            [self.managedObjectContext save:nil];
        }];
        
    });
}

- (void) incrementBPM
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        [self.managedObjectContext performBlockAndWait:^(void) {
            float newBPM = roundf( [_sequencer.bpm floatValue] ) + 1;
            if( newBPM > 300 )
                newBPM = 300;
            _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
            [self.managedObjectContext save:nil];
        }];
        
    });
}

- (void) clearIncrement:(NSTimer *)timer
{
    if( _patternView.wipe >= 100 ) {
        [self stopClear];
        NSLog(@"TODO: Clear pattern");
        // TODO: Link this back to the document method to avoid doubling up? Or create a method in Sequencer that clears?
        
    } else {
        _patternView.wipe = _patternView.wipe + 10;
    }
    
    [self updateView];
}

- (void) stopClear
{
    [_clearTimer invalidate];
    _clearTimer = nil;
    _patternView.wipe = 0;
    _clearButton.buttonState = EatsButtonViewState_Inactive;
}



#pragma mark - Sub view delegate methods

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        __block uint currentPageId;
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            currentPageId = _currentPattern.inPage.id.unsignedIntValue;
        }];
        
        SequencerPageState *currentPageState = [_sharedSequencerState.pageStates objectAtIndex:currentPageId];
        
        BOOL buttonDown = [down boolValue];
        
        // Page buttons
        if ( [_pageButtons containsObject:sender] ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                if([self.delegate respondsToSelector:@selector(setNewPageId:)])
                    [self.delegate performSelector:@selector(setNewPageId:) withObject:[NSNumber numberWithUnsignedInteger:[_pageButtons indexOfObject:sender]]];
            }
        }
        
        // Pattern buttons
        if ( [_patternButtons containsObject:sender] ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                currentPageState.nextPatternId = [NSNumber numberWithUnsignedInteger:[_patternButtons indexOfObject:sender]];
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
            }
        }
        
        // Pattern buttons for other pages
        if ( [_patternsOnOtherPagesButtons containsObject:sender] ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                uint pageId = 0;
                
                for( SequencerPageState *pageState in _sharedSequencerState.pageStates ) {
                    if( currentPageId != pageId )
                        pageState.nextPatternId = [NSNumber numberWithUnsignedInteger:[_patternsOnOtherPagesButtons indexOfObject:sender]];
                    
                    pageId ++;
                }
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
            }
        }
        
        // Play mode pause button
        if( sender == _pauseButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                currentPageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
                currentPageState.nextStep = nil;
                [self setPlayMode];
            }
            
        // Play mode forward button
        } else if( sender == _forwardButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                currentPageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
                currentPageState.nextStep = nil;
                [self setPlayMode];
            }
            
        // Play mode reverse button
        } else if( sender == _reverseButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                currentPageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
                currentPageState.nextStep = nil;
                [self setPlayMode];
            }
            
        // Play mode random button
        } else if( sender == _randomButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                currentPageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];
                currentPageState.nextStep = nil;
                [self setPlayMode];
            }
            
        // BPM- button
        } else if( sender == _bpmDecrementButton ) {
            if ( buttonDown && _sharedPreferences.midiClockSourceName == nil ) {
                
                if( !_bpmRepeatTimer ) {
                    
                    sender.buttonState = EatsButtonViewState_Down;
                    [self decrementBPM];
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                        _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                           target:self
                                                                         selector:@selector(decrementBPMRepeat:)
                                                                         userInfo:nil
                                                                          repeats:YES];
                        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                        
                        // Make sure we fire even when the UI is tracking mouse down stuff
                        [runloop addTimer:_bpmRepeatTimer forMode: NSRunLoopCommonModes];
                        [runloop addTimer:_bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
                        
                    });
                }
                
            } else {
                
                if( _bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                    [_bpmRepeatTimer invalidate];
                    _bpmRepeatTimer = nil;
                }
                
                sender.buttonState = EatsButtonViewState_Inactive;
            }
            
        // BPM+ button
        } else if( sender == _bpmIncrementButton ) {
            if ( buttonDown && _sharedPreferences.midiClockSourceName == nil ) {
                
                if( !_bpmRepeatTimer ) {
                    
                    sender.buttonState = EatsButtonViewState_Down;
                    [self incrementBPM];
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                        _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                           target:self
                                                                         selector:@selector(incrementBPMRepeat:)
                                                                         userInfo:nil
                                                                          repeats:YES];
                        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                        
                        // Make sure we fire even when the UI is tracking mouse down stuff
                        [runloop addTimer:_bpmRepeatTimer forMode: NSRunLoopCommonModes];
                        [runloop addTimer:_bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
                        
                    });
                }
                
            } else {
                
                if( _bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                    [_bpmRepeatTimer invalidate];
                    _bpmRepeatTimer = nil;
                }
                
                sender.buttonState = EatsButtonViewState_Inactive;
            }
            
        // Clear button
        } else if( sender == _clearButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                    _clearTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(clearIncrement:)
                                                                 userInfo:nil
                                                                  repeats:YES];
                    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                    
                    // Make sure we fire even when the UI is tracking mouse down stuff
                    [runloop addTimer:_clearTimer forMode: NSRunLoopCommonModes];
                    [runloop addTimer:_clearTimer forMode: NSEventTrackingRunLoopMode];
                    
                });
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
                
                [self stopClear];
            }
            
            // Exit button
        } else if( sender == _exitButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
            } else {
                
                if( _clearTimer )
                    [self stopClear];
                
                // Start animateOut
                [self animateIncrement:-1];
                
                _animationFrame = 0;
                [self scheduleAnimateOutTimer];
            }
        }
            
    });
    
    [self updateView];
}

- (void) eatsGridLoopBraceViewUpdated:(EatsGridLoopBraceView *)sender
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        [self setLoopStart:[NSNumber numberWithUnsignedInt:[EatsGridUtils percentageToSteps:sender.startPercentage width:self.width]] andEnd:[NSNumber numberWithUnsignedInt:[EatsGridUtils percentageToSteps:sender.endPercentage width:self.width]]];
    
    });
    
    [self updateView];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
    
        dispatch_async(self.bigSerialQueue, ^(void) {
                
            __block SequencerPageState *pageState;
            
            [self.managedObjectContext performBlockAndWait:^(void) {
                pageState = [_sharedSequencerState.pageStates objectAtIndex:_currentPattern.inPage.id.unsignedIntegerValue];
            }];

            // Scrub the loop
            pageState.nextStep = [NSNumber numberWithUnsignedInt:x];
            if( pageState.playMode.intValue == EatsSequencerPlayMode_Pause )
                pageState.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
            [self updateView];
            
        });
        
    }
}

- (void) eatsGridPatternViewSelection:(NSDictionary *)selection sender:(EatsGridPatternView *)sender
{
    dispatch_async(self.bigSerialQueue, ^(void) {
    
        uint start = [[selection valueForKey:@"start"] unsignedIntValue];
        uint end = [[selection valueForKey:@"end"] unsignedIntValue];
        
        [self setLoopStart:[NSNumber numberWithUnsignedInt:start] andEnd:[NSNumber numberWithUnsignedInt:end]];
        
        _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:start width:_loopBraceView.width];
        _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:end width:_loopBraceView.width];
        
    });
}

@end
