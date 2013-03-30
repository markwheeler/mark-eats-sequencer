//
//  Document.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Document.h"
#import <VVMIDI/VVMIDI.h>
#import "EatsDocumentController.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "ClockTick.h"
#import "ScaleGeneratorSheetController.h"
#import "EatsExternalClockCalculator.h"
#import "EatsGridNavigationController.h"
#import "EatsScaleGenerator.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

@property Preferences                   *sharedPreferences;
@property EatsClock                     *clock;
@property ClockTick                     *clockTick;
@property EatsExternalClockCalculator   *externalClockCalculator;
@property EatsGridNavigationController  *gridNavigationController;
@property ScaleGeneratorSheetController *scaleGeneratorSheetController;

@property NSMutableArray                *quantizationArray;
@property NSArray                       *swingArray;

@property NSAlert                       *notesOutsideGridAlert;
@property BOOL                          checkedForNotesOutsideGrid;

@property (weak) IBOutlet NSWindow              *documentWindow;
@property (weak) IBOutlet NSArrayController     *pitchesArrayController;
@property (weak) IBOutlet NSObjectController    *pageObjectController;

@property (weak) IBOutlet NSTableView   *rowPitchesTableView;
@property (weak) IBOutlet NSPopUpButton *stepQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton *patternQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton *stepLengthPopup;
@property (weak) IBOutlet NSPopUpButton *swingPopup;
@property (weak) IBOutlet NSPopUpButton *currentPagePopup;

@end


@implementation Document


#pragma mark - Setters and getters

@synthesize isActive = _isActive;
@synthesize currentPage = _currentPage;

- (void)setIsActive:(BOOL)isActive
{
    _isActive = isActive;
    if(self.gridNavigationController) self.gridNavigationController.isActive = isActive;
}

- (BOOL)isActive
{
    return _isActive;
}

- (void) setCurrentPage:(SequencerPage *)currentPage
{
    _currentPage = currentPage;
    self.pitchesArrayController.fetchPredicate = [NSPredicate predicateWithFormat:@"inPage == %@", currentPage];
    self.pageObjectController.fetchPredicate = [NSPredicate predicateWithFormat:@"self == %@", currentPage];
    [self updateSequencerPageUI];
}

- (SequencerPage *) currentPage
{
    return _currentPage;
}



#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.

        self.isActive = NO;
        
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create the quantization settings
        self.quantizationArray = [NSMutableArray array];
        int quantizationSetting = MIN_QUANTIZATION;
        while ( quantizationSetting >= MAX_QUANTIZATION ) {
            
            NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:quantizationSetting], @"quantization", nil];
            
            if( quantizationSetting == 1)
                [quantization setObject:[NSString stringWithFormat:@"1 bar"] forKey:@"label"];
            else
                [quantization setObject:[NSString stringWithFormat:@"1/%i", quantizationSetting] forKey:@"label"];
            
            [self.quantizationArray insertObject:quantization atIndex:0];
            quantizationSetting = quantizationSetting / 2;
        }
        
        // Create the swing settings
        self.swingArray = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:50], @"swing", @"50 (Straight)", @"label", nil],
                                                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:54], @"swing", @"54", @"label", nil],
                                                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:58], @"swing", @"58", @"label", nil],
                                                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:63], @"swing", @"63", @"label", nil],
                                                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:67], @"swing", @"67 (Triplets)", @"label", nil],
                                                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:71], @"swing", @"71", @"label", nil],
                                                    nil];        
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.sequencer removeObserver:self forKeyPath:@"bpm"];
    [self.sequencer removeObserver:self forKeyPath:@"stepQuantization"];
    [self.sequencer removeObserver:self forKeyPath:@"patternQuantization"];
    [self.currentPage removeObserver:self forKeyPath:@"stepLength"];
    [self.currentPage removeObserver:self forKeyPath:@"swing"];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    
    // Setup the Core Data object
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
    NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:nil];
    
    if([matches count]) {
        self.sequencer = [matches lastObject];
    } else {
        // Create initial structure
        self.sequencer = [Sequencer sequencerWithPages:8 inManagedObjectContext:self.managedObjectContext];
        
        [Sequencer addDummyDataToSequencer:self.sequencer inManagedObjectContext:self.managedObjectContext];
    }
    
    // Set the current page to the first one
    self.currentPage = [self.sequencer.pages objectAtIndex:0];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[aController window]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[aController window]];
    
    // Create a Clock and set it up
    
    self.clockTick = [[ClockTick alloc] init];
    self.clockTick.delegate = self;
    self.clockTick.ppqn = PPQN;
    self.clockTick.ticksPerMeasure = TICKS_PER_MEASURE;
    self.clockTick.midiClockPPQN = MIDI_CLOCK_PPQN;
    self.clockTick.minQuantization = MIN_QUANTIZATION;
    self.clockTick.sequencer = self.sequencer;
    
    self.clock = [[EatsClock alloc] init];
    self.clock.delegate = self.clockTick;
    self.clock.ppqn = PPQN;
    self.clock.qnPerMeasure = QN_PER_MEASURE;
    
    self.externalClockCalculator = [[EatsExternalClockCalculator alloc] init];
    
    // BPM
    [self updateClockBPM];
    
    // Setup UI
    [self setupUI];
    [self updateSequencerPageUI];
    
    // KVO
    [self.sequencer addObserver:self forKeyPath:@"bpm" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencer addObserver:self forKeyPath:@"stepQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencer addObserver:self forKeyPath:@"patternQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPage addObserver:self forKeyPath:@"stepLength" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPage addObserver:self forKeyPath:@"swing" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Create the gridNavigationController
    self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.managedObjectContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnected:)
                                                 name:@"GridControllerConnected"
                                               object:nil];
    
    // Start the clock right away
    [self.clock startClock];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self.clock stopClock];
    
    // TODO: These following lines shouldn't be nesecary once the dealloc bug in ClockTick is fixed.
    self.clock = nil;
    self.clockTick = nil;
    //self.gridNavigationController = nil;
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    if( documentController.lastActiveDocument != self ) {
        [documentController setActiveDocument:self];
        [self updateUI];
    }
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    if( !self.checkedForNotesOutsideGrid ) {
        NSLog(@"Checking...");
        [self checkForNotesOutsideGrid];
        self.checkedForNotesOutsideGrid = YES;
    }
}

- (void) updateUI
{
    [self.gridNavigationController updateGridView];
}


#pragma mark - Setup and update UI

- (void) setupUI
{
    [self.stepQuantizationPopup removeAllItems];
    [self.patternQuantizationPopup removeAllItems];
    [self.stepLengthPopup removeAllItems];
    
    for( NSDictionary *quantization in self.quantizationArray) {
        [self.stepQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.patternQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.stepLengthPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }
    
    [self updateStepQuantizationPopup];
    [self updatePatternQuantizationPopup];
    
    [self.swingPopup removeAllItems];
    for( NSDictionary *swing in self.swingArray) {
        [self.swingPopup addItemWithTitle:[swing valueForKey:@"label"]];
    }
    
    [self.currentPagePopup removeAllItems];
    for(SequencerPage *page in self.sequencer.pages) {
        [self.currentPagePopup addItemWithTitle:[NSString stringWithFormat:@"%@", page.id]];
    }
    
    // Table view default sort
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"row" ascending: YES];
    [self.rowPitchesTableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
}

- (void) updateSequencerPageUI
{
    [self updateStepLengthPopup];
    [self updateSwingPopup];
}

- (void) updateClockBPM
{
    self.clock.bpm = [self.sequencer.bpm floatValue];
}

- (void) updateStepQuantizationPopup
{
    [self.stepQuantizationPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencer.stepQuantization];
    }]];
}

- (void) updatePatternQuantizationPopup
{
    [self.patternQuantizationPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencer.patternQuantization];
    }]];
}

- (void) updateStepLengthPopup
{
    [self.stepLengthPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.currentPage.stepLength];
    }]];
}

- (void) updateSwingPopup
{
    [self.swingPopup selectItemAtIndex:[self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"swing"] isEqualTo:self.currentPage.swing];
    }]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ( object == self.sequencer && [keyPath isEqual:@"bpm"] )
        [self updateClockBPM];
    else if ( object == self.sequencer && [keyPath isEqual:@"stepQuantization"] )
        [self updateStepQuantizationPopup];
    else if ( object == self.sequencer && [keyPath isEqual:@"patternQuantization"] )
        [self updatePatternQuantizationPopup];
    else if ( object == self.currentPage && [keyPath isEqual:@"stepLength"] )
        [self updateStepLengthPopup];
    else if ( object == self.currentPage && [keyPath isEqual:@"swing"] )
        [self updateSwingPopup];
}



#pragma mark - Private methods

- (void) gridControllerConnected:(NSNotification *)notification
{
    [self checkForNotesOutsideGrid];
}

- (void) checkForNotesOutsideGrid
{
    // Make sure all the loops fit within the connected grid size
    for( SequencerPage *page in self.sequencer.pages ) {
        if( page.loopStart.intValue > self.sharedPreferences.gridWidth || page.loopEnd.intValue > self.sharedPreferences.gridWidth ) {
            page.loopStart = [NSNumber numberWithInt:0];
            page.loopEnd = [NSNumber numberWithInt:self.sharedPreferences.gridWidth - 1];
        }
    }
    
    // Get the notes
    NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step >= %u) OR (row >= %u)", self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight];
    
    NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];

    if( [noteMatches count] && !self.notesOutsideGridAlert ) {
         self.notesOutsideGridAlert = [NSAlert alertWithMessageText:@"This song contains notes outside of the grid controller's area."
                                         defaultButton:@"Leave notes"
                                       alternateButton:@"Remove notes"
                                           otherButton:nil
                             informativeTextWithFormat:@"Would you like to remove these %lu notes?", [noteMatches count]];
        
        [self.notesOutsideGridAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(notesOutsideGridAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
}

- (void) notesOutsideGridAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if( returnCode == NSOKButton ) {
        NSLog(@"Leave them");
        
    } else {
        NSLog(@"Remove them");
        
        // TODO remove all the notes
        
        // Get the notes
        //NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        //noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step >= %u) OR (row >= %u)", self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight];
        
        //NSArray *noteMatches = [self.managedObjectContext executeFetchRequest:noteRequest error:nil];
        
        // Remove
    }
    
    self.notesOutsideGridAlert = nil;
}


#pragma mark - Interface actions

- (IBAction)playButton:(NSButton *)sender
{
    [self.clock startClock];
}

- (IBAction)stopButton:(NSButton *)sender
{
    [self.clock stopClock];
}

- (IBAction)sequencerPauseButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Pause];
    page.nextStep = nil;
    [self.gridNavigationController updateGridView];
}


- (IBAction)sequencerForwardButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
    page.nextStep = nil;
    [self.gridNavigationController updateGridView];
}

- (IBAction)sequencerReverseButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
    page.nextStep = nil;
    [self.gridNavigationController updateGridView];
}

- (IBAction)sequencerRandomButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];
    page.nextStep = nil;
    [self.gridNavigationController updateGridView];
}

- (IBAction)scalesOpenSheetButton:(NSButton *)sender {
    if (!self.scaleGeneratorSheetController) {
        self.scaleGeneratorSheetController = [[ScaleGeneratorSheetController alloc] init];
        [self.scaleGeneratorSheetController beginSheetModalForWindow:self.documentWindow completionHandler:^(NSUInteger returnCode) {
            
            // Generate the scale
            if (returnCode == NSOKButton) {
                
                uint numberToGenerate = self.sharedPreferences.gridHeight;
                if( !numberToGenerate )
                    numberToGenerate = 32;
                
                // Generate pitches
                NSArray *pitches = [EatsScaleGenerator generateScaleType:self.scaleGeneratorSheetController.scaleType
                                                               tonicNote:self.scaleGeneratorSheetController.tonicNote
                                                                  length:numberToGenerate];
                // Reverse the array
                pitches = [[pitches reverseObjectEnumerator] allObjects];
                
                // Put them into the page
                //NSMutableOrderedSet *setOfRowPitches = [self.currentPage.pitches mutableCopy];
                int r = 0;
                
                for( NSNumber *pitch in pitches ) {
                    SequencerRowPitch *rowPitch = [self.currentPage.pitches objectAtIndex:r];
                    rowPitch.pitch = pitch;
                    r++;
                }
                
            // Cancel
            } else if (returnCode == NSCancelButton) {
                // Do nothing
                
            } else {
                NSLog(@"Unknown return code received from ScaleGeneratorSheetController");
            }
            
            // Clear up
            self.scaleGeneratorSheetController = nil;
            
        }];
    }
}

- (IBAction)stepQuantizationPopup:(NSPopUpButton *)sender
{
    self.sequencer.stepQuantization = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction)patternQuantizationPopup:(NSPopUpButton *)sender
{
    self.sequencer.patternQuantization = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction)stepLengthPopup:(NSPopUpButton *)sender
{
    self.currentPage.stepLength = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction)swingPopup:(NSPopUpButton *)sender
{
    self.currentPage.swing = [[self.swingArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"swing"];
}

- (IBAction)currentPagePopup:(NSPopUpButton *)sender
{
    self.currentPage = [self.sequencer.pages objectAtIndex:[sender indexOfSelectedItem]];
}


@end
