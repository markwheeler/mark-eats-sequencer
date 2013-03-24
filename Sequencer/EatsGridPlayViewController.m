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

@interface EatsGridPlayViewController ()

@property SequencerPage                 *page;
@property SequencerPattern              *pattern;

@property EatsGridPatternView           *patternView;

@property EatsGridButtonView            *pauseButton;
@property EatsGridButtonView            *forwardButton;
@property EatsGridButtonView            *reverseButton;
@property EatsGridButtonView            *randomButton;
@property EatsGridButtonView            *bpmDecrementButton;
@property EatsGridButtonView            *bpmIncrementButton;
@property EatsGridButtonView            *clearButton;
@property EatsGridButtonView            *exitButton;

@property NSArray                       *playModeButtons;

@end

@implementation EatsGridPlayViewController

- (void) setupView
{
    
    // Get the page
    NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
    pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == 0"];
    
    NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
    self.page = [pageMatches lastObject];
    
    // Get the pattern
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"(inPage == %@) AND (id == 0)", self.page];
    
    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
    self.pattern = [patternMatches lastObject];
    
    // Create the sub views
    self.patternView = [[EatsGridPatternView alloc] init];
    self.patternView.delegate = self;
    self.patternView.x = 0;
    self.patternView.y = self.height / 2;
    self.patternView.width = self.width;
    self.patternView.height = self.height / 2;
    self.patternView.mode = EatsPatternViewMode_Play;
    self.patternView.pattern = self.pattern;
    
    uint buttonRow = 0;
    if( self.width < 16 ) buttonRow = 1;

    self.pauseButton = [[EatsGridButtonView alloc] init];
    self.pauseButton.delegate = self;
    self.pauseButton.x = self.width - 8;
    self.pauseButton.y = buttonRow;
    self.clearButton.inactiveBrightness = 5;
    
    self.forwardButton = [[EatsGridButtonView alloc] init];
    self.forwardButton.delegate = self;
    self.forwardButton.x = self.width - 7;
    self.forwardButton.y = buttonRow;
    self.clearButton.inactiveBrightness = 5;
    
    self.reverseButton = [[EatsGridButtonView alloc] init];
    self.reverseButton.delegate = self;
    self.reverseButton.x = self.width - 6;
    self.reverseButton.y = buttonRow;
    self.clearButton.inactiveBrightness = 5;
    
    self.randomButton = [[EatsGridButtonView alloc] init];
    self.randomButton.delegate = self;
    self.randomButton.x = self.width - 5;
    self.randomButton.y = buttonRow;
    self.clearButton.inactiveBrightness = 5;
    
    self.bpmDecrementButton = [[EatsGridButtonView alloc] init];
    self.bpmDecrementButton.delegate = self;
    self.bpmDecrementButton.x = self.width - 4;
    self.bpmDecrementButton.y = buttonRow;
    
    self.bpmIncrementButton = [[EatsGridButtonView alloc] init];
    self.bpmIncrementButton.delegate = self;
    self.bpmIncrementButton.x = self.width - 3;
    self.bpmIncrementButton.y = buttonRow;
    
    self.clearButton = [[EatsGridButtonView alloc] init];
    self.clearButton.delegate = self;
    self.clearButton.x = self.width - 2;
    self.clearButton.y = buttonRow;
    self.clearButton.inactiveBrightness = 5;
    
    self.exitButton = [[EatsGridButtonView alloc] init];
    self.exitButton.delegate = self;
    self.exitButton.x = self.width - 1;
    self.exitButton.y = buttonRow;
    self.exitButton.inactiveBrightness = 8;
    
    // Make the correct playMode button active and listen for changes to keep it correct
    self.playModeButtons = [[NSArray alloc] initWithObjects:self.pauseButton, self.forwardButton, self.reverseButton, self.randomButton, nil];
    [self setPlayMode:[self.page.playMode intValue]];
    [self.page addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
    self.subViews = [[NSSet alloc] initWithObjects:self.patternView,
                                                   self.pauseButton,
                                                   self.forwardButton,
                                                   self.reverseButton,
                                                   self.randomButton,
                                                   self.bpmDecrementButton,
                                                   self.bpmIncrementButton,
                                                   self.clearButton,
                                                   self.exitButton,
                                                   nil];
}

- (void) dealloc
{
    [self.page removeObserver:self forKeyPath:@"playMode"];
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

// Actives the playMode button
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

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    
    if ( [keyPath isEqual:@"playMode"] )
        [self setPlayMode:[[change valueForKey:@"new"] intValue]];
}



#pragma mark - Sub view delegate methods

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

- (void) eatsGridButtonViewPressed:(NSNumber *)down sender:(EatsGridButtonView *)sender
{
    BOOL buttonDown = [down boolValue];
    
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
            sender.buttonState = EatsButtonViewState_Down;
            NSLog(@"BPM-");
        } else {
            sender.buttonState = EatsButtonViewState_Inactive;
        }
        
    // TODO: BPM+ button
    } else if( sender == self.bpmIncrementButton ) {
        if ( buttonDown ) {
            sender.buttonState = EatsButtonViewState_Down;
            NSLog(@"BPM+");
        } else {
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
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
            return;
        }
    }
    
    [self updateView];

}

@end
