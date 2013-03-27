//
//  EatsGridPlayViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPlayViewController.h"
#import "EatsGridNavigationController.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerNote.h"

#define ANIMATION_FRAMERATE 15

@interface EatsGridPlayViewController ()

@property Sequencer                         *sequencer;
@property SequencerPage                     *page;
@property SequencerPattern                  *pattern;

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
    self.sequencer = [sequencerMatches lastObject];
    
    // Get the page
    self.page = [self.sequencer.pages objectAtIndex:0];
    
    // Get the pattern
    self.pattern = [self.page.patterns objectAtIndex:0];
    
    // Create the sub views
    
    // Page buttons
    self.pageButtons = [[NSMutableArray alloc] initWithCapacity:8];
    for( int i = 0; i < 8; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height / 2) + 1;
        if( self.width < 16 )
            button.y ++;
        button.visible = NO;
        [self.pageButtons addObject:button];
    }
    
    // Pattern buttons
    uint numberOfPatterns = self.width;
    if( numberOfPatterns > 16 )
        numberOfPatterns = 16;
    
    self.patternButtons = [[NSMutableArray alloc] initWithCapacity:numberOfPatterns];
    for( int i = 0; i < numberOfPatterns; i ++ ) {
        EatsGridButtonView *button = [[EatsGridButtonView alloc] init];
        button.delegate = self;
        button.x = i;
        button.y = - (self.height / 2) + 3;
        button.visible = NO;
        [self.patternButtons addObject:button];
    }
    
    // Play mode buttons
    self.pauseButton = [[EatsGridButtonView alloc] init];
    self.pauseButton.x = self.width - 8;
    
    self.forwardButton = [[EatsGridButtonView alloc] init];
    self.forwardButton.x = self.width - 7;
    
    self.reverseButton = [[EatsGridButtonView alloc] init];
    self.reverseButton.x = self.width - 6;
    
    self.randomButton = [[EatsGridButtonView alloc] init];
    self.randomButton.x = self.width - 5;
    
    self.playModeButtons = [NSArray arrayWithObjects:self.pauseButton, self.forwardButton, self.reverseButton, self.randomButton, nil];
    
    for( EatsGridButtonView *button in self.playModeButtons ) {
        button.delegate = self;
        button.y = - (self.height / 2) + 1;
        button.inactiveBrightness = 5;
        button.visible = NO;
    }
    
    // Control buttons
    self.bpmDecrementButton = [[EatsGridButtonView alloc] init];
    self.bpmDecrementButton.x = self.width - 4;
    
    self.bpmIncrementButton = [[EatsGridButtonView alloc] init];
    self.bpmIncrementButton.x = self.width - 3;
    
    self.clearButton = [[EatsGridButtonView alloc] init];
    self.clearButton.x = self.width - 2;
    self.clearButton.inactiveBrightness = 5;
    
    self.exitButton = [[EatsGridButtonView alloc] init];
    self.exitButton.x = self.width - 1;
    self.exitButton.inactiveBrightness = 8;
    
    self.controlButtons = [NSArray arrayWithObjects:self.bpmDecrementButton, self.bpmIncrementButton, self.clearButton, self.exitButton, nil];
    
    for( EatsGridButtonView *button in self.controlButtons ) {
        button.delegate = self;
        button.y = - (self.height / 2) + 1;
        button.visible = NO;
    }
    
    // Loop length selection view
    self.loopBraceView = [[EatsGridLoopBraceView alloc] init];
    self.loopBraceView.delegate = self;
    self.loopBraceView.x = 0;
    self.loopBraceView.y = - (self.height / 2) + 4;
    self.loopBraceView.width = self.width;
    self.loopBraceView.height = 1;
    self.loopBraceView.fillBar = YES;
    self.loopBraceView.visible = NO;
    self.loopBraceView.startPercentage = 0; // TODO
    self.loopBraceView.endPercentage = 100;
    
    // Pattern view
    self.patternView = [[EatsGridPatternView alloc] init];
    self.patternView.delegate = self;
    self.patternView.x = 0;
    self.patternView.y = 1;
    self.patternView.width = self.width;
    self.patternView.height = self.height - 1;
    self.patternView.foldFrom = EatsPatternViewFoldFrom_Top;
    self.patternView.mode = EatsPatternViewMode_Play;
    self.patternView.pattern = self.pattern;
    self.patternView.patternHeight = self.height;
    
    // Make the correct playMode button active and listen for changes to keep it correct
    [self setPlayMode:[self.page.playMode intValue]];
    [self.page addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Set the other buttons
    [self setActivePageButton];
    [self setActivePatternButton];
    
    // Add everything to sub views
    self.subViews = [[NSMutableSet alloc] initWithObjects:self.loopBraceView, self.patternView, nil];
    [self.subViews addObjectsFromArray:self.pageButtons];
    [self.subViews addObjectsFromArray:self.patternButtons];
    [self.subViews addObjectsFromArray:self.playModeButtons];
    [self.subViews addObjectsFromArray:self.controlButtons];
    
    // Start animateIn
    self.animationFrame = 0;
    int speedMultiplier = 8 / self.height;
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:( 1.0 * speedMultiplier ) / ANIMATION_FRAMERATE
                                                           target:self
                                                         selector:@selector(animateIn:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) dealloc
{
    [self.page removeObserver:self forKeyPath:@"playMode"];
    
    if( self.animationTimer )
        [self.animationTimer invalidate];
    
    if( self.bpmRepeatTimer )
        [self.bpmRepeatTimer invalidate];
}

- (void) updateView
{
    // Update PatternView sub view
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"SELF == %@", self.pattern];
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
    
    self.patternView.pattern = [patternMatches lastObject];
    self.patternView.currentStep = [self.page.currentStep unsignedIntValue];
    
    [super updateView];
}

// Activates the playMode button
- (void) setPlayMode:(EatsSequencerPlayMode)playMode
{
    uint i = 0;
    for ( EatsGridButtonView *button in self.playModeButtons ) {
        if( i == playMode )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
    
    [self updateView];
}

- (void) setActivePageButton
{
    uint i = 0;
    for ( EatsGridButtonView *button in self.pageButtons ) {
        if( i == [self.page.id intValue] )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
    
    [self updateView];
}

- (void) setActivePatternButton
{
    uint i = 0;
    for ( EatsGridButtonView *button in self.patternButtons ) {
        if( i == [self.page.id intValue] )
            button.buttonState = EatsButtonViewState_Active;
        else
            button.buttonState = EatsButtonViewState_Inactive;
        i++;
    }
    
    [self updateView];
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
    self.animationFrame ++;
    
    [self animateIncrement:1];
    
    [self updateView];
    
    // Final frame
    if( self.animationFrame == (self.height / 2) - 1 ) { 
        [timer invalidate];
        self.animationTimer = nil;
    }
    
}

- (void) animateOut:(NSTimer *)timer
{
    self.animationFrame ++;
        
    if( self.patternView.height == self.height - 1 ) { // Final frame
        
        [timer invalidate];
        self.animationTimer = nil;
        
        [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
    }
    
    
    [self animateIncrement:-1];
    
    [self updateView];
}

- (void) animateIncrement:(int)amount
{
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

- (void) decrementBPM:(NSTimer *)timer
{
    [timer invalidate];
    self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(decrementBPM:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    if( [self.sequencer.bpm intValue] > 20 )
        self.sequencer.bpm = [NSNumber numberWithInt:[self.sequencer.bpm intValue] - 1];
}

- (void) incrementBPM:(NSTimer *)timer
{
    [timer invalidate];
    self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(incrementBPM:)
                                                         userInfo:nil
                                                          repeats:YES];
    
    if( [self.sequencer.bpm intValue] < 300 )
    self.sequencer.bpm = [NSNumber numberWithInt:[self.sequencer.bpm intValue] + 1];
}



#pragma mark - Sub view delegate methods

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender
{
    BOOL buttonDown = [down boolValue];
    
    // Page buttons
    if ( [self.pageButtons containsObject:sender] ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            // Change the page
            [self setActivePageButton];
            NSLog(@"Page button %lu", [self.pageButtons indexOfObject:sender]);
        }
    }
    
    // Pattern buttons
    if ( [self.patternButtons containsObject:sender] ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            // Change the pattern
            [self setActivePatternButton];
            NSLog(@"Pattern button %lu", [self.patternButtons indexOfObject:sender]);
        }
    }
    
    // Play mode pause button
    if( sender == self.pauseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            self.page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
        }
        
    // Play mode forward button
    } else if( sender == self.forwardButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            self.page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
        }
        
    // Play mode reverse button
    } else if( sender == self.reverseButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            self.page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
        }
        
    // Play mode random button
    } else if( sender == self.randomButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            self.page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];   
        }
        
    // TODO: BPM- button
    } else if( sender == self.bpmDecrementButton ) {
        if ( buttonDown ) {
            
            if( !self.bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                if( [self.sequencer.bpm intValue] > 20 )
                    self.sequencer.bpm = [NSNumber numberWithInt:[self.sequencer.bpm intValue] - 1];
                
                self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(decrementBPM:)
                                                                     userInfo:nil
                                                                      repeats:YES];
            }
            
        } else {
            
            if( self.bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                [self.bpmRepeatTimer invalidate];
                self.bpmRepeatTimer = nil;
            }
            
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // TODO: BPM+ button
    } else if( sender == self.bpmIncrementButton ) {
        if ( buttonDown ) {
            
            if( !self.bpmRepeatTimer ) {
                
                sender.buttonState = EatsButtonViewState_Down;
                if( [self.sequencer.bpm intValue] < 300 )
                    self.sequencer.bpm = [NSNumber numberWithInt:[self.sequencer.bpm intValue] + 1];
                
                self.bpmRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                       target:self
                                                                     selector:@selector(incrementBPM:)
                                                                     userInfo:nil
                                                                      repeats:YES];
            }
            
        } else {
            
            if( self.bpmRepeatTimer && sender.buttonState == EatsButtonViewState_Down ) {
                [self.bpmRepeatTimer invalidate];
                self.bpmRepeatTimer = nil;
            }
            
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // TODO: Clear button
    } else if( sender == self.clearButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
        } else {
            NSLog(@"Clear");
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // Exit button
    } else if( sender == self.exitButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
        } else {
                        
            // Start animateOut
            [self animateIncrement:-1];
            
            self.animationFrame = 0;
            int speedMultiplier = 8 / self.height;
            self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:( 1.0 * speedMultiplier ) / ANIMATION_FRAMERATE
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
    NSLog(@"start: %f end: %f", sender.startPercentage, sender.endPercentage );
    [self updateView];
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    if( down ) {
        // Scrub the loop
        self.page.nextStep = [NSNumber numberWithUnsignedInt:x];
        if( [self.page.playMode intValue] == EatsSequencerPlayMode_Pause )
            self.page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
    }
}

@end
