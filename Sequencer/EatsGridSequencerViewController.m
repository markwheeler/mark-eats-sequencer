//
//  EatsGridSequencerViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerViewController.h"
#import "EatsGridNavigationController.h"
#import "Sequencer.h"
#import "Preferences.h"

#define ANIMATION_FRAMERATE 15
#define PAGE_ANIMATION_EASE 0.04
#define NOTE_EDIT_IN_OUT_ANIMATION_LENGTH 4


@interface EatsGridSequencerViewController ()

@property Preferences                       *sharedPreferences;

@property SequencerNote                     *activeEditNote;
@property BOOL                              lastDownWasInEditMode;

@property EatsGridPatternView               *patternView;
@property EatsGridHorizontalSliderView      *velocityView;
@property EatsGridHorizontalSliderView      *lengthView;
@property EatsGridHorizontalSliderView      *modulationValueAView;
@property EatsGridHorizontalSliderView      *modulationValueBView;

@property NSTimer                           *editNoteAnimationTimer;
@property uint                              editNoteAnimationFrame;

@property NSTimer                           *pageAnimationTimer;
@property uint                              pageAnimationFrame;
@property float                             pageAnimationSpeedMultiplier;

@end

@implementation EatsGridSequencerViewController

- (void) setupView
{
    dispatch_sync(self.gridQueue, ^(void) {
        if( self.width > 8 )
            self.pageAnimationSpeedMultiplier = 0.5;
        else
            self.pageAnimationSpeedMultiplier = 8.0;

        self.sharedPreferences = [Preferences sharedPreferences];

        // Create the sub views
        self.patternView = [[EatsGridPatternView alloc] init];
        self.patternView.delegate = self;
        self.patternView.x = 0;
        self.patternView.y = 0;
        self.patternView.width = self.width;
        self.patternView.height = self.height;
        self.patternView.mode = EatsPatternViewMode_Edit;
        self.patternView.patternHeight = self.height;
        self.patternView.gridQueue = self.gridQueue;
        
        self.velocityView = [[EatsGridHorizontalSliderView alloc] init];
        self.velocityView.delegate = self;
        self.velocityView.x = 0;
        self.velocityView.y = 0;
        self.velocityView.width = self.width;
        self.velocityView.height = 1;
        self.velocityView.fillBar = YES;
        self.velocityView.visible = NO;

        self.lengthView = [[EatsGridHorizontalSliderView alloc] init];
        self.lengthView.delegate = self;
        self.lengthView.x = 0;
        self.lengthView.y = 1;
        self.lengthView.width = self.width;
        self.lengthView.height = 1;
        self.lengthView.fillBar = YES;
        self.lengthView.visible = NO;
        
        self.modulationValueAView = [[EatsGridHorizontalSliderView alloc] init];
        self.modulationValueAView.delegate = self;
        self.modulationValueAView.x = 0;
        self.modulationValueAView.y = 2;
        self.modulationValueAView.width = self.width;
        self.modulationValueAView.height = 1;
        self.modulationValueAView.fillBar = YES;
        self.modulationValueAView.visible = NO;
        
        self.modulationValueBView = [[EatsGridHorizontalSliderView alloc] init];
        self.modulationValueBView.delegate = self;
        self.modulationValueBView.x = 0;
        self.modulationValueBView.y = 3;
        self.modulationValueBView.width = self.width;
        self.modulationValueBView.height = 1;
        self.modulationValueBView.fillBar = YES;
        self.modulationValueBView.visible = NO;

        self.subViews = [[NSMutableSet alloc] initWithObjects:self.patternView,
                                                              self.velocityView,
                                                              self.lengthView,
                                                              self.modulationValueAView,
                                                              self.modulationValueBView,
                                                              nil];

        [self updatePatternNotes];
        [self updateView];

        // Sequencer page notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pagePatternNotesDidChange:) name:kSequencerPagePatternNotesDidChangeNotification object:self.sequencer];

        // Sequencer note notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteLengthDidChange:) name:kSequencerNoteLengthDidChangeNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteVelocityDidChange:) name:kSequencerNoteVelocityDidChangeNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteModulationValuesDidChange:) name:kSequencerNoteModulationValuesDidChangeNotification object:self.sequencer];

        // Sequencer state notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateCurrentPageDidChangeLeft:) name:kSequencerStateCurrentPageDidChangeLeftNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateCurrentPageDidChangeRight:) name:kSequencerStateCurrentPageDidChangeRightNotification object:self.sequencer];

        // Sequencer page state notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateCurrentPatternIdDidChange:) name:kSequencerPageStateCurrentPatternIdDidChangeNotification object:self.sequencer];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateCurrentStepDidChange:) name:kSequencerPageStateCurrentStepDidChangeNotification object:self.sequencer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStateNextStepDidChange:) name:kSequencerPageStateNextStepDidChangeNotification object:self.sequencer];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStatePlayModeDidChange:) name:kSequencerPageStatePlayModeDidChangeNotification object:self.sequencer];
    });
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) updateView
{
    [super updateView];
}



#pragma mark - Private methods

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
    self.patternView.x += amount;
    
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        
        float percentageOfAnimationComplete = (float)self.pageAnimationFrame / ( self.width - 5 );
        float opacity = ( 0.7 * percentageOfAnimationComplete ) + 0.3;
        
        self.patternView.opacity = opacity;
        
    } else if( self.patternView.opacity != 1 ) {
        self.patternView.opacity = 1;
    }
}

- (void) enterNoteEditModeFor:(SequencerNote *)note
{
    // DEBUG LOG temp logging to track down bug x6
    NSLog(@"1 entering note edit mode for: %i,%i %@", note.step, note.row, note );
    
    dispatch_async(self.gridQueue, ^(void) {
        self.patternView.mode = EatsPatternViewMode_NoteEdit;
        self.patternView.enabled = NO;
        
        self.editNoteAnimationFrame = 0;
        
        // Collapse pattern from bottom
        if( note.row > ( self.height / 2 ) - 1 ) {
            self.patternView.foldFrom = EatsPatternViewFoldFrom_Bottom;
            
        // Or from top
        } else {
            self.patternView.foldFrom = EatsPatternViewFoldFrom_Top;
        }
        
        self.patternView.y = 1;
        
        self.velocityView.y = -3;
        self.lengthView.y = -2;
        self.modulationValueAView.y = -1;
        self.modulationValueBView.y = 0;
        
        self.modulationValueBView.visible = YES;
        
        self.patternView.height = self.height - 1;
        self.patternView.activeEditNote = note;
        
        float animationProgress = ( self.editNoteAnimationFrame + 1 ) / (float)NOTE_EDIT_IN_OUT_ANIMATION_LENGTH;
        
        self.patternView.noteEditModeAnimationAmount = animationProgress;
        self.patternView.animatingIn = YES;
        
        self.activeEditNote = note;
        
        [self updateNoteVelocity];
        [self updateNoteLength];
        [self updateNoteModulationValues];
        
        [self updateView];
        
        // DEBUG LOG
        NSLog(@"2 entering note edit mode for: %i,%i %@", note.step, note.row, note );
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            self.editNoteAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ( ANIMATION_FRAMERATE * 2.0 )
                                                               target:self
                                                             selector:@selector(animateInNoteEditMode:)
                                                             userInfo:nil
                                                              repeats:YES];
            [self.editNoteAnimationTimer setTolerance:self.editNoteAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
            
            // Make sure we fire even when the UI is tracking mouse down stuff
            NSRunLoop *runloop = [NSRunLoop currentRunLoop];
            [runloop addTimer:self.editNoteAnimationTimer forMode: NSRunLoopCommonModes];
            [runloop addTimer:self.editNoteAnimationTimer forMode: NSEventTrackingRunLoopMode];
            
            // DEBUG LOG
            NSLog(@"3 entering note edit mode for: %i,%i %@", note.step, note.row, note );
            
        });
    });
}

- (void) exitNoteEditMode
{
    dispatch_async(self.gridQueue, ^(void) {
        self.patternView.enabled = NO;
        
        self.editNoteAnimationFrame = 0;
        
        self.patternView.y --;
        
        self.velocityView.visible = NO;
        self.lengthView.y --;
        self.modulationValueAView.y --;
        self.modulationValueBView.y --;
        
        self.patternView.height = self.height - 3;
        
        float animationProgress = 1.0 - ( ( self.editNoteAnimationFrame + 1 ) / (float)NOTE_EDIT_IN_OUT_ANIMATION_LENGTH );
        
        self.patternView.noteEditModeAnimationAmount = animationProgress;
        self.patternView.animatingIn = NO;
        
        
        [self updateView];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
        
            self.editNoteAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ( ANIMATION_FRAMERATE * 2.0 )
                                                                   target:self
                                                                 selector:@selector(animateOutNoteEditMode:)
                                                                 userInfo:nil
                                                                  repeats:YES];
            [self.editNoteAnimationTimer setTolerance:self.editNoteAnimationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
            
            // Make sure we fire even when the UI is tracking mouse down stuff
            NSRunLoop *runloop = [NSRunLoop currentRunLoop];
            [runloop addTimer:self.editNoteAnimationTimer forMode: NSRunLoopCommonModes];
            [runloop addTimer:self.editNoteAnimationTimer forMode: NSEventTrackingRunLoopMode];
            
        });
    });
}

- (void) exitNoteEditModeInstantly
{
    self.activeEditNote = nil;
    self.velocityView.visible = NO;
    self.lengthView.visible = NO;
    self.modulationValueAView.visible = NO;
    self.modulationValueBView.visible = NO;
    self.patternView.y = 0;
    self.patternView.height = self.height;
    self.patternView.enabled = YES;
    self.patternView.activeEditNote = nil;
    self.patternView.noteEditModeAnimationAmount = 0.0;
    self.patternView.mode = EatsPatternViewMode_Edit;
    
    if( self.editNoteAnimationTimer ) {
        [self.editNoteAnimationTimer invalidate];
        self.editNoteAnimationTimer = nil;
    }
}

- (void) animateInNoteEditMode:(NSTimer *)timer
{
    dispatch_async( self.gridQueue, ^(void) {
        
        // DEBUG LOG
        NSLog(@"4 entering note edit mode");
        
        self.editNoteAnimationFrame ++;
        
        if( self.editNoteAnimationFrame < NOTE_EDIT_IN_OUT_ANIMATION_LENGTH ) {
            
            float animationProgress = ( self.editNoteAnimationFrame + 1 ) / (float)NOTE_EDIT_IN_OUT_ANIMATION_LENGTH;
            
            self.patternView.noteEditModeAnimationAmount = animationProgress;
            
            self.patternView.height --;
            self.patternView.y ++;
            
            self.velocityView.y ++;
            self.lengthView.y ++;
            self.modulationValueAView.y ++;
            self.modulationValueBView.y ++;
            
            if( self.velocityView.y >= 0 )
                self.velocityView.visible = YES;
            if( self.lengthView.y >= 0 )
                self.lengthView.visible = YES;
            if( self.modulationValueAView.y >= 0 )
                self.modulationValueAView.visible = YES;
            
        } else { // Final frame
            
            self.patternView.enabled = YES;
            
            [timer invalidate];
            self.editNoteAnimationTimer = nil;
            
        }
        
        // DEBUG LOG
        NSLog(@"5 entering note edit mode");
        
        [self updateView];
        
        // DEBUG LOG
        NSLog(@"6 entering note edit mode");
    });

}

- (void) animateOutNoteEditMode:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
        
        self.editNoteAnimationFrame ++;
        
        if( self.editNoteAnimationFrame < NOTE_EDIT_IN_OUT_ANIMATION_LENGTH ) {
            
            float animationProgress = 1.0 - ( ( self.editNoteAnimationFrame + 1 ) / (float)NOTE_EDIT_IN_OUT_ANIMATION_LENGTH );
            
            self.patternView.noteEditModeAnimationAmount = animationProgress;
            
            self.patternView.height ++;
            self.patternView.y --;
            
            self.lengthView.y --;
            self.modulationValueAView.y --;
            self.modulationValueBView.y --;
            
            if( self.lengthView.y < 0 )
                self.lengthView.visible = NO;
            if( self.modulationValueAView.y < 0 )
                self.modulationValueAView.visible = NO;
            if( self.modulationValueBView.y < 0 )
                self.modulationValueBView.visible = NO;
            
        } else { // Final frame
            
            self.patternView.activeEditNote = nil;
            self.patternView.mode = EatsPatternViewMode_Edit;
            self.patternView.enabled = YES;
            
            self.activeEditNote = nil;
            
            [timer invalidate];
            self.editNoteAnimationTimer = nil;
        }
        
        [self updateView];
    });
}



#pragma mark - Sub view updates

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

- (void) updateNoteLength
{
    float stepPercentage = ( 100.0 / self.velocityView.width );
    self.activeEditNote = [self.sequencer noteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    self.patternView.activeEditNote = self.activeEditNote;
    
    self.lengthView.percentage = ( ( ( ( (float)self.activeEditNote.length / self.lengthView.width )  * 100.0) - stepPercentage) / (100.0 - stepPercentage) ) * 100.0;
}

- (void) updateNoteVelocity
{
    float oneStepOf127 = (float)SEQUENCER_MIDI_MAX  / self.velocityView.width;
    float range = SEQUENCER_MIDI_MAX - oneStepOf127;
    self.activeEditNote = [self.sequencer noteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    self.patternView.activeEditNote = self.activeEditNote;
    
    float percentageForVelocitySlider = 100.0 * ( ( self.activeEditNote.velocity - oneStepOf127 ) / range );
    if( percentageForVelocitySlider < 0 )
        percentageForVelocitySlider = 0;
    
    self.velocityView.percentage = percentageForVelocitySlider;
}

- (void) updateNoteModulationValues
{
    
    self.activeEditNote = [self.sequencer noteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    self.patternView.activeEditNote = self.activeEditNote;
    
    // We center half values on the step left of center on the grid
    float midStepValue = ( self.modulationValueAView.width * 0.5 - 1 ) / ( self.modulationValueAView.width - 1 );
    
    for( int i = 0; i < NUMBER_OF_MODULATION_BUSSES; i ++ ) {
        
        float newValue = [self.activeEditNote.modulationValues[i] floatValue];
        
        float sliderValue;
        
        if( newValue <= 0.5 ) {
            float valueInHalf = newValue / 0.5;
            sliderValue = midStepValue * valueInHalf;
        } else {
            float valueInHalf = ( newValue - 0.5 ) / 0.5;
            sliderValue = midStepValue + ( 1.0 - midStepValue ) * valueInHalf;
        }
        
        // Set
        if( i == 0 )
            self.modulationValueAView.percentage = sliderValue * 100.0;
        else if( i == 1 )
            self.modulationValueBView.percentage = sliderValue * 100.0;
        
    }
}

- (void) updatePageLeft
{
    // Start animate left
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    self.patternView.x = - self.width + 4;
    self.patternView.enabled = NO;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        self.patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:1];
    
    [self performSelectorOnMainThread:@selector(scheduleAnimatePageLeftTimer) withObject:nil waitUntilDone:YES];
}

- (void) updatePageRight
{
    // Start animate right
    [self.pageAnimationTimer invalidate];
    self.pageAnimationTimer = nil;
    
    self.patternView.x = self.width - 4;
    self.patternView.enabled = NO;
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        self.patternView.opacity = 0;
    }
    self.pageAnimationFrame = 0;
    [self animatePageIncrement:-1];
    [self performSelectorOnMainThread:@selector(scheduleAnimatePageRightTimer) withObject:nil waitUntilDone:YES];
}


#pragma mark - Notifications

- (void) pagePatternNotesDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

- (void) noteLengthDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            SequencerNote *note = [notification.userInfo valueForKey:@"note"];
            if( self.activeEditNote && note.row == self.activeEditNote.row && note.step ==  self.activeEditNote.step ) {
                [self updateNoteLength];
            }
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

- (void) noteVelocityDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            SequencerNote *note = [notification.userInfo valueForKey:@"note"];
            if( self.activeEditNote && note.row == self.activeEditNote.row && note.step ==  self.activeEditNote.step ) {
                [self updateNoteVelocity];
            }
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

- (void) noteModulationValuesDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPattern:notification] ) {
            SequencerNote *note = [notification.userInfo valueForKey:@"note"];
            if( self.activeEditNote && note.row == self.activeEditNote.row && note.step ==  self.activeEditNote.step ) {
                [self updateNoteModulationValues];
                [self updateView];
            }
        }
    });
}

- (void) stateCurrentPageDidChangeLeft:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( self.patternView.mode != EatsPatternViewMode_Edit )
            [self exitNoteEditModeInstantly];
        [self updatePatternNotes];
        [self updatePageLeft];
        [self updateView];
    });
}

- (void) stateCurrentPageDidChangeRight:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( self.patternView.mode != EatsPatternViewMode_Edit )
            [self exitNoteEditModeInstantly];
        [self updatePatternNotes];
        [self updatePageRight];
        [self updateView];
    });
}

- (void) pageStateCurrentPatternIdDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            if( self.patternView.mode != EatsPatternViewMode_Edit )
                [self exitNoteEditModeInstantly];
            [self updatePatternNotes];
            [self updateView];
        }
    });
}

- (void) pageStateCurrentStepDidChange:(NSNotification *)notification
{
    dispatch_async(self.gridQueue, ^(void) {
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updatePatternNotes];
            [self updateView];
        }
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
        if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
            [self updatePatternNotes];
            [self updateView];
        }
    });
}



#pragma mark - Sub view delegate methods

// Both sliders
- (void) eatsGridHorizontalSliderViewUpdated:(EatsGridHorizontalSliderView *)sender
{
    
    // Velocity
    if( sender == self.velocityView ) {
        
        float oneStepOf127 = (float)SEQUENCER_MIDI_MAX / sender.width;
        float range = SEQUENCER_MIDI_MAX - oneStepOf127;
        
        float newVelocity = range * (sender.percentage / 100.0);
        newVelocity += oneStepOf127;
        newVelocity = roundf( newVelocity );
        
        [self.sequencer setVelocity:newVelocity forNoteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
        
    // Length
    } else if( sender == self.lengthView ) {
        int newLength = roundf( ( sender.width - 1 ) * ( sender.percentage / 100.0 ) ) + 1;
        [self.sequencer setLength:newLength forNoteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
        
    // Modulation
    } else {
        
        // We center on the step left of center on the grid
        float midStepValue = ( sender.width * 0.5 - 1 ) / ( sender.width - 1 );
        
        float newValue = sender.percentage / 100.0;
        float adjustedValue;
        
        if( newValue <= midStepValue ) { // L
            float valueInHalf = newValue / midStepValue;
            adjustedValue = 0.5 * valueInHalf;
            
        } else { // R
            float valueInHalf = ( newValue - midStepValue ) / ( 1.0 - midStepValue );
            adjustedValue = 0.5 + 0.5 * valueInHalf;
        }
        
        // Set the correct modulation bus
        
        int modBus = 0;
        if( sender == self.modulationValueAView )
            modBus = 0;
        else if( sender == self.modulationValueBView )
            modBus = 1;
        
        [self.sequencer setModulationValue:adjustedValue forBus:modBus forNoteAtStep:self.activeEditNote.step atRow:self.activeEditNote.row inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
        
    }
}

- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender
{
    uint x = [[xyDown valueForKey:@"x"] unsignedIntValue];
    uint y = [[xyDown valueForKey:@"y"] unsignedIntValue];
    BOOL down = [[xyDown valueForKey:@"down"] boolValue];
    
    // Down
    if( down ) {
        
        // Edit mode
        if( sender.mode == EatsPatternViewMode_Edit ) {
            
            self.lastDownWasInEditMode = YES;
            
            dispatch_sync(self.gridQueue, ^(void) {
                [self updateView];
            });
            
        // Note edit mode
        } else if ( sender.mode == EatsPatternViewMode_NoteEdit ) {
            
            self.lastDownWasInEditMode = NO;
            
            [self exitNoteEditMode];
        }
    
    // Release
    } else if( sender.mode == EatsPatternViewMode_Edit && self.lastDownWasInEditMode ) {
        
        // TODO comment out of release
        NSLog(@"SequencerViewController.eatsGridPatternViewPressAt:%u,%u (release)", x, y );
        
        [self.sequencer addOrRemoveNoteThatIsSelectableAtStep:x atRow:self.height - 1 - y inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    }
}

- (void) eatsGridPatternViewLongPressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender
{
    uint x = [[xy valueForKey:@"x"] unsignedIntValue];
    uint y = [[xy valueForKey:@"y"] unsignedIntValue];
    
    // See if we have a note there
    SequencerNote *foundNote = [self.sequencer noteThatIsSelectableAtStep:x atRow:self.height - 1 - y inPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    
    // DEBUG LOG
    NSLog( @"Long press at %@", xy );
    
    if( foundNote )
        [self enterNoteEditModeFor:foundNote];
    else
        [self showView:[NSNumber numberWithInt:EatsGridViewType_Play]];
}

@end