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
#import "Preferences.h"

#define ANIMATION_FRAMERATE 15

@interface EatsGridPlayViewController ()

@property Sequencer                         *sequencer;
@property SequencerPattern                  *pattern;
@property Preferences                       *sharedPreferences;

@property EatsGridLoopBraceView             *loopBraceView;
@property EatsGridPatternView               *patternView;

@property NSMutableArray                    *pageButtons;
@property NSMutableArray                    *patternButtons;
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

@property NSTimer                           *animationTimer;
@property uint                              animationFrame;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    
    // Get the sequencer
    NSFetchRequest *sequencerRequest = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
    NSArray *sequencerMatches = [self.managedObjectContext executeFetchRequest:sequencerRequest error:nil];
    _sequencer = [sequencerMatches lastObject];
    
    // Get the pattern
    _pattern = [self.delegate valueForKey:@"pattern"];
    
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
    _loopBraceView.y = - (self.height / 2) + 4;
    _loopBraceView.width = self.width;
    _loopBraceView.height = 1;
    _loopBraceView.fillBar = YES;
    _loopBraceView.visible = NO;
    _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:_pattern.inPage.loopStart.intValue width:self.width];
    _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:_pattern.inPage.loopEnd.intValue width:self.width];
    
    // Pattern view
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.x = 0;
    _patternView.y = 1;
    _patternView.width = self.width;
    _patternView.height = self.height - 1;
    _patternView.foldFrom = EatsPatternViewFoldFrom_Top;
    _patternView.mode = EatsPatternViewMode_Play;
    _patternView.pattern = _pattern;
    _patternView.patternHeight = self.height;
    
    // Set top left buttons correctly
    [self setActivePageButton];
    [self setActivePatternButton];
    
    // Make the correct playMode button active and listen for changes to keep it correct
    [self setPlayMode:[_pattern.inPage.playMode intValue]];
    //[_pattern.inPage addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Add everything to sub views
    self.subViews = [[NSMutableSet alloc] initWithObjects:_loopBraceView, _patternView, nil];
    [self.subViews addObjectsFromArray:_pageButtons];
    [self.subViews addObjectsFromArray:_patternButtons];
    [self.subViews addObjectsFromArray:_playModeButtons];
    [self.subViews addObjectsFromArray:_controlButtons];
    
    // Start animateIn
    _animationFrame = 0;
    int speedMultiplier = 8 / self.height;
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( 1.0 * speedMultiplier ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateIn:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) dealloc
{
    //[_pattern.inPage removeObserver:self forKeyPath:@"playMode"];
    
    if( _animationTimer )
        [_animationTimer invalidate];
    
    if( _bpmRepeatTimer )
        [_bpmRepeatTimer invalidate];
}

- (void) updateView
{
    if( _pattern != [self.delegate valueForKey:@"pattern"] )
        _pattern = [self.delegate valueForKey:@"pattern"];
    
    // Update PatternView sub view
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", _pattern];
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
    
    _pattern = [patternMatches lastObject];
    
    _patternView.pattern = _pattern;
    _patternView.currentStep = _pattern.inPage.currentStep.unsignedIntValue;
    
    [self setPlayMode:_pattern.inPage.playMode.intValue];    
    [self setActivePageButton];
    [self setActivePatternButton];
    _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:_pattern.inPage.loopStart.intValue width:self.width];
    _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:_pattern.inPage.loopEnd.intValue width:self.width];
    
    [super updateView];
}

// Activates the playMode button
- (void) setPlayMode:(EatsSequencerPlayMode)playMode
{
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
    uint i = 0;
    for ( EatsGridButtonView *button in _pageButtons ) {
        if( i == [_pattern.inPage.id intValue] )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) setActivePatternButton
{
    uint i = 0;
    for ( EatsGridButtonView *button in _patternButtons ) {
        if( i == _pattern.inPage.currentPatternId.intValue )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    
    if ( [keyPath isEqual:@"playMode"] )
        [self setPlayMode:[[change valueForKey:@"new"] intValue]];
}

- (void) animateIn:(NSTimer *)timer
{
    _animationFrame ++;
    
    [self animateIncrement:1];
    
    [self updateView];
    
    // Final frame
    if( _animationFrame == (self.height / 2) - 1 ) { 
        [timer invalidate];
        _animationTimer = nil;
    }
    
}

- (void) animateOut:(NSTimer *)timer
{
    _animationFrame ++;
        
    if( _patternView.height == self.height - 1 ) { // Final frame
        
        [timer invalidate];
        _animationTimer = nil;
        
        [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
    }
    
    
    [self animateIncrement:-1];
    
    [self updateView];
}

// TODO: Add ease to animation

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

- (void) decrementBPM:(NSTimer *)timer
{
    [timer invalidate];
    _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(decrementBPM:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    if( [_sequencer.bpm intValue] > 20 )
        _sequencer.bpm = [NSNumber numberWithInt:[_sequencer.bpm intValue] - 1];
}

- (void) incrementBPM:(NSTimer *)timer
{
    [timer invalidate];
    _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(incrementBPM:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    if( [_sequencer.bpm intValue] < 300 )
    _sequencer.bpm = [NSNumber numberWithInt:[_sequencer.bpm intValue] + 1];
}



#pragma mark - Sub view delegate methods

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender
{
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
            
            if([self.delegate respondsToSelector:@selector(setNewPatternId:)])
                [self.delegate performSelector:@selector(setNewPatternId:) withObject:[NSNumber numberWithUnsignedInteger:[_patternButtons indexOfObject:sender]]];
        }
    }
    
    // Play mode pause button
    if( sender == _pauseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
            [self setPlayMode:EatsSequencerPlayMode_Pause];
        }
        
    // Play mode forward button
    } else if( sender == _forwardButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
            [self setPlayMode:EatsSequencerPlayMode_Forward];
        }
        
    // Play mode reverse button
    } else if( sender == _reverseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
            [self setPlayMode:EatsSequencerPlayMode_Reverse];
        }
        
    // Play mode random button
    } else if( sender == _randomButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];
            [self setPlayMode:EatsSequencerPlayMode_Random];
        }
        
    // BPM- button
    } else if( sender == _bpmDecrementButton ) {
        if ( buttonDown && _sharedPreferences.midiClockSourceName == nil ) {
            
            if( !_bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                if( [_sequencer.bpm intValue] > 20 )
                    _sequencer.bpm = [NSNumber numberWithInt:[_sequencer.bpm intValue] - 1];
                
                _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(decrementBPM:)
                                                                     userInfo:nil
                                                                      repeats:YES];
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
                if( [_sequencer.bpm intValue] < 300 )
                    _sequencer.bpm = [NSNumber numberWithInt:[_sequencer.bpm intValue] + 1];
                
                _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(incrementBPM:)
                                                                     userInfo:nil
                                                                      repeats:YES];
            }
            
        } else {
            
            if( _bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                [_bpmRepeatTimer invalidate];
                _bpmRepeatTimer = nil;
            }
            
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // TODO: Clear button
    } else if( sender == _clearButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
        } else {
            NSLog(@"Clear pattern");
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // Exit button
    } else if( sender == _exitButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
        } else {
                        
            // Start animateOut
            [self animateIncrement:-1];
            
            _animationFrame = 0;
            int speedMultiplier = 8 / self.height;
            _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( 1.0 * speedMultiplier ) / ANIMATION_FRAMERATE
                                                                   target:self
                                                                 selector:@selector(animateOut:)
                                                                 userInfo:nil
                                                                  repeats:YES];
            return;
        }
    }
    
    [self updateView];

}

- (void) eatsGridLoopBraceViewUpdated:(EatsGridLoopBraceView *)sender
{
    _pattern.inPage.loopStart = [NSNumber numberWithUnsignedInt:[EatsGridUtils percentageToSteps:sender.startPercentage width:self.width]];
    _pattern.inPage.loopEnd = [NSNumber numberWithUnsignedInt:[EatsGridUtils percentageToSteps:sender.endPercentage width:self.width]];
    
    [self updateView];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
        // Scrub the loop
        _pattern.inPage.nextStep = [NSNumber numberWithUnsignedInt:x];
        if( [_pattern.inPage.playMode intValue] == EatsSequencerPlayMode_Pause )
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
    }
}

- (void) eatsGridPatternViewSelection:(NSDictionary *)selection sender:(EatsGridPatternView *)sender
{
    uint start = [[selection valueForKey:@"start"] unsignedIntValue];
    uint end = [[selection valueForKey:@"end"] unsignedIntValue];
    
    _pattern.inPage.loopStart = [NSNumber numberWithUnsignedInt:start];
    _pattern.inPage.loopEnd = [NSNumber numberWithUnsignedInt:end];
    
    _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:start width:_loopBraceView.width];
    _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:end width:_loopBraceView.width];
}

@end
