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
#import "Sequencer.h"
#import "Preferences.h"

#define ANIMATION_FRAMERATE 15
#define IN_OUT_ANIMATION_EASE 0.12
#define PAGE_ANIMATION_EASE 0.04

@interface EatsGridPlayViewController ()

@property Preferences                       *sharedPreferences;
@property Sequencer                         *sequencer;

@property EatsGridHorizontalShiftView       *transposeView;
@property EatsGridLoopBraceView             *loopBraceView;
@property EatsGridPatternView               *patternView;

@property NSMutableArray                    *pageButtons;
@property NSMutableArray                    *patternButtons;
@property NSMutableArray                    *patternsOnOtherPagesButtons;
@property NSMutableArray                    *scrubOtherPagesButtons;

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

@property NSTimer                           *inOutAnimationTimer;
@property uint                              inOutAnimationFrame;

@property NSTimer                           *pageAnimationTimer;
@property uint                              pageAnimationFrame;

@property float                             animationSpeedMultiplier;

@property NSDictionary                      *lastDownPatternKey;
@property BOOL                              copiedPattern;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    _animationSpeedMultiplier = 8.0 / self.height;
    
    // Get prefs
    self.sharedPreferences = [Preferences sharedPreferences];
    
    // Create the sub views
    
    // Page buttons
    _pageButtons = [[NSMutableArray alloc] initWithCapacity:8];
    for( int i = 0; i < 8; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height - 4) + 1;
        if( self.width < 16 )
            button.y ++;
        button.visible = NO;
        [_pageButtons addObject:button];
    }
    
    // Pattern buttons
    uint numberOfPatterns = self.width;
    if( numberOfPatterns > 16 )
        numberOfPatterns = 16;
    
    // Pattern buttons for this page on small grids
    if( self.height < 16 || self.width < 16 ) {
        _patternButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
        for( int i = 0; i < numberOfPatterns; i ++ ) {
            EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
            button.delegate = self;
            button.x = i;
            button.y = - (self.height - 4) + 3;
            button.visible = NO;
            [_patternButtons addObject:button];
        }
    }
    
    // Pattern buttons for other pages on small grids
    if( self.height < 16 && self.width > 8 ) {
        _patternsOnOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
        for( int i = 0; i < numberOfPatterns; i ++ ) {
            EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
            button.delegate = self;
            button.x = i;
            button.y = - (self.height - 4) + 2;
            button.visible = NO;
            [_patternsOnOtherPagesButtons addObject:button];
        }
    }
    
    // Pattern buttons for all pages on large grids
    if( self.height > 8 && self.width > 8 ) {
        _patternsOnOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns * 8];
        // Rows
        for( int i = 0; i < 8; i ++ ) {
            // Columns
            for( int j = 0; j < numberOfPatterns; j ++ ) {
                EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
                button.delegate = self;
                button.x = j;
                button.y = - (self.height - 4) + 2 + i;
                button.inactiveBrightness = 4;
                button.visible = NO;
                [_patternsOnOtherPagesButtons addObject:button];
            }
        }
    }
    
    // Scrub buttons for other pages and transpose slider, if there's space
    if( self.height > 8 ) {
        _scrubOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:self.width];
        for( int i = 0; i < self.width; i ++ ) {
            EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
            button.delegate = self;
            button.x = i;
            button.y = - 1;
            button.visible = NO;
            [_scrubOtherPagesButtons addObject:button];
        }
        
        _transposeView = [[EatsGridHorizontalShiftView alloc] init];
        _transposeView.delegate = self;
        _transposeView.x = 0;
        _transposeView.y = - 2;
        _transposeView.width = self.width;
        _transposeView.height = 1;
        _transposeView.visible = NO;
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
        button.y = - (self.height - 4) + 1;
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
    _exitButton.inactiveBrightness = 5;
    
    _controlButtons = [NSArray arrayWithObjects:_bpmDecrementButton, _bpmIncrementButton, _clearButton, _exitButton, nil];
    
    for( EatsGridButtonView *button in _controlButtons ) {
        button.delegate = self;
        button.y = - (self.height - 4) + 1;
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
    
    // Pattern view
    _patternView = [[EatsGridPatternView alloc] init];
    _patternView.delegate = self;
    _patternView.x = 0;
    _patternView.y = 1;
    _patternView.width = self.width;
    _patternView.height = self.height - 1;
    _patternView.foldFrom = EatsPatternViewFoldFrom_Top;
    _patternView.mode = EatsPatternViewMode_Play;
    _patternView.patternHeight = self.height;
    
    // Add everything to sub views
    self.subViews = [[NSMutableSet alloc] initWithObjects:_loopBraceView, _patternView, nil];
    [self.subViews addObjectsFromArray:_pageButtons];
    [self.subViews addObjectsFromArray:_patternButtons];
    [self.subViews addObjectsFromArray:_patternsOnOtherPagesButtons];
    if( self.height > 8 ) {
        [self.subViews addObjectsFromArray:_scrubOtherPagesButtons];
        [self.subViews addObject:_transposeView];
    }
    [self.subViews addObjectsFromArray:_playModeButtons];
    [self.subViews addObjectsFromArray:_controlButtons];
    
    // Update everything
    [self updatePage];
    [self updatePlayMode];
    [self updatePattern];
    if( self.height > 8 ) {
        [self updateTranspose];
        [self updateScrubOtherPages];
    }
    [self updateLoop];
    [self updatePatternNotes];
    
    
    // Sequencer page notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageLoopDidChange:) name:kSequencerPageLoopDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageTransposeDidChange:) name:kSequencerPageTransposeDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageTransposeZeroStepDidChange:) name:kSequencerPageTransposeZeroStepDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pagePatternNotesDidChange:) name:kSequencerPagePatternNotesDidChangeNotification object:self.sequencer];
    
    // Sequencer note notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteLengthDidChange:) name:kSequencerNoteLengthDidChangeNotification object:self.sequencer];
    
    // Sequencer state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateCurrentPageDidChangeLeft:) name:kSequencerStateCurrentPageDidChangeLeftNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateCurrentPageDidChangeRight:) name:kSequencerStateCurrentPageDidChangeRightNotification object:self.sequencer];
    
    // Sequencer page state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateCurrentPatternIdDidChange:) name:kSequencerPageStateCurrentPatternIdDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateNextPatternIdDidChange:) name:kSequencerPageStateNextPatternIdDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateCurrentStepDidChange:) name:kSequencerPageStateCurrentStepDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateNextStepDidChange:) name:kSequencerPageStateNextStepDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStatePlayModeDidChange:) name:kSequencerPageStatePlayModeDidChangeNotification object:self.sequencer];
    
    
    // Start animateIn
    self.inOutAnimationFrame = 0;
    [self animateInOutIncrement:-1];
    [self scheduleAnimateInTimer];
    
    [self updateView];
}

- (void) dealloc
{
    if( self.inOutAnimationTimer )
        [self.inOutAnimationTimer invalidate];
    
    if( self.pageAnimationTimer )
        [self.pageAnimationTimer invalidate];
    
    if( self.bpmRepeatTimer )
        [self.bpmRepeatTimer invalidate];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Private methods

- (void) animateIn:(NSTimer *)timer
{
    self.inOutAnimationFrame ++;
    
    [timer invalidate];
    
    [self animateInOutIncrement:1];
    
    [self updateView];
    
    // Final frame
    if( self.inOutAnimationFrame == self.height - 4 ) {
        self.inOutAnimationTimer = nil;
    } else {
        [self scheduleAnimateInTimer];
    }

}

- (void) animateOut:(NSTimer *)timer
{
    self.inOutAnimationFrame ++;
    
    [timer invalidate];
    
    // Final frame
    if( _patternView.height == self.height - 1 ) {
        self.inOutAnimationTimer = nil;
        
        [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
    } else {
        [self scheduleAnimateOutTimer];
    }
    
    [self animateInOutIncrement:-1];
        
    [self updateView];
}

- (void) scheduleAnimateInTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.inOutAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 0.1 + IN_OUT_ANIMATION_EASE * self.inOutAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateIn:)
                                                         userInfo:nil
                                                          repeats:NO];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:self.inOutAnimationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSEventTrackingRunLoopMode];
        
    });
}

- (void) scheduleAnimateOutTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        int frameCountdown = ( (self.height / 2) - 1 - self.inOutAnimationFrame);
        self.inOutAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 0.1 + IN_OUT_ANIMATION_EASE * frameCountdown ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateOut:)
                                                         userInfo:nil
                                                          repeats:NO];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:self.inOutAnimationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSEventTrackingRunLoopMode];
    });
}

- (void) animateInOutIncrement:(int)amount
{
    if( _transposeView ) {
        _transposeView.y += amount;
        if( _transposeView.y < 0 )
            _transposeView.visible = NO;
        else
            _transposeView.visible = YES;
    }
    
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
    for (EatsGridButtonView *button in _scrubOtherPagesButtons) {
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

- (void) pageLeft:(NSTimer *)timer
{
    self.pageAnimationFrame ++;
    
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    [self animatePageIncrement:1];
    
    [self updateView];
    
    // Final frame
    if( self.pageAnimationFrame == self.width - 5 ) {
        self.pageAnimationTimer = nil;
    } else {
        [self scheduleAnimatePageLeftTimer];
    }
}

- (void) pageRight:(NSTimer *)timer
{
    self.pageAnimationFrame ++;
    
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    [self animatePageIncrement:-1];
    
    [self updateView];
    
    // Final frame
    if( self.pageAnimationFrame == self.width - 5 ) {
        self.pageAnimationTimer = nil;
    } else {
        [self scheduleAnimatePageRightTimer];
    }
}

- (void) scheduleAnimatePageLeftTimer
{
    // Haven't attached this to the run loop because the async seemed to mean timers could overlap
    self.pageAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 0.1 + PAGE_ANIMATION_EASE * self.pageAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                               target:self
                                                             selector:@selector(pageLeft:)
                                                             userInfo:nil
                                                              repeats:NO];
}

- (void) scheduleAnimatePageRightTimer
{
    self.pageAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * _animationSpeedMultiplier ) * ( 0.1 + PAGE_ANIMATION_EASE * self.pageAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                              target:self
                                                            selector:@selector(pageRight:)
                                                            userInfo:nil
                                                             repeats:NO];
}

- (void) animatePageIncrement:(int)amount
{
//    NSLog(@"Page ani %i", amount);
    
    _loopBraceView.x += amount;
    _patternView.x += amount;

    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        
        float percentageOfAnimationComplete = (float)self.pageAnimationFrame / ( self.width - 1 );
        float opacity = ( 0.7 * percentageOfAnimationComplete ) + 0.3;
        
        _loopBraceView.opacity = opacity;
        _patternView.opacity = opacity;
        
    } else if( _loopBraceView.opacity != 1 || _patternView.opacity != 1 ) {
        _loopBraceView.opacity = 1;
        _patternView.opacity = 1;
    }
}


- (void) decrementBPMRepeat:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [timer invalidate];
        self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(decrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:self.bpmRepeatTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
        
        [self.sequencer decrementBPM];
    });
}

- (void) incrementBPMRepeat:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [timer invalidate];
        self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(incrementBPMRepeat:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:self.bpmRepeatTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
        
        [self.sequencer incrementBPM];
    });
}

- (void) clearIncrement:(NSTimer *)timer
{
    if( _patternView.wipe >= 100 ) {
        [self stopClear];
        [self.sequencer clearNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
        
    } else {
        _patternView.wipe = _patternView.wipe + 10;
        [self updateView];
    }
}

- (void) stopClear
{
    [_clearTimer invalidate];
    _clearTimer = nil;
    _patternView.wipe = 0;
    _clearButton.buttonState = EatsButtonViewState_Inactive;
}



#pragma mark - Sub view updates

- (void) updatePageLeft
{
    // Start animate left
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    _loopBraceView.x = - self.width + 4;
    _patternView.x = - self.width + 4;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        _loopBraceView.opacity = 0;
        _patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:1];
    [self scheduleAnimatePageLeftTimer];
    
    [self updatePage];
    
    [self updateView];
}

- (void) updatePageRight
{
    // Start animate right
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    _loopBraceView.x = self.width - 4;
    _patternView.x = self.width - 4;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        _loopBraceView.opacity = 0;
        _patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:-1];
    [self scheduleAnimatePageRightTimer];
    
    [self updatePage];
    
    [self updateView];
}

- (void) updatePage
{
    uint i = 0;
    for ( EatsGridButtonView *button in _pageButtons ) {
        if( i == self.sequencer.currentPageId )
            button.buttonState = EatsButtonViewState_Active;
        else if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) updatePlayMode
{
    uint i = 0;
    for ( EatsGridButtonView *button in _playModeButtons ) {
        if( i == [self.sequencer playModeForPage:self.sequencer.currentPageId] )
            button.buttonState = EatsButtonViewState_Active;
        else if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) updatePattern
{
    // Set all other page pattern buttons to 0
    for ( EatsGridButtonView *button in _patternsOnOtherPagesButtons ) {
        if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
        button.inactiveBrightness = 0;
    }
    
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        
        int playMode = [self.sequencer playModeForPage:pageId];
        int currentPatternId = [self.sequencer currentPatternIdForPage:pageId];
        NSNumber *nextPatternId = [self.sequencer nextPatternIdForPage:pageId];
        
        uint patternButtonId;
        
        // For large grids
        if( self.height > 8 && self.width > 8 ) {
            
            NSRange range;
            range.length = self.width;
            if (range.length > 16)
                range.length = 16;
            range.location = pageId * range.length;
            
            NSArray *patternsRow = [_patternsOnOtherPagesButtons subarrayWithRange:range];
            
            patternButtonId = 0;
            for ( EatsGridButtonView *button in patternsRow ) {
                
                // Activate or deactivate
                if( patternButtonId == currentPatternId && playMode != EatsSequencerPlayMode_Pause )
                    button.buttonState = EatsButtonViewState_Active;
                else if( button.buttonState != EatsButtonViewState_Down )
                    button.buttonState = EatsButtonViewState_Inactive;
                
                // Next pattern
                if( nextPatternId && patternButtonId == nextPatternId.intValue && playMode != EatsSequencerPlayMode_Pause )
                    button.inactiveBrightness = 8;
                // Not playing but current pattern
                else if( patternButtonId == currentPatternId )
                    button.inactiveBrightness = 4;
                // Has some notes
                else if( [self.sequencer numberOfNotesForPattern:patternButtonId inPage:pageId] )
                    button.inactiveBrightness = 3;
                // Nothing
                else
                    button.inactiveBrightness = 0;
                
                // Is active page
                if( pageId == self.sequencer.currentPageId )
                    button.inactiveBrightness += 3;

                patternButtonId ++;
            }
            
        // For smaller grids
        } else {
            // For this page
            if( pageId == self.sequencer.currentPageId ) {
                
                patternButtonId = 0;
                for ( EatsGridButtonView *button in _patternButtons ) {
                    
                    // Activate playing or next if pattern quantization is off
                    if( patternButtonId == currentPatternId && playMode != EatsSequencerPlayMode_Pause )
                        button.buttonState = EatsButtonViewState_Active;
                    else if( button.buttonState != EatsButtonViewState_Down )
                        button.buttonState = EatsButtonViewState_Inactive;
                    
                    // Not playing but current pattern
                    if( patternButtonId == currentPatternId )
                        button.inactiveBrightness = 10;
                    // Next pattern
                    else if( nextPatternId && patternButtonId == nextPatternId.intValue )
                        button.inactiveBrightness = 8;
                    // Has some notes
                    else if( [self.sequencer numberOfNotesForPattern:patternButtonId inPage:pageId] )
                        button.inactiveBrightness = 6;
                    // Nothing
                    else
                        button.inactiveBrightness = 0;
                    patternButtonId ++;
                }
                
            // For other pages
            } else if( playMode != EatsSequencerPlayMode_Pause )  {
                
                patternButtonId = 0;
                for ( EatsGridButtonView *button in _patternsOnOtherPagesButtons ) {
                    
                    // Playing pattern
                    if( patternButtonId == currentPatternId )
                        button.buttonState = EatsButtonViewState_Active;
                    
                    // Next pattern
                    if( nextPatternId && patternButtonId == nextPatternId.intValue )
                        button.inactiveBrightness = 8;
                    patternButtonId ++;
                }
            }
        }
    }
}

- (void) updateTranspose
{
    _transposeView.shift = [self.sequencer transposeForPage:self.sequencer.currentPageId];
    _transposeView.zeroStep = [self.sequencer transposeZeroStepForPage:self.sequencer.currentPageId];
}

- (void) updateScrubOtherPages
{
    // Set all other page pattern buttons to 0
    for ( EatsGridButtonView *button in _scrubOtherPagesButtons ) {
        if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
    }
    
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        if( pageId != self.sequencer.currentPageId && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Pause )
            [[_scrubOtherPagesButtons objectAtIndex:[self.sequencer currentStepForPage:pageId] ] setButtonState:EatsButtonViewState_Active];
    }
}


- (void) updateLoop
{
    _loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:[self.sequencer loopStartForPage:self.sequencer.currentPageId] width:self.width];
    _loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:[self.sequencer loopEndForPage:self.sequencer.currentPageId] width:self.width];
}

- (void) updatePatternNotes
{
    self.patternView.notes = [self.sequencer notesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Reverse )
        self.patternView.drawNotesForReverse = YES;
    else
        self.patternView.drawNotesForReverse = NO;
    self.patternView.currentStep = [self.sequencer currentStepForPage:self.sequencer.currentPageId];
    self.patternView.nextStep = [self.sequencer nextStepForPage:self.sequencer.currentPageId];
}




#pragma mark - Notifications

// Sequencer page notifications
- (void) pageLoopDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updateLoop];
        [self updateView];
    }
}

- (void) pageTransposeDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updateTranspose];
        [self updateView];
    }
}

- (void) pageTransposeZeroStepDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updateTranspose];
        [self updateView];
    }
}

- (void) pagePatternNotesDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
        [self updatePatternNotes];
        [self updateView];
    }
}

// Sequencer note notifications
- (void) noteLengthDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
        [self updatePatternNotes];
        [self updateView];
    }
}

// Sequencer state notifications
- (void) stateCurrentPageDidChangeLeft:(NSNotification *)notification
{
    [self updatePageLeft];
    [self updatePlayMode];
    [self updatePattern];
    if( self.height > 8 ) {
        [self updateTranspose];
        [self updateScrubOtherPages];
    }
    [self updateLoop];
    [self updatePatternNotes];
    [self updateView];
}

- (void) stateCurrentPageDidChangeRight:(NSNotification *)notification
{
    [self updatePageRight];
    [self updatePlayMode];
    [self updatePattern];
    if( self.height > 8 ) {
        [self updateTranspose];
        [self updateScrubOtherPages];
    }
    [self updateLoop];
    [self updatePatternNotes];
    [self updateView];
}

// Sequencer page state notifications
- (void) pageStateCurrentPatternIdDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updatePatternNotes];
    
    [self updatePattern];
    [self updateView];
}

- (void) pageStateNextPatternIdDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updatePatternNotes];
    
    [self updatePattern];
    [self updateView];
}

- (void) pageStateCurrentStepDidChange:(NSNotification *)notification
{
    BOOL needsToUpdate = NO;
    
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updatePatternNotes];
        needsToUpdate = YES;
    }
    
    if( self.height > 8 ) {
        [self updateScrubOtherPages];
        needsToUpdate = YES;
    }
    
    if( needsToUpdate )
        [self updateView];
}

- (void) pageStateNextStepDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updatePatternNotes];
        [self updateView];
    }
}

- (void) pageStatePlayModeDidChange:(NSNotification *)notification
{
    BOOL needsToUpdate = NO;
    
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updatePlayMode];
        [self updatePattern];
        needsToUpdate = YES;
    }
    
    if( self.height > 8 ) {
        [self updateScrubOtherPages];
        needsToUpdate = YES;
    }
    
    if( needsToUpdate )
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
            
            [self.sequencer setCurrentPageId:(int)[_pageButtons indexOfObject:sender]];
            
        } else {
            sender.buttonState = EatsButtonViewState_Inactive;
            [self updatePage];
        }
    }
    
    // Pattern buttons
    if ( [_patternButtons containsObject:sender] ) {
        
        uint pressedPattern = (uint)[_patternButtons indexOfObject:sender];
        
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            
            if( _lastDownPatternKey ) {
                // Copy pattern
                [self.sequencer copyNotesFromPattern:[[_lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] fromPage:self.sequencer.currentPageId toPattern:pressedPattern toPage:self.sequencer.currentPageId];
                _copiedPattern = YES;
                
            } else {
                // Keep track of last down
                _lastDownPatternKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:pressedPattern], @"pattern", nil];
            }
            
        // Release
        } else {
            sender.buttonState = EatsButtonViewState_Inactive;
            
            if( _lastDownPatternKey && [[_lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] == pressedPattern ) {
                
                if( !_copiedPattern ) {
                    // Change pattern
                    [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithUnsignedInt:pressedPattern] forPage:self.sequencer.currentPageId];
                }
            
                _lastDownPatternKey = nil;
                _copiedPattern = NO;
            }
        }
    }
    
    // Pattern buttons for other pages
    if ( [_patternsOnOtherPagesButtons containsObject:sender] ) {
        
        // For large grids
        if( self.height > 8 && self.width > 8 ) {
            
            uint numberOfPatterns = self.width;
            if (numberOfPatterns > 16)
                numberOfPatterns = 16;
            
            uint pressedPattern = [_patternsOnOtherPagesButtons indexOfObject:sender] % numberOfPatterns;
            uint pressedPage = (uint)[_patternsOnOtherPagesButtons indexOfObject:sender] / numberOfPatterns;
            
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                if( _lastDownPatternKey ) {
                    // Copy pattern
                    [self.sequencer copyNotesFromPattern:[[_lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] fromPage:[[_lastDownPatternKey valueForKey:@"page"] unsignedIntValue] toPattern:pressedPattern toPage:pressedPage];
                    _copiedPattern = YES;
                    
                } else {
                    // Keep track of last down
                    _lastDownPatternKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:pressedPage], @"page",
                                                                                     [NSNumber numberWithUnsignedInt:pressedPattern], @"pattern",
                                                                                     nil];
                }
                
            // Release
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
                
                if( _lastDownPatternKey
                   && [[_lastDownPatternKey valueForKey:@"page"] unsignedIntValue] == pressedPage
                   && [[_lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] == pressedPattern ) {
                    
                    if( !_copiedPattern ) {
                        // Change pattern
                        [self.sequencer startOrStopPattern:pressedPattern inPage:pressedPage];
                    }
                    
                    _lastDownPatternKey = nil;
                    _copiedPattern = NO;

                }
                
            }
        
        // Smaller grids (change all patterns at once)
        } else {
            
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithUnsignedInteger:[_patternsOnOtherPagesButtons indexOfObject:sender]]];
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
            }

        }
    }
    
    // Scrub buttons for other pages
    if ( [_scrubOtherPagesButtons containsObject:sender] ) {
        if ( buttonDown ) {
            
            [self.sequencer setNextStep:[NSNumber numberWithUnsignedInteger:[_scrubOtherPagesButtons indexOfObject:sender]] forAllPagesExcept:self.sequencer.currentPageId];
            
            for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
                if( pageId != self.sequencer.currentPageId && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Pause ) {
                    sender.buttonState = EatsButtonViewState_Down;
                    break;
                }
            }
        
        } else {
            sender.buttonState = EatsButtonViewState_Inactive;
        }
    }
    
    // Play mode pause button
    if( sender == _pauseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Pause forPage:self.sequencer.currentPageId];
        }
        
    // Play mode forward button
    } else if( sender == _forwardButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Forward forPage:self.sequencer.currentPageId];
        }
        
    // Play mode reverse button
    } else if( sender == _reverseButton ) {
        if ( buttonDown ) {
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Reverse forPage:self.sequencer.currentPageId];
        }
        
    // Play mode random button
    } else if( sender == _randomButton ) {
        if ( buttonDown ) {
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Random forPage:self.sequencer.currentPageId];
        }
        
    // BPM- button
    } else if( sender == _bpmDecrementButton ) {
        if ( buttonDown && self.sharedPreferences.midiClockSourceName == nil ) {
            
            if( !self.bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                [self.sequencer decrementBPM];
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                    self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(decrementBPMRepeat:)
                                                                     userInfo:nil
                                                                      repeats:YES];
                    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                    
                    // Make sure we fire even when the UI is tracking mouse down stuff
                    [runloop addTimer:self.bpmRepeatTimer forMode: NSRunLoopCommonModes];
                    [runloop addTimer:self.bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
                    
                });
            }
            
        } else {
            
            if( self.bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                [self.bpmRepeatTimer invalidate];
                self.bpmRepeatTimer = nil;
            }
            
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // BPM+ button
    } else if( sender == _bpmIncrementButton ) {
        if ( buttonDown && self.sharedPreferences.midiClockSourceName == nil ) {
            
            if( !self.bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                [self.sequencer incrementBPM];
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                    self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(incrementBPMRepeat:)
                                                                     userInfo:nil
                                                                      repeats:YES];
                    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                    
                    // Make sure we fire even when the UI is tracking mouse down stuff
                    [runloop addTimer:self.bpmRepeatTimer forMode: NSRunLoopCommonModes];
                    [runloop addTimer:self.bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
                    
                });
            }
            
        } else {
            
            if( self.bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                [self.bpmRepeatTimer invalidate];
                self.bpmRepeatTimer = nil;
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
            
        // We check to make sure the exit button was pressed in this view (not just being released after transitioning from sequencer mode)
        } else if( sender.buttonState == EatsButtonViewState_Down ) {
            
            if( _clearTimer )
                [self stopClear];
            
            // Start animateOut
            [self animateInOutIncrement:-1];
            
            self.inOutAnimationFrame = 0;
            [self scheduleAnimateOutTimer];
        }
    }
    
    [self updateView];
}

- (void) eatsGridHorizontalShiftViewUpdated:(EatsGridHorizontalShiftView *)sender
{
    [self.sequencer setTranspose:sender.shift forPage:self.sequencer.currentPageId];
    [self.sequencer setTransposeZeroStep:sender.zeroStep forPage:self.sequencer.currentPageId];
}

- (void) eatsGridLoopBraceViewUpdated:(EatsGridLoopBraceView *)sender
{
    uint start = [EatsGridUtils percentageToSteps:sender.startPercentage width:self.width];
    uint end = [EatsGridUtils percentageToSteps:sender.endPercentage width:self.width];
    [self.sequencer setLoopStart:start andLoopEnd:end forPage:self.sequencer.currentPageId];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
        
        // Scrub the loop
        if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Pause )
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Forward forPage:self.sequencer.currentPageId];
        [self.sequencer setNextStep:[NSNumber numberWithUnsignedInt:x] forPage:self.sequencer.currentPageId];
        
    }
}

- (void) eatsGridPatternViewSelection:(NSDictionary *)selection sender:(EatsGridPatternView *)sender
{
    uint start = [[selection valueForKey:@"start"] unsignedIntValue];
    uint end = [[selection valueForKey:@"end"] unsignedIntValue];
    [self.sequencer setLoopStart:start andLoopEnd:end forPage:self.sequencer.currentPageId];
}

@end
