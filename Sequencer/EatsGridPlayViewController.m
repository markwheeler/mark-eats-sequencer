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

@property EatsGridBoxView                   *boxOverlayView;
@property NSTimer                           *boxOverlayFadeTimer;

@property EatsGridHorizontalShiftView       *transposeView;
@property EatsGridLoopBraceView             *loopBraceView;
@property EatsGridPatternView               *patternView;

@property NSMutableArray                    *pageButtons;
@property NSMutableArray                    *patternButtons;
@property NSMutableArray                    *patternsOnOtherPagesButtons;
@property NSMutableArray                    *scrubOtherPagesButtons;

@property NSArray                           *playModeButtons;
@property NSArray                           *controlButtons;

@property EatsGridButtonView                *forwardButton;
@property EatsGridButtonView                *reverseButton;
@property EatsGridButtonView                *randomButton;
@property EatsGridButtonView                *sliceButton;
@property EatsGridButtonView                *bpmDecrementButton;
@property EatsGridButtonView                *bpmIncrementButton;
//@property EatsGridButtonView                *clearButton;
@property EatsGridButtonView                *automationButton;
@property EatsGridButtonView                *exitButton;

@property NSTimer                           *automationLongPressTimer;
@property NSTimer                           *bpmRepeatTimer;
@property BOOL                              automationShortPress;
//@property NSTimer                           *clearTimer;

@property NSTimer                           *inOutAnimationTimer;
@property uint                              inOutAnimationFrame;
@property float                             inOutAnimationSpeedMultiplier;

@property NSTimer                           *pageAnimationTimer;
@property uint                              pageAnimationFrame;
@property float                             pageAnimationSpeedMultiplier;

@property NSDictionary                      *lastDownPatternKey;
@property BOOL                              firstPatternKeyHasBeenPressed;
@property BOOL                              copiedPattern;

@property NSNumber                          *lastDownScrubOtherPagesKey;
@property BOOL                              setLoopOnOtherPages;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    dispatch_sync(self.gridQueue, ^(void) {
        
        // Update animation speed multiplier
        if( self.height > 8 )
            self.inOutAnimationSpeedMultiplier = 0.5;
        else
            self.inOutAnimationSpeedMultiplier = 2.5;
        
        if( self.width > 8 )
            self.pageAnimationSpeedMultiplier = 0.5;
        else
            self.pageAnimationSpeedMultiplier = 8.0;
        
        
        // Get prefs
        self.sharedPreferences = [Preferences sharedPreferences];
        
        
        // Create the sub views
        
        // Page buttons
        self.pageButtons = [[NSMutableArray alloc] initWithCapacity:8];
        for( int i = 0; i < 8; i ++ ) {
            EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
            button.delegate = self;
            button.x = i;
            button.y = - (self.height - 4) + 1;
            if( self.width < 16 )
                button.y ++;
            button.visible = NO;
            [self.pageButtons addObject:button];
        }
        
        // Pattern buttons
        uint numberOfPatterns = self.width;
        if( numberOfPatterns > 16 )
            numberOfPatterns = 16;
        
        // Pattern buttons for this page on small grids
        if( self.height < 16 ) {
            self.patternButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
            for( int i = 0; i < numberOfPatterns; i ++ ) {
                EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
                button.delegate = self;
                button.x = i;
                button.y = - (self.height - 4) + 3;
                button.visible = NO;
                [self.patternButtons addObject:button];
            }
        }
        
        // Pattern buttons for other pages on small grids
        if( self.height < 16 && self.width > 8 ) {
            self.patternsOnOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
            for( int i = 0; i < numberOfPatterns; i ++ ) {
                EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
                button.delegate = self;
                button.x = i;
                button.y = - (self.height - 4) + 2;
                button.visible = NO;
                [self.patternsOnOtherPagesButtons addObject:button];
            }
        }
        
        // Pattern buttons for all pages on large grids
        if( self.height > 8 ) {
            self.patternsOnOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns * 8];
            // Rows
            for( int i = 0; i < 8; i ++ ) {
                // Columns
                for( int j = 0; j < numberOfPatterns; j ++ ) {
                    EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
                    button.delegate = self;
                    button.x = j;
                    button.y = - (self.height - 4) + 2 + i;
                    if( self.width < 16 )
                        button.y ++;
                    button.inactiveBrightness = 4;
                    button.visible = NO;
                    [self.patternsOnOtherPagesButtons addObject:button];
                }
            }
        }
        
        // Scrub buttons for other pages, if there's space
        if( self.height > 8 ) {
            self.scrubOtherPagesButtons = [[NSMutableArray alloc] initWithCapacity:self.width];
            for( int i = 0; i < self.width; i ++ ) {
                EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
                button.delegate = self;
                button.x = i;
                button.y = - 1;
                button.visible = NO;
                [self.scrubOtherPagesButtons addObject:button];
            }
        }
        
        // Transpose slider, if there's space
        if( self.height > 8 && self.width > 8 ) {
            self.transposeView = [[EatsGridHorizontalShiftView alloc] init];
            self.transposeView.delegate = self;
            self.transposeView.x = 0;
            self.transposeView.y = - 2;
            self.transposeView.width = self.width;
            self.transposeView.height = 1;
            self.transposeView.visible = NO;
        }
        
        // Play mode buttons
        self.forwardButton = [[EatsGridButtonView alloc] init];
        self.forwardButton.x = self.width - 8;
        
        self.reverseButton = [[EatsGridButtonView alloc] init];
        self.reverseButton.x = self.width - 7;
        
        self.randomButton = [[EatsGridButtonView alloc] init];
        self.randomButton.x = self.width - 6;
        
        self.sliceButton = [[EatsGridButtonView alloc] init];
        self.sliceButton.x = self.width - 5;
        
        self.playModeButtons = [NSArray arrayWithObjects:self.forwardButton, self.reverseButton, self.randomButton, self.sliceButton, nil];
        
        for( EatsGridButtonView *button in self.playModeButtons ) {
            button.delegate = self;
            button.y = - (self.height - 4) + 1;
            button.inactiveBrightness = 5;
            button.visible = NO;
        }
        
        // Control buttons
        self.bpmDecrementButton = [[EatsGridButtonView alloc] init];
        self.bpmDecrementButton.x = self.width - 4;
        
        self.bpmIncrementButton = [[EatsGridButtonView alloc] init];
        self.bpmIncrementButton.x = self.width - 3;
        
//        self.clearButton = [[EatsGridButtonView alloc] init];
//        self.clearButton.x = self.width - 2;
//        self.clearButton.inactiveBrightness = 5;
        
        self.automationButton = [[EatsGridButtonView alloc] init];
        self.automationButton.x = self.width - 2;
        
        self.exitButton = [[EatsGridButtonView alloc] init];
        self.exitButton.x = self.width - 1;
        self.exitButton.inactiveBrightness = 5;
        
        self.controlButtons = [NSArray arrayWithObjects:self.bpmDecrementButton, self.bpmIncrementButton, self.automationButton, self.exitButton, nil];
        
        for( EatsGridButtonView *button in self.controlButtons ) {
            button.delegate = self;
            button.y = - (self.height - 4) + 1;
            button.visible = NO;
        }
        
        // Loop length selection view
        self.loopBraceView = [[EatsGridLoopBraceView alloc] init];
        self.loopBraceView.delegate = self;
        self.loopBraceView.x = 0;
        self.loopBraceView.y = 0;
        self.loopBraceView.width = self.width;
        self.loopBraceView.height = 1;
        self.loopBraceView.fillBar = YES;
        
        // Pattern view
        self.patternView = [[EatsGridPatternView alloc] init];
        self.patternView.delegate = self;
        self.patternView.x = 0;
        self.patternView.y = 1;
        self.patternView.width = self.width;
        self.patternView.height = self.height - 1;
        self.patternView.foldFrom = EatsPatternViewFoldFrom_Top;
        self.patternView.mode = EatsPatternViewMode_Play;
        self.patternView.patternHeight = self.height;
        
        // Add everything to sub views
        self.subViews = [[NSMutableSet alloc] initWithObjects:self.loopBraceView, self.patternView, nil];
        [self.subViews addObjectsFromArray:self.pageButtons];
        [self.subViews addObjectsFromArray:self.patternButtons];
        [self.subViews addObjectsFromArray:self.patternsOnOtherPagesButtons];
        if( self.height > 8 )
            [self.subViews addObjectsFromArray:self.scrubOtherPagesButtons];
        if( self.height > 8 && self.width > 8 )
            [self.subViews addObject:self.transposeView];
        [self.subViews addObjectsFromArray:self.playModeButtons];
        [self.subViews addObjectsFromArray:self.controlButtons];
        
        // Update everything
        [self updatePage];
        [self updatePlayMode];
        [self updateAutomationMode];
        [self updateAutomationStatus];
        [self updatePattern];
        if( self.height > 8 ) {
            [self updateTranspose];
            [self updateScrubOtherPages];
        }
        [self updateLoop];
        [self updatePatternNotes];
        
        // Clock tick notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clockMinQuantizationTick:) name:kClockMinQuantizationTick object:nil];
        
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
        
        // Sequencer automation notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automationModeDidChange:) name:kSequencerAutomationModeDidChangeNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automationChangesDidChange:) name:kSequencerAutomationChangesDidChangeNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automationRemoveAllChanges:) name:kSequencerAutomationRemoveAllChangesNotification object:self.sequencer];
        
        // Start animateIn
        self.inOutAnimationFrame = 0;
        [self animateInOutIncrement:-1];
        [self scheduleAnimateInTimer];
        
        [self updateView];
        
    });
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

- (void) updateView
{
    if( self.sharedPreferences.gridSupportsVariableBrightness )
        self.transposeView.useWideBrightnessRange = YES;
        
    else
        self.transposeView.useWideBrightnessRange = NO;
    
    [super updateView];
}



#pragma mark - Private methods

- (void) animateIn:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
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
    });
}

- (void) animateOut:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
        self.inOutAnimationFrame ++;
        
        [timer invalidate];
        
        // Final frame
        if( self.patternView.height == self.height - 1 ) {
            self.inOutAnimationTimer = nil;
            
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
        } else {
            [self scheduleAnimateOutTimer];
        }
        
        [self animateInOutIncrement:-1];
            
        [self updateView];
    });
}

- (void) scheduleAnimateInTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.inOutAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * self.inOutAnimationSpeedMultiplier ) * ( 0.1 + IN_OUT_ANIMATION_EASE * self.inOutAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateIn:)
                                                         userInfo:nil
                                                          repeats:NO];
        [self.inOutAnimationTimer setTolerance:self.inOutAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSEventTrackingRunLoopMode];
        
    });
}

- (void) scheduleAnimateOutTimer
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        int frameCountdown = ( (self.height / 2) - 1 - self.inOutAnimationFrame);
        self.inOutAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * self.inOutAnimationSpeedMultiplier ) * ( 0.1 + IN_OUT_ANIMATION_EASE * frameCountdown ) ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateOut:)
                                                         userInfo:nil
                                                          repeats:NO];
        [self.inOutAnimationTimer setTolerance:self.inOutAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.inOutAnimationTimer forMode: NSEventTrackingRunLoopMode];
    });
}

- (void) animateInOutIncrement:(int)amount
{
    if( self.transposeView ) {
        self.transposeView.y += amount;
        if( self.transposeView.y < 0 )
            self.transposeView.visible = NO;
        else
            self.transposeView.visible = YES;
    }
    
    self.loopBraceView.y += amount;
    if( self.loopBraceView.y < 0 )
        self.loopBraceView.visible = NO;
    else
        self.loopBraceView.visible = YES;
    
    self.patternView.y += amount;
    self.patternView.height += amount * -1;
    
    for (EatsGridButtonView *button in self.pageButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in self.patternButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in self.patternsOnOtherPagesButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in self.scrubOtherPagesButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in self.playModeButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
    for (EatsGridButtonView *button in self.controlButtons) {
        button.y += amount;
        if( button.y < 0 )
            button.visible = NO;
        else
            button.visible = YES;
    }
}

- (void) pageLeft:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
        self.pageAnimationFrame ++;
        
        [self.pageAnimationTimer invalidate];
        self.pageAnimationTimer = nil;
        
        [self animatePageIncrement:1];
        
        [self updateView];
        
        // Final frame
        if( self.pageAnimationFrame == self.width - 5 ) {
            self.pageAnimationTimer = nil;
            self.loopBraceView.enabled = YES;
            self.patternView.enabled = YES;
            
        } else {
            [self performSelectorOnMainThread:@selector(scheduleAnimatePageLeftTimer) withObject:nil waitUntilDone:YES];
        }
    });
}

- (void) pageRight:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
        self.pageAnimationFrame ++;
        
        [self.pageAnimationTimer invalidate];
        self.pageAnimationTimer = nil;
        
        [self animatePageIncrement:-1];
        
        [self updateView];
        
        // Final frame
        if( self.pageAnimationFrame == self.width - 5 ) {
            self.pageAnimationTimer = nil;
            self.loopBraceView.enabled = YES;
            self.patternView.enabled = YES;
            
        } else {
            [self performSelectorOnMainThread:@selector(scheduleAnimatePageRightTimer) withObject:nil waitUntilDone:YES];
        }
    });
}

- (void) scheduleAnimatePageLeftTimer
{
    // This needs to be done on the main thread
    
    self.pageAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * self.pageAnimationSpeedMultiplier ) * ( 0.1 + PAGE_ANIMATION_EASE * self.pageAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                               target:self
                                                             selector:@selector(pageLeft:)
                                                             userInfo:nil
                                                              repeats:NO];
    [self.pageAnimationTimer setTolerance:self.pageAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
    
    // Make sure we fire even when the UI is tracking mouse down stuff
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addTimer:self.pageAnimationTimer forMode: NSRunLoopCommonModes];
    [runloop addTimer:self.pageAnimationTimer forMode: NSEventTrackingRunLoopMode];
}

- (void) scheduleAnimatePageRightTimer
{
    // This needs to be done on the main thread
    
    self.pageAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:( ( 0.5 * self.pageAnimationSpeedMultiplier ) * ( 0.1 + PAGE_ANIMATION_EASE * self.pageAnimationFrame ) ) / ANIMATION_FRAMERATE
                                                              target:self
                                                            selector:@selector(pageRight:)
                                                            userInfo:nil
                                                             repeats:NO];
    [self.pageAnimationTimer setTolerance:self.pageAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
    
    // Make sure we fire even when the UI is tracking mouse down stuff
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addTimer:self.pageAnimationTimer forMode: NSRunLoopCommonModes];
    [runloop addTimer:self.pageAnimationTimer forMode: NSEventTrackingRunLoopMode];
}

- (void) animatePageIncrement:(int)amount
{
    
    self.loopBraceView.x += amount;
    self.patternView.x += amount;

    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        
        float percentageOfAnimationComplete = (float)self.pageAnimationFrame / ( self.width - 5 );
        float opacity = ( 0.7 * percentageOfAnimationComplete ) + 0.3;
        
        self.loopBraceView.opacity = opacity;
        self.patternView.opacity = opacity;
        
    } else if( self.loopBraceView.opacity != 1 || self.patternView.opacity != 1 ) {
        self.loopBraceView.opacity = 1;
        self.patternView.opacity = 1;
    }
}

- (void) flashBoxOverlay
{
    // Create a box and then fade it out as a visual cue that the automation has been cleared
    self.boxOverlayView = [[EatsGridBoxView alloc] init];
    self.boxOverlayView.width = self.width;
    self.boxOverlayView.height = self.height;
    [self.subViews addObject:self.boxOverlayView];
    
    [self.boxOverlayFadeTimer invalidate];
    self.boxOverlayFadeTimer = nil;
    
    [self updateView];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.boxOverlayFadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.03
                                                                    target:self
                                                                  selector:@selector(boxOverlayFadeIncrement:)
                                                                  userInfo:nil
                                                                   repeats:YES];
        [self.boxOverlayFadeTimer setTolerance:self.boxOverlayFadeTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addTimer:self.boxOverlayFadeTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.boxOverlayFadeTimer forMode: NSEventTrackingRunLoopMode];
    });

}

- (void) boxOverlayFadeIncrement:(NSTimer *)timer
{
    self.boxOverlayView.brightness --;
    
    if( self.boxOverlayView.brightness == 0 ) {
        
        [self.boxOverlayFadeTimer invalidate];
        self.boxOverlayFadeTimer = nil;
        
        dispatch_sync(self.gridQueue, ^(void) {
            [self.subViews removeObject:self.boxOverlayView];
            self.boxOverlayView = nil;
        });
    }
    
    [self updateView];
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
        [self.bpmRepeatTimer setTolerance:self.bpmRepeatTimer.timeInterval * 0.1]; // 10%
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
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
        [self.bpmRepeatTimer setTolerance:self.bpmRepeatTimer.timeInterval * 0.1]; // 10%
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addTimer:self.bpmRepeatTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.bpmRepeatTimer forMode: NSEventTrackingRunLoopMode];
        
        [self.sequencer incrementBPM];
    });
}

//- (void) clearIncrement:(NSTimer *)timer
//{
//    dispatch_async(self.gridQueue, ^(void) {
//        if( self.patternView.wipe >= 100 ) {
//            [self stopClear];
//            [self.sequencer clearNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
//            
//        } else {
//            self.patternView.wipe = self.patternView.wipe + 10;
//            [self updateView];
//        }
//    });
//}

//- (void) stopClear
//{
//    [self.clearTimer invalidate];
//    self.clearTimer = nil;
//    self.patternView.wipe = 0;
//    self.clearButton.buttonState = EatsButtonViewState_Inactive;
//}

- (void) incrementAutomationFlashForTick:(int)tick
{
    // We only update every second tick (32nds) to keep the refresh rate reasonable
    if( tick % 2 && ( self.sequencer.automationMode == EatsSequencerAutomationMode_Armed || self.sequencer.automationMode == EatsSequencerAutomationMode_Recording ) ) {
        
        int newBrightness = self.automationButton.activeBrightness;
        
        // Blink twice as fast when armed
        if( self.sequencer.automationMode == EatsSequencerAutomationMode_Armed )
            newBrightness -= 2;
        else if (self.sequencer.automationMode == EatsSequencerAutomationMode_Recording )
            newBrightness --;
        
        if( newBrightness < 0 )
            newBrightness = 15;
        self.automationButton.activeBrightness = newBrightness;
        
        [self updateView];
    }
}



#pragma mark - Sub view updates

- (void) updatePageLeft
{
    // Start animate left
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    self.loopBraceView.x = - self.width + 4;
    self.patternView.x = - self.width + 4;
    self.loopBraceView.enabled = NO;
    self.patternView.enabled = NO;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        self.loopBraceView.opacity = 0;
        self.patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:1];
    [self performSelectorOnMainThread:@selector(scheduleAnimatePageLeftTimer) withObject:nil waitUntilDone:YES];
    
    [self updatePage];
}

- (void) updatePageRight
{
    // Start animate right
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    self.loopBraceView.x = self.width - 4;
    self.patternView.x = self.width - 4;
    self.loopBraceView.enabled = NO;
    self.patternView.enabled = NO;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        self.loopBraceView.opacity = 0;
        self.patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:-1];
    [self performSelectorOnMainThread:@selector(scheduleAnimatePageRightTimer) withObject:nil waitUntilDone:YES];
    
    [self updatePage];
}

- (void) updatePage
{
    uint i = 0;
    for ( EatsGridButtonView *button in self.pageButtons ) {
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
    for ( EatsGridButtonView *button in self.playModeButtons ) {
        if( i == [self.sequencer playModeForPage:self.sequencer.currentPageId] - 1 )
            button.buttonState = EatsButtonViewState_Active;
        else if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
}

- (void) updateAutomationMode
{
    // Light up when playing, armed or recording
    if( self.sequencer.automationMode == EatsSequencerAutomationMode_Inactive )
        self.automationButton.buttonState = EatsButtonViewState_Inactive;
    else
        self.automationButton.buttonState = EatsButtonViewState_Active;
    
    self.automationButton.activeBrightness = 15;
}


- (void) updateAutomationStatus
{
    // Show some light if automation is recorded
    if( self.sequencer.automationChanges.count )
        self.automationButton.inactiveBrightness = 5;
    else
        self.automationButton.inactiveBrightness = 0;
}

- (void) updatePattern
{
    // Set all other page pattern buttons to 0 (not required on large grids)
    if( self.height < 16 ) {
        for ( EatsGridButtonView *button in self.patternsOnOtherPagesButtons ) {
            if( button.buttonState != EatsButtonViewState_Down )
                button.buttonState = EatsButtonViewState_Inactive;
            button.inactiveBrightness = 0;
        }
    }
    
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        
        int playMode = [self.sequencer playModeForPage:pageId];
        int currentPatternId = [self.sequencer currentPatternIdForPage:pageId];
        NSNumber *nextPatternId = [self.sequencer nextPatternIdForPage:pageId];
        
        uint patternButtonId;
        
        // For large grids
        if( self.height > 8 ) {
            
            NSRange range;
            range.length = self.width;
            if (range.length > 16)
                range.length = 16;
            range.location = pageId * range.length;
            
            NSArray *patternsRow = [self.patternsOnOtherPagesButtons subarrayWithRange:range];
            
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
                    button.inactiveBrightness = 5;
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
                for ( EatsGridButtonView *button in self.patternButtons ) {
                    
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
                for ( EatsGridButtonView *button in self.patternsOnOtherPagesButtons ) {
                    
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
    self.transposeView.shift = [self.sequencer transposeForPage:self.sequencer.currentPageId];
    self.transposeView.zeroStep = [self.sequencer transposeZeroStepForPage:self.sequencer.currentPageId];
}

- (void) updateScrubOtherPages
{
    // Set all other page pattern buttons to 0
    for ( EatsGridButtonView *button in self.scrubOtherPagesButtons ) {
        if( button.buttonState != EatsButtonViewState_Down )
            button.buttonState = EatsButtonViewState_Inactive;
    }
    
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        if( pageId != self.sequencer.currentPageId && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Pause )
            [[self.scrubOtherPagesButtons objectAtIndex:[self.sequencer currentStepForPage:pageId] ] setButtonState:EatsButtonViewState_Active];
    }
}


- (void) updateLoop
{
    self.loopBraceView.startPercentage = [EatsGridUtils stepsToPercentage:[self.sequencer loopStartForPage:self.sequencer.currentPageId] width:self.width];
    self.loopBraceView.endPercentage = [EatsGridUtils stepsToPercentage:[self.sequencer loopEndForPage:self.sequencer.currentPageId] width:self.width];
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

// Clock tick notifications
- (void) clockMinQuantizationTick:(NSNotification *)notification {
    dispatch_async(self.gridQueue, ^(void) {
        [self incrementAutomationFlashForTick:[[notification.userInfo valueForKey:@"tick"] intValue]];
    });
}

// Sequencer page notifications
- (void) pageLoopDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updateLoop];
            [self updateView];
        }
    });
}

- (void) pageTransposeDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updateTranspose];
            [self updateView];
        }
    });
}

- (void) pageTransposeZeroStepDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updateTranspose];
            [self updateView];
        }
    });
}

- (void) pagePatternNotesDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            [self updatePatternNotes];
        }
        [self updatePattern];
        [self updateView];
    });
}

// Sequencer note notifications
- (void) noteLengthDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

// Sequencer state notifications
- (void) stateCurrentPageDidChangeLeft:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
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
    });
}

- (void) stateCurrentPageDidChangeRight:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
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
    });
}

// Sequencer page state notifications
- (void) pageStateCurrentPatternIdDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] )
            [self updatePatternNotes];
        
        [self updatePattern];
        [self updateView];
    });
}

- (void) pageStateNextPatternIdDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] )
            [self updatePatternNotes];
        
        [self updatePattern];
        [self updateView];
    });
}

- (void) pageStateCurrentStepDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
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
    });
}

- (void) pageStateNextStepDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

- (void) pageStatePlayModeDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        
        [self updatePattern];
        
        if( [self.sequencer isNotificationFromCurrentPage:notification] )
            [self updatePlayMode];
        
        if( self.height > 8 )
            [self updateScrubOtherPages];
        
        [self updateView];
    });
}

- (void) automationModeDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        [self updateAutomationMode];
        [self updateView];
    });
}

- (void) automationChangesDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        [self updateAutomationStatus];
        [self updateView];
    });
}

- (void) automationRemoveAllChanges:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        [self flashBoxOverlay];
    });
}



#pragma mark - Sub view delegate methods

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender
{
    dispatch_async(self.gridQueue, ^(void) {
        
        BOOL buttonDown = [down boolValue];
            
        // Page buttons
        if ( [self.pageButtons containsObject:sender] ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                [self.sequencer setCurrentPageId:(int)[self.pageButtons indexOfObject:sender]];
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
                [self updatePage];
            }
        
        // Pattern buttons
        } else if ( [self.patternButtons containsObject:sender] ) {
            
            uint pressedPattern = (uint)[self.patternButtons indexOfObject:sender];
            
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                self.firstPatternKeyHasBeenPressed = YES;
                
                // Here we check the timestamp to make it harder to accidentally copy when you really just wanted to trigger multiple patterns at once
                if( self.lastDownPatternKey && [[self.lastDownPatternKey valueForKey:@"timestamp"] timeIntervalSinceNow] <= -0.4  ) {
                    // Copy pattern
                    [self.sequencer copyNotesFromPattern:[[self.lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] fromPage:self.sequencer.currentPageId toPattern:pressedPattern toPage:self.sequencer.currentPageId];
                    self.copiedPattern = YES;
                    
                } else {
                    // Keep track of last down
                    self.lastDownPatternKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:pressedPattern], @"pattern", [NSDate date], @"timestamp", nil];
                }
                
            // Release
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
                
                if( !self.copiedPattern && self.firstPatternKeyHasBeenPressed ) {
                    // Change pattern
                    [self.sequencer startOrStopPattern:pressedPattern inPage:self.sequencer.currentPageId];
                }
                
                if( self.lastDownPatternKey && [[self.lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] == pressedPattern ) {
                    self.lastDownPatternKey = nil;
                    self.copiedPattern = NO;
                }
                
                [self updatePattern];
            }
            
            [self updateView];
        
        // Pattern buttons for other pages
        } else if ( [self.patternsOnOtherPagesButtons containsObject:sender] ) {
            
            // For large grids
            if( self.height > 8 ) {
                
                uint numberOfPatterns = self.width;
                if (numberOfPatterns > 16)
                    numberOfPatterns = 16;
                
                uint pressedPattern = [self.patternsOnOtherPagesButtons indexOfObject:sender] % numberOfPatterns;
                uint pressedPage = (uint)[self.patternsOnOtherPagesButtons indexOfObject:sender] / numberOfPatterns;
                
                if ( buttonDown ) {
                    sender.buttonState = EatsButtonViewState_Down;
                    self.firstPatternKeyHasBeenPressed = YES;
                    
                    // Here we check the timestamp to make it harder to accidentally copy when you really just wanted to trigger multiple patterns at once
                    if( self.lastDownPatternKey && [[self.lastDownPatternKey valueForKey:@"timestamp"] timeIntervalSinceNow] <= -0.4  ) {
                        // Copy pattern
                        [self.sequencer copyNotesFromPattern:[[self.lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] fromPage:[[self.lastDownPatternKey valueForKey:@"page"] unsignedIntValue] toPattern:pressedPattern toPage:pressedPage];
                        self.copiedPattern = YES;
                        
                    } else {
                        // Keep track of last down
                        self.lastDownPatternKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:pressedPage], @"page",
                                                                                         [NSNumber numberWithUnsignedInt:pressedPattern], @"pattern",
                                                                                         [NSDate date], @"timestamp",
                                                                                         nil];
                    }
                    
                // Release
                } else {
                    sender.buttonState = EatsButtonViewState_Inactive;
                    
                    if( !self.copiedPattern && self.firstPatternKeyHasBeenPressed ) {
                        // Change pattern
                        [self.sequencer startOrStopPattern:pressedPattern inPage:pressedPage];
                    }
                    
                    if( self.lastDownPatternKey
                       && [[self.lastDownPatternKey valueForKey:@"page"] unsignedIntValue] == pressedPage
                       && [[self.lastDownPatternKey valueForKey:@"pattern"] unsignedIntValue] == pressedPattern ) {
                        
                        self.lastDownPatternKey = nil;
                        self.copiedPattern = NO;

                    }
                    
                    [self updatePattern];
                    
                }
            
            // Smaller grids (change all patterns at once)
            } else {
                
                if ( buttonDown ) {
                    sender.buttonState = EatsButtonViewState_Down;
                    
                    [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithUnsignedInteger:[self.patternsOnOtherPagesButtons indexOfObject:sender]] forAllPagesExcept:self.sequencer.currentPageId];
                    
                } else {
                    sender.buttonState = EatsButtonViewState_Inactive;
                    
                    [self updatePattern];
                }

            }
            
            [self updateView];
        
        // Scrub buttons for other pages
        } else if ( [self.scrubOtherPagesButtons containsObject:sender] ) {
            
            int pressedStep = (int)[self.scrubOtherPagesButtons indexOfObject:sender];
            
            if ( buttonDown ) {
                
                if( self.sharedPreferences.loopFromScrubArea && self.lastDownScrubOtherPagesKey  ) {
                    
                    int loopEnd = pressedStep - 1;
                    if( loopEnd < 0 )
                        loopEnd += self.width;
                    
                    // Add automation
                    NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:[self.lastDownScrubOtherPagesKey copy], @"startValue",
                                                                                      [NSNumber numberWithInt:loopEnd], @"endValue",
                                                                                      nil];
                    [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetLoop withValues:values forAllPagesExcept:self.sequencer.currentPageId];
                    
                    // Set loop
                    [self.sequencer setLoopStart:self.lastDownScrubOtherPagesKey.intValue andLoopEnd:loopEnd forAllPagesExcept:self.sequencer.currentPageId];
                    self.setLoopOnOtherPages = YES;
                    
                } else {
                    
                    if( self.sharedPreferences.loopFromScrubArea ) {
                        if( !self.setLoopOnOtherPages ) {
                            
                            // Add automation
                            NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"startValue",
                                                                                              [NSNumber numberWithInt:self.sharedPreferences.gridWidth - 1], @"endValue",
                                                                                              nil];
                            [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetLoop withValues:values forAllPagesExcept:self.sequencer.currentPageId];
                            
                            // Reset loop
                            [self.sequencer setLoopStart:0 andLoopEnd:self.sharedPreferences.gridWidth - 1 forAllPagesExcept:self.sequencer.currentPageId];
                        }
                        
                        // Keep track of last down
                        self.lastDownScrubOtherPagesKey = [NSNumber numberWithUnsignedInteger:pressedStep];
                    }
                    
                    if( !self.setLoopOnOtherPages || !self.sharedPreferences.loopFromScrubArea ) {
                        // Scrub
                        [self.sequencer setNextStep:[NSNumber numberWithUnsignedInteger:pressedStep] forAllPagesExcept:self.sequencer.currentPageId];
                    }
                    
                }
                
                for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
                    if( pageId != self.sequencer.currentPageId && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Pause ) {
                        sender.buttonState = EatsButtonViewState_Down;
                        break;
                    }
                }
                
            } else {
                sender.buttonState = EatsButtonViewState_Inactive;
                
                if( self.lastDownScrubOtherPagesKey && self.lastDownScrubOtherPagesKey.intValue == pressedStep ) {
                    self.lastDownScrubOtherPagesKey = nil;
                    self.setLoopOnOtherPages = NO;
                }
                
                [self updateScrubOtherPages];

            }
            
            [self updateView];
        
        // Play mode buttons
        } else if( [self.playModeButtons containsObject:sender] ) {
            
            if( buttonDown ) {
            
                EatsSequencerPlayMode playMode;
                
                // Play mode forward button
                if( sender == self.forwardButton ) {
                    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Forward )
                        playMode = EatsSequencerPlayMode_Pause;
                    else
                        playMode = EatsSequencerPlayMode_Forward;
                    
                // Play mode reverse button
                } else if( sender == self.reverseButton ) {
                    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Reverse )
                        playMode = EatsSequencerPlayMode_Pause;
                    else
                        playMode = EatsSequencerPlayMode_Reverse;
                    
                // Play mode random button
                } else if( sender == self.randomButton ) {
                    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Random )
                        playMode = EatsSequencerPlayMode_Pause;
                    else
                        playMode = EatsSequencerPlayMode_Random;
                
                // Play mode slice button
                } else {
                    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Slice )
                        playMode = EatsSequencerPlayMode_Pause;
                    else
                        playMode = EatsSequencerPlayMode_Slice;
                    
                }
                
                // Add automation
                NSDictionary *values = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:playMode] forKey:@"value"];
                [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetPlayMode withValues:values forPage:self.sequencer.currentPageId];
                
                [self.sequencer setPlayMode:playMode forPage:self.sequencer.currentPageId];
                
            }
            
        // BPM- button
        } else if( sender == self.bpmDecrementButton ) {
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
                        [self.bpmRepeatTimer setTolerance:self.bpmRepeatTimer.timeInterval * 0.1]; // 10%
                        
                        // Make sure we fire even when the UI is tracking mouse down stuff
                        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
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
            
            [self updateView];
            
        // BPM+ button
        } else if( sender == self.bpmIncrementButton ) {
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
                        [self.bpmRepeatTimer setTolerance:self.bpmRepeatTimer.timeInterval * 0.1]; // 10%
                        
                        // Make sure we fire even when the UI is tracking mouse down stuff
                        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
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
            
            [self updateView];
            
//        // Clear button
//        } else if( sender == self.clearButton ) {
//            if ( buttonDown ) {
//                sender.buttonState = EatsButtonViewState_Down;
//                
//                dispatch_async(dispatch_get_main_queue(), ^(void) {
//                
//                    self.clearTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
//                                                                   target:self
//                                                                 selector:@selector(clearIncrement:)
//                                                                 userInfo:nil
//                                                                  repeats:YES];
//                    [self.self.clearTimer setTolerance:self.self.clearTimer.timeInterval * 0.1]; // 10%
//                    
//                    // Make sure we fire even when the UI is tracking mouse down stuff
//                    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
//                    [runloop addTimer:self.clearTimer forMode: NSRunLoopCommonModes];
//                    [runloop addTimer:self.clearTimer forMode: NSEventTrackingRunLoopMode];
//                    
//                });
//                
//            } else {
//                sender.buttonState = EatsButtonViewState_Inactive;
//                
//                [self stopClear];
//            }
//            
//            [self updateView];

        // Automation button
        } else if( sender == self.automationButton ) {
            
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
                self.automationShortPress = YES;
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                    self.automationLongPressTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                                           target:self
                                                                         selector:@selector(automationLongPressTimeout:)
                                                                         userInfo:nil
                                                                          repeats:NO];
                    [self.automationLongPressTimer setTolerance:self.automationLongPressTimer.timeInterval * 0.1]; // 10%
                    
                    // Make sure we fire even when the UI is tracking mouse down stuff
                    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                    [runloop addTimer:self.automationLongPressTimer forMode: NSRunLoopCommonModes];
                    [runloop addTimer:self.automationLongPressTimer forMode: NSEventTrackingRunLoopMode];
                });
                
            } else {
                
                [self.automationLongPressTimer invalidate];
                self.automationLongPressTimer = nil;
                
                // Short press (long presses are handled by the timer)
                if( self.automationShortPress ) {
                    
                    self.automationShortPress = NO;
                    
                    if( self.sequencer.automationMode == EatsSequencerAutomationMode_Inactive || self.sequencer.automationMode == EatsSequencerAutomationMode_Recording )
                        [self.sequencer setAutomationMode:EatsSequencerAutomationMode_Playing];
                    else
                        [self.sequencer setAutomationMode:EatsSequencerAutomationMode_Inactive];
                }
                
                if( self.sequencer.automationMode == EatsButtonViewState_Inactive )
                    sender.buttonState = EatsButtonViewState_Inactive;
                else
                    sender.buttonState = EatsButtonViewState_Active;
            }
            
            [self updateView];
            
        // Exit button
        } else if( sender == self.exitButton ) {
            if ( buttonDown ) {
                sender.buttonState = EatsButtonViewState_Down;
                
            // We check to make sure the exit button was pressed in this view (not just being released after transitioning from sequencer mode)
            } else if( sender.buttonState == EatsButtonViewState_Down ) {
                
//                if( self.clearTimer )
//                    [self stopClear];
                
                // Start animateOut
                [self animateInOutIncrement:-1];
                
                self.inOutAnimationFrame = 0;
                [self scheduleAnimateOutTimer];
            }
            
            [self updateView];
        }
        
    });
}

- (void) automationLongPressTimeout:(NSTimer *)timer
{
    [self.automationLongPressTimer invalidate];
    self.automationLongPressTimer = nil;
    
    dispatch_async(self.gridQueue, ^(void) {
        self.automationShortPress = NO;
        
        if( self.sequencer.automationMode == EatsSequencerAutomationMode_Inactive )
            [self.sequencer setAutomationMode:EatsSequencerAutomationMode_Armed];
        else
            [self.sequencer setAutomationMode:EatsSequencerAutomationMode_Recording];
        
    });
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        self.automationLongPressTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                                         target:self
                                                                       selector:@selector(automationLongerPressTimeout:)
                                                                       userInfo:nil
                                                                        repeats:NO];
        [self.automationLongPressTimer setTolerance:self.automationLongPressTimer.timeInterval * 0.1]; // 10%
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addTimer:self.automationLongPressTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:self.automationLongPressTimer forMode: NSEventTrackingRunLoopMode];
    });
}

- (void) automationLongerPressTimeout:(NSTimer *)timer
{
    [self.automationLongPressTimer invalidate];
    self.automationLongPressTimer = nil;
    
    dispatch_async(self.gridQueue, ^(void) {
        [self.sequencer removeAllAutomation];
    });
}


- (void) eatsGridHorizontalShiftViewUpdated:(EatsGridHorizontalShiftView *)sender
{
    // Add automation
    NSDictionary *values = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:sender.shift] forKey:@"value"];
    [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetTranspose withValues:values forPage:self.sequencer.currentPageId];
    
    [self.sequencer setTranspose:sender.shift forPage:self.sequencer.currentPageId];    
    [self.sequencer setTransposeZeroStep:sender.zeroStep forPage:self.sequencer.currentPageId];
}

- (void) eatsGridLoopBraceViewUpdated:(EatsGridLoopBraceView *)sender
{
    uint start = [EatsGridUtils percentageToSteps:sender.startPercentage width:self.width];
    uint end = [EatsGridUtils percentageToSteps:sender.endPercentage width:self.width];
    
    // Add automation
    NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:start], @"startValue",
                                                                      [NSNumber numberWithUnsignedInt:end], @"endValue",
                                                                      nil];
    [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetLoop withValues:values forPage:self.sequencer.currentPageId];
    
    [self.sequencer setLoopStart:start andLoopEnd:end forPage:self.sequencer.currentPageId];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
        
        // Scrub the loop
        if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Pause ) {
            
            // Add automation
            NSDictionary *values = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:EatsSequencerPlayMode_Forward] forKey:@"value"];
            [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetPlayMode withValues:values forPage:self.sequencer.currentPageId];
            
            [self.sequencer setPlayMode:EatsSequencerPlayMode_Forward forPage:self.sequencer.currentPageId];
        }
        [self.sequencer setNextStep:[NSNumber numberWithUnsignedInt:x] forPage:self.sequencer.currentPageId];
        
    }
}

- (void) eatsGridPatternViewSelection:(NSDictionary *)selection sender:(EatsGridPatternView *)sender
{
    NSNumber *start = [selection valueForKey:@"start"];
    NSNumber *end = [selection valueForKey:@"end"];
    
    // Add automation
    NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:start, @"startValue",
                                                                      end, @"endValue",
                                                                      nil];
    [self.sequencer addAutomationChangeOfType:EatsSequencerAutomationType_SetLoop withValues:values forPage:self.sequencer.currentPageId];
    
    [self.sequencer setLoopStart:start.unsignedIntValue andLoopEnd:end.unsignedIntValue forPage:self.sequencer.currentPageId];
}

@end