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
#define ANIMATION_EASE 0.4

#define FLASH_MIN_BRIGHTNESS 5
#define FLASH_MAX_BRIGHTNESS 10

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
@property int                               animationSpeedMultiplier;

@property NSMutableSet                      *flashingTimers;
@property NSNumber                          *currentlyFlashingStep;
@property NSNumber                          *currentlyFlashingPatternId;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    // Create set
    _flashingTimers = [NSMutableSet setWithCapacity:2];

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
    _animationSpeedMultiplier = 8 / self.height;
    [self animateIncrement:-1];
    [self scheduleAnimateInTimer];
    [self updateView];
}

- (void) dealloc
{
    //[_pattern.inPage removeObserver:self forKeyPath:@"playMode"];
    
    if( _animationTimer )
        [_animationTimer invalidate];
    
    if( _bpmRepeatTimer )
        [_bpmRepeatTimer invalidate];
    
    [self stopAllFlashing];
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
    
    // Start or stop flashing
    NSNumber *nextStep = _pattern.inPage.nextStep;
    if( nextStep == nil && _currentlyFlashingStep != nil ) {
        [self stopObjectFlashing:_patternView];
    } else if( nextStep != _currentlyFlashingStep ) {
        [self stopObjectFlashing:_patternView];
        [self startObjectFlashing:_patternView];
        //[self setObjectFlashing:_patternView];
    }
    _currentlyFlashingStep = nextStep;
    
    NSNumber *nextPatternId = _pattern.inPage.nextPatternId;
    if( nextPatternId == nil && _currentlyFlashingPatternId != nil ) {
        for( EatsGridButtonView *button in _patternButtons ) {
            [self stopObjectFlashing:button];
            button.inactiveBrightness = 0;
        }
        
    } else if( nextPatternId != _currentlyFlashingPatternId ) {
        EatsGridButtonView *nextPatternButton = [_patternButtons objectAtIndex:nextPatternId.intValue];
        
        for( EatsGridButtonView *button in _patternButtons ) {
            if( button == nextPatternButton ) {
                [self stopObjectFlashing:nextPatternButton];
                [self startObjectFlashing:nextPatternButton];
                //[self setObjectFlashing:nextPatternButton];
            } else {
                [self stopObjectFlashing:button];
                button.inactiveBrightness = 0;
            }
        }
    }
    _currentlyFlashingPatternId = nextPatternId;
    
    // Set buttons etc
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
    
    [timer invalidate];
    
    [self animateIncrement:1];
    
    [self updateView];
    
    // Final frame
    if( _animationFrame == self.height / 2 ) {
        _animationTimer = nil;
    } else {
        [self scheduleAnimateInTimer];
    }
    
}

- (void) animateOut:(NSTimer *)timer
{
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
    
    [self updateView];
}

- (void) scheduleAnimateInTimer
{
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 1 + ANIMATION_EASE * _animationFrame ) ) / ANIMATION_FRAMERATE
                                                       target:self
                                                     selector:@selector(animateIn:)
                                                     userInfo:nil
                                                      repeats:NO];
}

- (void) scheduleAnimateOutTimer
{
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 1 + ANIMATION_EASE * ( (self.height / 2) - 1 - _animationFrame) ) ) / ANIMATION_FRAMERATE
                                                       target:self
                                                     selector:@selector(animateOut:)
                                                     userInfo:nil
                                                      repeats:NO];
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
    [timer invalidate];
    _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(decrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    [self decrementBPM];
}

- (void) incrementBPMRepeat:(NSTimer *)timer
{
    [timer invalidate];
    _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(incrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    [self incrementBPM];
}

- (void) decrementBPM
{
    float newBPM = roundf( [_sequencer.bpm floatValue] ) - 1;
    if( newBPM < 20 )
        newBPM = 20;
    _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
}

- (void) incrementBPM
{
    float newBPM = roundf( [_sequencer.bpm floatValue] ) + 1;
    if( newBPM > 300 )
        newBPM = 300;
    _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
}


#pragma mark - Flashing methods

- (void) startObjectFlashing:(id)object
{
    // Keep track of the object and animation frame by attaching it to the timer
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:object, @"object",
                                                                                      [NSNumber numberWithInt:0], @"animationFrame",
                                                                                      nil];
    
    [_flashingTimers addObject:[NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateObjectFlashing:)
                                                     userInfo:userInfo
                                                      repeats:YES]];
    [self setObjectFlashing:object];
}

- (void) stopObjectFlashing:(id)object
{
    NSTimer *timer = [[_flashingTimers objectsPassingTest:^(id obj, BOOL *stop){
        NSTimer *aTimer = obj;
        return [[aTimer.userInfo valueForKey:@"object"] isEqual:object];
    }] anyObject];
    
    if( timer ) {
        NSLog(@"Remove");
        [timer invalidate];
        [_flashingTimers removeObject:timer];
    }
}

- (void) stopAllFlashing
{
    for( NSTimer *timer in _flashingTimers ) {
        [timer invalidate];
    }
    [_flashingTimers removeAllObjects];
}

- (void) setObjectFlashing:(id)object
{
    NSTimer *timer = [[_flashingTimers objectsPassingTest:^(id obj, BOOL *stop){
        NSTimer *aTimer = obj;
        return [[aTimer.userInfo valueForKey:@"object"] isEqual:object];
    }] anyObject];
    
    
    NSNumber *animationFrame = [timer.userInfo valueForKey:@"animationFrame"];
    int brightness = FLASH_MAX_BRIGHTNESS - animationFrame.intValue;
    
    // ButtonView
    if( [object class] == [EatsGridButtonView class] ) {
        EatsGridButtonView *button = object;
        button.inactiveBrightness = brightness;
        
    // PatternView
    } else if( [object class] == [EatsGridPatternView class] ) {
        EatsGridPatternView *patternView = object;
        patternView.flashBrightness = brightness;
    }
    
    animationFrame = [NSNumber numberWithInt:animationFrame.intValue + 1];
    if( brightness < FLASH_MIN_BRIGHTNESS )
        animationFrame = [NSNumber numberWithInt:0];
    
    [timer.userInfo setValue:animationFrame forKey:@"animationFrame"];
}

- (void) updateObjectFlashing:(NSTimer *)timer
{
    [self setObjectFlashing:[timer.userInfo valueForKey:@"object"]];
    [self updateView];
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
            _pattern.inPage.nextPatternId = [NSNumber numberWithUnsignedInteger:[_patternButtons indexOfObject:sender]];
        }
    }
    
    // Play mode pause button
    if( sender == _pauseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
            _pattern.inPage.nextStep = nil;
            [self setPlayMode:EatsSequencerPlayMode_Pause];
        }
        
    // Play mode forward button
    } else if( sender == _forwardButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
            _pattern.inPage.nextStep = nil;
            [self setPlayMode:EatsSequencerPlayMode_Forward];
        }
        
    // Play mode reverse button
    } else if( sender == _reverseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
            _pattern.inPage.nextStep = nil;
            [self setPlayMode:EatsSequencerPlayMode_Reverse];
        }
        
    // Play mode random button
    } else if( sender == _randomButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            _pattern.inPage.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];
            _pattern.inPage.nextStep = nil;
            [self setPlayMode:EatsSequencerPlayMode_Random];
        }
        
    // BPM- button
    } else if( sender == _bpmDecrementButton ) {
        if ( buttonDown && _sharedPreferences.midiClockSourceName == nil ) {
            
            if( !_bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                [self decrementBPM];
                
                _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(decrementBPMRepeat:)
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
                [self incrementBPM];
                
                _bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(incrementBPMRepeat:)
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
            [self scheduleAnimateOutTimer];
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
        [self updateView];
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
