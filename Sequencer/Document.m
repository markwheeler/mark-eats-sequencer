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
#import "EatsSwingUtils.h"
#import "ClockTick.h"
#import "ScaleGeneratorSheetController.h"
#import "EatsGridNavigationController.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

#define SEQUENCER_PAGES 8

@property EatsClock                     *clock;
@property ClockTick                     *clockTick;
@property EatsGridNavigationController  *gridNavigationController;
@property ScaleGeneratorSheetController *scaleGeneratorSheetController;

@property NSMutableArray                *quantizationArray;
@property NSArray                       *swingArray;

@property NSAlert                       *notesOutsideGridAlert;
@property NSAlert                       *clearPatternAlert;
@property BOOL                          checkedForThingsOutsideGrid;

@property (weak) IBOutlet NSWindow              *documentWindow;
@property (weak) IBOutlet NSArrayController     *pitchesArrayController;
@property (weak) IBOutlet NSObjectController    *pageObjectController;

@property (weak) IBOutlet NSSegmentedControl    *sequencerPlaybackControls;
@property (weak) IBOutlet NSPopUpButton         *stepQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton         *patternQuantizationPopup;
@property (weak) IBOutlet NSSegmentedControl    *currentPageSegmentedControl;

@property (weak) IBOutlet NSSegmentedControl    *currentPatternSegmentedControl;
@property (weak) IBOutlet NSSegmentedControl    *pagePlaybackControls;
@property (weak) IBOutlet NSTableView           *rowPitchesTableView;
@property (weak) IBOutlet NSPopUpButton         *stepLengthPopup;
@property (weak) IBOutlet NSPopUpButton         *swingPopup;

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
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"playMode"];
    
    _currentPage = currentPage;
    _currentSequencerPageState = [[[SequencerState sharedSequencerState] pageStates] objectAtIndex:currentPage.id.unsignedIntegerValue];

    self.pitchesArrayController.fetchPredicate = [NSPredicate predicateWithFormat:@"inPage == %@", currentPage];
    self.pitchesArrayController.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"row" ascending:NO]];
    
    self.pageObjectController.fetchPredicate = [NSPredicate predicateWithFormat:@"self == %@", currentPage];
    
    [self.currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentSequencerPageState addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
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

        _bigSerialQueue = dispatch_queue_create("com.MarkEatsSequencer.BigQueue", NULL);
        
        self.isActive = NO;
        
        // Replace the NSPersistentDocument's MOC with a new one that can be used as a parent
        NSManagedObjectContext *parentMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        parentMOC.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
        self.managedObjectContext = parentMOC;
        
        // Create a child MOC with a private queue for use in background threads etc
        self.childManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        self.childManagedObjectContext.parentContext = self.managedObjectContext;
        
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
        self.swingArray = [EatsSwingUtils swingArray];
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
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"playMode"];
    [self.currentPage removeObserver:self forKeyPath:@"stepLength"];
    [self.currentPage removeObserver:self forKeyPath:@"swing"];
}

- (NSString *) windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void) windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    
    // Setup the Core Data object
    [self.managedObjectContext performBlockAndWait:^(void) {
        NSError *requestError = nil;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
        NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
        
        if( [matches count] ) {
            self.sequencer = [matches lastObject];
        } else {
            // Create initial structure
            self.sequencer = [Sequencer sequencerWithPages:SEQUENCER_PAGES inManagedObjectContext:self.managedObjectContext];
            
            [Sequencer addDummyDataToSequencer:self.sequencer inManagedObjectContext:self.managedObjectContext];
        }
        
        // Setup the SequencerState
        SequencerState *sequencerState = [SequencerState sharedSequencerState];
        [sequencerState createPageStates:SEQUENCER_PAGES];
        for( SequencerPage *page in self.sequencer.pages ) {
            [[sequencerState.pageStates objectAtIndex:page.id.unsignedIntegerValue] setCurrentStep:[page.loopEnd copy]];
        }
    }];
    
    // Setup UI
    [self setupUI];
    
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
    
    self.clockTick = [[ClockTick alloc] initWithManagedObjectContext:self.childManagedObjectContext];
    self.clockTick.delegate = self;
    self.clockTick.ppqn = PPQN;
    self.clockTick.ticksPerMeasure = TICKS_PER_MEASURE;
    self.clockTick.midiClockPPQN = MIDI_CLOCK_PPQN;
    self.clockTick.minQuantization = MIN_QUANTIZATION;
    self.clockTick.qnPerMeasure = QN_PER_MEASURE;
    self.clockTick.managedObjectContext = self.childManagedObjectContext;
    
    self.clock = [[EatsClock alloc] init];
    self.clock.delegate = self.clockTick;
    self.clock.ppqn = PPQN;
    self.clock.qnPerMeasure = QN_PER_MEASURE;
    
    // BPM
    [self updateClockBPM];
    
    // Set everything to match the model
    [self updateSequencerPageUI];
    
    // KVO
    [self.sequencer addObserver:self forKeyPath:@"bpm" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencer addObserver:self forKeyPath:@"stepQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencer addObserver:self forKeyPath:@"patternQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentSequencerPageState addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPage addObserver:self forKeyPath:@"stepLength" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPage addObserver:self forKeyPath:@"swing" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Create the gridNavigationController
    self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.childManagedObjectContext andQueue:_bigSerialQueue];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnected:)
                                                 name:@"GridControllerConnected"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerNone:)
                                                 name:@"GridControllerNone"
                                               object:nil];
    
    // External clock notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalClockStart:)
                                                 name:@"ExternalClockStart"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalClockContinue:)
                                                 name:@"ExternalClockContinue"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalClockZero:)
                                                 name:@"ExternalClockZero"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalClockStop:)
                                                 name:@"ExternalClockStop"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalClockBPM:)
                                                 name:@"ExternalClockBPM"
                                               object:nil];
    
    // Start the clock right away
    //[self.clock startClock];
}

- (void) windowWillClose:(NSNotification *)notification
{
    [self.clock stopClock];
    
    // TODO: These following lines shouldn't be nesecary once the dealloc bug in ClockTick is fixed.
    self.clock = nil;
    self.clockTick = nil;
    //self.gridNavigationController = nil;
}

+ (BOOL) autosavesInPlace
{
    return YES;
}

- (void) windowDidBecomeMain:(NSNotification *)notification
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    if( documentController.lastActiveDocument != self ) {
        [documentController setActiveDocument:self];
        [self updateUI];
    }
}

- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
    if( !self.checkedForThingsOutsideGrid ) {
        [self checkForThingsOutsideGrid];
        self.checkedForThingsOutsideGrid = YES;
    }
}

- (void) updateUI
{
    [self.gridNavigationController updateGridView];
}

- (void) clearPatternStartAlert
{
    self.clearPatternAlert = [NSAlert alertWithMessageText:@"Clear current pattern?"
                                                 defaultButton:@"Clear"
                                               alternateButton:@"Cancel"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
    
    [self.clearPatternAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(clearPatternAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) clearPatternAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if( returnCode == NSOKButton )
        [self clearPattern];
    self.clearPatternAlert = nil;
}

- (void) clearPattern
{
    NSLog(@"Clear pattern");
    
    // TODO clear pattern
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
    
    // Add items to swing popup with separators between swing types
    [self.swingPopup removeAllItems];
    for( NSDictionary *swing in self.swingArray) {
        if( [[swing valueForKey:@"label"] isEqualTo:@"-"])
            [self.swingPopup.menu addItem: [NSMenuItem separatorItem]];
        else
            [self.swingPopup addItemWithTitle:[swing valueForKey:@"label"]];
    }
    
    for(SequencerPage *page in self.sequencer.pages) {
        [self.currentPageSegmentedControl setLabel:page.name forSegment:[page.id intValue]];
    }
    
    // Table view default sort
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"row" ascending: YES];
    [self.rowPitchesTableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
}

- (void) updateSequencerPageUI
{
    [self updateStepLengthPopup];
    [self updateSwingPopup];
    [self updateCurrentPattern];
    [self updatePlayMode];
}

- (void) updateClockBPM
{
    self.clock.bpm = [self.sequencer.bpm floatValue];
    self.clockTick.bpm = [self.sequencer.bpm floatValue];
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

- (void) updateCurrentPattern
{
    [self.currentPatternSegmentedControl setSelectedSegment:_currentSequencerPageState.currentPatternId.integerValue];
}

- (void) updatePlayMode
{
    self.pagePlaybackControls.selectedSegment = self.currentSequencerPageState.playMode.integerValue;
}

- (void) updateStepLengthPopup
{
    [self.stepLengthPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.currentPage.stepLength];
    }]];
}

- (void) updateSwingPopup
{
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        if( [[obj valueForKey:@"type"] isEqualTo:self.currentPage.swingType] && [[obj valueForKey:@"amount"] isEqualTo:self.currentPage.swingAmount] )
            return YES;
        else
            return NO;
    }];
    [self.swingPopup selectItemAtIndex:index];
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
    else if ( object == self.currentSequencerPageState && [keyPath isEqual:@"currentPatternId"] )
        [self updateCurrentPattern];
    else if ( object == self.currentSequencerPageState && [keyPath isEqual:@"playMode"] )
        [self updatePlayMode];
    else if ( object == self.currentPage && [keyPath isEqual:@"stepLength"] )
        [self updateStepLengthPopup];
    else if ( object == self.currentPage && [keyPath isEqual:@"swing"] )
        [self updateSwingPopup];
}



#pragma mark - Private methods

- (void) externalClockStart:(NSNotification *)notification
{
    [self.clock startClock];
    [self.sequencerPlaybackControls setSelectedSegment:1];
}

- (void) externalClockContinue:(NSNotification *)notification
{
    [self.clock continueClock];
    [self.sequencerPlaybackControls setSelectedSegment:1];
}

- (void) externalClockZero:(NSNotification *)notification
{
    [self.clock setClockToZero];
}

- (void) externalClockStop:(NSNotification *)notification
{
    [self.clock stopClock];
    [self.sequencerPlaybackControls setSelectedSegment:0];
}

- (void) externalClockBPM:(NSNotification *)notification
{
    self.sequencer.bpm = [notification.userInfo valueForKey:@"bpm"];
}

- (void) gridControllerConnected:(NSNotification *)notification
{
    [self checkForThingsOutsideGrid];
    [self updateInterfaceToMatchGridSize];
}

- (void) gridControllerNone:(NSNotification *)notification
{
    [self updateInterfaceToMatchGridSize];
}

- (void) checkForThingsOutsideGrid
{
    // Make sure all the loops etc fit within the connected grid size
    for( SequencerPage *page in self.sequencer.pages ) {
        if( page.loopStart.intValue >= self.sharedPreferences.gridWidth || page.loopEnd.intValue >= self.sharedPreferences.gridWidth ) {
            page.loopStart = [NSNumber numberWithInt:0];
            page.loopEnd = [NSNumber numberWithInt:self.sharedPreferences.gridWidth - 1];
        }
        
        if( self.currentSequencerPageState.currentStep.intValue >= self.sharedPreferences.gridWidth )
            self.currentSequencerPageState.currentStep = [page.loopEnd copy];
        if( self.currentSequencerPageState.nextStep.intValue >= self.sharedPreferences.gridWidth )
            self.currentSequencerPageState.nextStep = nil;
        if( self.currentSequencerPageState.currentPatternId.intValue >= self.sharedPreferences.gridWidth )
            self.currentSequencerPageState.currentPatternId = [NSNumber numberWithInt:0];
        if( self.currentSequencerPageState.nextPatternId.intValue >= self.sharedPreferences.gridWidth )
            self.currentSequencerPageState.nextPatternId = nil;
    }
    
    // Get the notes
    [self.managedObjectContext performBlock:^(void) {
        NSError *requestError = nil;
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step >= %u) OR (row >= %u)", self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight];
        
        NSUInteger count = [self.managedObjectContext countForFetchRequest:noteRequest error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);

        if( count > 0 && !self.notesOutsideGridAlert ) {
             self.notesOutsideGridAlert = [NSAlert alertWithMessageText:@"This song contains notes outside of the grid controller's area."
                                                          defaultButton:@"Leave notes"
                                                        alternateButton:@"Remove notes"
                                                            otherButton:nil
                                              informativeTextWithFormat:@"Would you like to remove these %lu notes?", count];
            
            [self.notesOutsideGridAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(notesOutsideGridAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        }
    }];
}

- (void) updateInterfaceToMatchGridSize
{
    [self.currentPatternSegmentedControl setSegmentCount:self.sharedPreferences.gridWidth];
    for( int i = 0; i < self.currentPatternSegmentedControl.segmentCount; i ++ ) {
        [self.currentPatternSegmentedControl setLabel:[NSString stringWithFormat:@"%i", i] forSegment:i];
        [self.currentPatternSegmentedControl setWidth:28.0 forSegment:i];
    }
    
    self.pitchesArrayController.fetchPredicate = [NSPredicate predicateWithFormat:@"inPage == %@ AND row < %u", self.currentPage, self.sharedPreferences.gridHeight];
}

- (void) editLabelAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSString *newLabel = [alert.accessoryView valueForKey:@"stringValue"];
    
    if( returnCode == NSOKButton && ![newLabel isEqualToString:@""] ) {
        
        if( newLabel.length > 100 ) // The property can't take a string longer than 100 chars
            newLabel = [newLabel substringToIndex:100];
        self.currentPage.name = newLabel;
        [self.currentPageSegmentedControl setLabel:self.currentPage.name forSegment:[self.currentPage.id intValue]];
    }
}

- (void) notesOutsideGridAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if( returnCode == NSOKButton ) {
        NSLog(@"Leave them");
        
    } else {
        NSLog(@"Remove them");
        
        // TODO remove all the notes
        
        if( ![NSThread isMainThread] ) NSLog(@"%s is NOT running on main thread", __func__);
        
        // Get the notes
        
        // Remove
    }
    
    self.notesOutsideGridAlert = nil;
}



#pragma mark - Interface actions

- (IBAction)bpmStepper:(NSStepper *)sender
{
    self.sequencer.bpm = [NSNumber numberWithFloat:roundf( self.sequencer.bpm.floatValue )];
}

- (IBAction)sequencerPlaybackControls:(NSSegmentedControl *)sender
{
    if( sender.selectedSegment == 0 )
        [self.clock stopClock];
    else
        [self.clock startClock];
}



- (IBAction) stepQuantizationPopup:(NSPopUpButton *)sender
{
    self.sequencer.stepQuantization = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction) patternQuantizationPopup:(NSPopUpButton *)sender
{
    self.sequencer.patternQuantization = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction) currentPageSegmentedControl:(NSSegmentedControl *)sender
{
    self.currentPage = [self.sequencer.pages objectAtIndex:sender.selectedSegment];
}

- (IBAction) editLabelButton:(NSButton *)sender
{
    // Make a text field, add it to an alert and then show it so you can edit the page name
    
    NSTextField *accessoryTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,200,22)];
    accessoryTextField.stringValue = self.currentPage.name;
    
    NSAlert *editLabelAlert = [NSAlert alertWithMessageText:@"Edit the label for this sequencer page."
                                                 defaultButton:@"OK"
                                               alternateButton:@"Cancel"
                                                   otherButton:nil
                                     informativeTextWithFormat:@""];
    [editLabelAlert setAccessoryView:accessoryTextField];

    [editLabelAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(editLabelAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)currentPatternSegmentedControl:(NSSegmentedControl *)sender
{
    self.currentSequencerPageState.nextPatternId = [NSNumber numberWithInteger:sender.selectedSegment];
    [sender setSelectedSegment:self.currentSequencerPageState.currentPatternId.integerValue];
}

- (IBAction)pagePlaybackControls:(NSSegmentedControl *)sender
{
    self.currentSequencerPageState.playMode = [NSNumber numberWithInteger:sender.selectedSegment];
    
    // Pause
    if( sender.selectedSegment == EatsSequencerPlayMode_Pause ) {
        self.currentSequencerPageState.nextStep = nil;
        [self.gridNavigationController updateGridView];
        
    // Forward
    } else if( sender.selectedSegment == EatsSequencerPlayMode_Forward ) {
        self.currentSequencerPageState.nextStep = nil;
        [self.gridNavigationController updateGridView];
        
    // Reverse
    } else if( sender.selectedSegment == EatsSequencerPlayMode_Reverse ) {
        self.currentSequencerPageState.nextStep = nil;
        [self.gridNavigationController updateGridView];
        
    // Random
    } else if( sender.selectedSegment == EatsSequencerPlayMode_Random ) {
        self.currentSequencerPageState.nextStep = nil;
        [self.gridNavigationController updateGridView];
    }
}


- (IBAction) scalesOpenSheetButton:(NSButton *)sender {
    if (!self.scaleGeneratorSheetController) {
        self.scaleGeneratorSheetController = [[ScaleGeneratorSheetController alloc] init];
        [self.scaleGeneratorSheetController beginSheetModalForWindow:self.documentWindow completionHandler:^(NSUInteger returnCode) {
            
            // Generate the scale
            if (returnCode == NSOKButton) {
                
                // Check what note the user entered
                NSString *noteName = self.scaleGeneratorSheetController.tonicNoteName;
                WMNote *tonicNote;
                if ( [[NSScanner scannerWithString:noteName] scanInt:nil] )
                    tonicNote = [[WMPool pool] noteWithMidiNoteNumber:noteName.intValue]; // Lookup by MIDI value if they enetered a number
                else
                    tonicNote = [[WMPool pool] noteWithShortName:noteName]; // Otherwise use the short name
                
                // If we found a note then generate the sequence
                if( tonicNote ) {
                    // Generate pitches
                    NSArray *sequenceOfNotes = [WMPool sequenceOfNotesWithRootShortName:tonicNote.shortName scaleMode:self.scaleGeneratorSheetController.scaleMode length:32];
                    
                    // Put them into the page
                    int r = 0;
                    
                    for( WMNote *note in sequenceOfNotes ) {
                        SequencerRowPitch *rowPitch = [self.currentPage.pitches objectAtIndex:r];
                        rowPitch.pitch = [NSNumber numberWithInt:note.midiNoteNumber];
                        r++;
                    }
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

- (IBAction) stepLengthPopup:(NSPopUpButton *)sender
{
    self.currentPage.stepLength = [[self.quantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
}

- (IBAction)swingPopup:(NSPopUpButton *)sender
{
    NSUInteger index = [sender indexOfSelectedItem];
    
    self.currentPage.swingType = [[self.swingArray objectAtIndex:index] valueForKey:@"type"];
    self.currentPage.swingAmount = [[self.swingArray objectAtIndex:index] valueForKey:@"amount"];
}

@end
