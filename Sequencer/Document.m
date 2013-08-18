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
//#import "EatsGridNavigationController.h" TODO
#import "EatsWMNoteValueTransformer.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

@property EatsClock                     *clock;
@property ClockTick                     *clockTick;
//@property EatsGridNavigationController  *gridNavigationController; TODO
@property ScaleGeneratorSheetController *scaleGeneratorSheetController;

@property NSMutableArray                *stepQuantizationArray;
@property NSMutableArray                *patternQuantizationArray;
@property NSArray                       *swingArray;

@property NSAlert                       *notesOutsideGridAlert;
@property NSAlert                       *clearPatternAlert;
@property BOOL                          checkedForThingsOutsideGrid;
@property uint                          indexOflastSelectedScaleMode;
@property NSString                      *lastTonicNoteName;
@property NSPoint                       pageViewFrameOrigin;

@property (nonatomic, assign) IBOutlet NSWindow *documentWindow;

@property (weak) IBOutlet KeyboardInputView     *pageView;

@property (weak) IBOutlet NSSegmentedControl    *sequencerPlaybackControls;
@property (weak) IBOutlet NSPopUpButton         *stepQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton         *patternQuantizationPopup;
@property (weak) IBOutlet NSSegmentedControl    *currentPageSegmentedControl;

@property (weak) IBOutlet NSSegmentedControl    *currentPatternSegmentedControl;
@property (weak) IBOutlet NSSegmentedControl    *pagePlaybackControls;
@property (weak) IBOutlet NSTableView           *rowPitchesTableView;
@property (weak) IBOutlet NSPopUpButton         *stepLengthPopup;
@property (weak) IBOutlet NSPopUpButton         *swingPopup;

@property (weak) IBOutlet EatsDebugGridView     *debugGridView;
@property (weak) IBOutlet NSImageView           *clockLateIndicator;

@end


@implementation Document


#pragma mark - Setters and getters

@synthesize isActive = _isActive;

- (void)setIsActive:(BOOL)isActive
{
    _isActive = isActive;
//    if(self.gridNavigationController) self.gridNavigationController.isActive = isActive; TODO
}

- (BOOL)isActive
{
    return _isActive;
}


#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        //NSLog(@"---- Init Document ----");
        
        self.isActive = NO;
        
        // Get the prefs singleton
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create the Sequencer
        self.sequencer = [[Sequencer alloc] init];
        self.sequencer.undoManager = self.undoManager;
        
        // Add dummy data for testing
        [self.sequencer addDummyData];
        
        // Create the step quantization settings TODO move this into a utils class?
        self.stepQuantizationArray = [NSMutableArray array];
        int quantizationSetting = MIN_QUANTIZATION;
        while( quantizationSetting >= MAX_QUANTIZATION ) {
            
            NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:quantizationSetting], @"quantization", nil];
            
            if( quantizationSetting == 1)
                [quantization setObject:[NSString stringWithFormat:@"1 bar"] forKey:@"label"];
            else
                [quantization setObject:[NSString stringWithFormat:@"1/%i", quantizationSetting] forKey:@"label"];
            
            [self.stepQuantizationArray insertObject:quantization atIndex:0];
            quantizationSetting = quantizationSetting / 2;
        }
        
        // Create the swing settings
        self.swingArray = [EatsSwingUtils swingArray];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSLog(@"Document deallocated OK"); // TODO: Remove this for final release
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
    
    self.pageViewFrameOrigin = self.pageView.frame.origin;
    self.pageView.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[aController window]];
    
    // Setup UI
    [self setupUI];
    
    // Create a Clock and set it up
    self.clockTick = [[ClockTick alloc] initWithSequencer:self.sequencer];
    self.clockTick.delegate = self;
    self.clockTick.ppqn = PPQN;
    self.clockTick.ticksPerMeasure = TICKS_PER_MEASURE;
    self.clockTick.midiClockPPQN = MIDI_CLOCK_PPQN;
    self.clockTick.minQuantization = MIN_QUANTIZATION;
    self.clockTick.qnPerMeasure = QN_PER_MEASURE;
    
    self.clock = [[EatsClock alloc] init];
    self.clock.delegate = self.clockTick;
    self.clock.ppqn = PPQN;
    self.clock.qnPerMeasure = QN_PER_MEASURE;
    
    // BPM
    [self updateClockBPM];
    
    // Set everything to match the model
    [self updateSequencerPageUI];
    
    // Create the gridNavigationController TODO: Bring this back
    //    self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.managedObjectContext andSequencerState:_sequencerState andQueue:_bigSerialQueue];
    //    self.gridNavigationController.delegate = self;
    //    self.gridNavigationController.isActive = self.isActive;
    
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
    
    [self updateInterfaceToMatchGridSize];
    [self checkForThingsOutsideGrid];
    
    // Start the clock right away
    self.sequencerPlaybackControls.selectedSegment = 1;
    [self.clock startClock];
}

- (void) windowWillClose:(NSNotification *)notification
{
    [self.clock stopClock];
}

+ (BOOL) autosavesInPlace
{
    return YES;
}

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    //    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    //    @throw exception;
    //    return nil;
    
    return [self.sequencer songKeyedArchiveData];
}

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    //    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    //    @throw exception;
    //    return YES;
    
    NSError *error = [self.sequencer setSongFromKeyedArchiveData:data];
    if( error ) {
        *outError = error;
        return NO;
    } else {
        return YES;
    }
}

- (void) windowDidBecomeMain:(NSNotification *)notification
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    if( documentController.lastActiveDocument != self ) {
        [documentController setActiveDocument:self];
        
        // Added this check as in theory we might not be ready TODO do we need this?
//        if( _currentPageOnMainThread )
//            [self updateUI];
    }
}

- (void) updateUI
{
    [self updateCurrentPattern];
    
    _debugGridView.needsDisplay = YES;
    
//    [self.gridNavigationController updateGridView]; TODO
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
    if( returnCode == NSOKButton ) {
//                uint patternId;
//        
        // TODO re-work this!
        // If pattern quantization is disabled
//        if( _sequencerOnMainThread.patternQuantization.intValue == 0 && _currentSequencerPageState.nextPatternId )
//            patternId = _currentSequencerPageState.nextPatternId.unsignedIntValue;
//        
//        else
//            patternId = _currentSequencerPageState.currentPatternId.unsignedIntValue;
//        
//        [Sequencer clearPattern:....];
    }
    self.clearPatternAlert = nil;
}


#pragma mark - Setup and update UI

- (void) setupUI
{
    self.clockLateIndicator.alphaValue = 0.0;
    
    self.debugGridView.delegate = self;
    self.debugGridView.needsDisplay = YES;
    
    [self.stepQuantizationPopup removeAllItems];
    [self.stepLengthPopup removeAllItems];
    
    for( NSDictionary *quantization in self.stepQuantizationArray) {
        [self.stepQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.stepLengthPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }
    
    [self setupPatternQuantizationPopup];
    
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
    
//    for(SequencerPage *page in self.sequencerOnMainThread.pages) { //TODO
//        [self.currentPageSegmentedControl setLabel:page.name forSegment:[page.id intValue]];
//    }
    
    // Table view default sort
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"row" ascending: NO];
    [self.rowPitchesTableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    self.rowPitchesTableView.delegate = self;
}

- (void) setupPatternQuantizationPopup
{
    [self.patternQuantizationPopup removeAllItems];
    
    // Create the pattern quantization settings
    self.patternQuantizationArray = [NSMutableArray array];
    int quantizationSetting = self.sharedPreferences.gridWidth;
    while ( quantizationSetting >= MAX_QUANTIZATION ) {
        
        NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:quantizationSetting], @"quantization", nil];
        
        if( quantizationSetting == 1)
            [quantization setObject:[NSString stringWithFormat:@"1 loop"] forKey:@"label"];
        else
            [quantization setObject:[NSString stringWithFormat:@"1/%i", quantizationSetting] forKey:@"label"];
        
        [self.patternQuantizationArray insertObject:quantization atIndex:0];
        quantizationSetting = quantizationSetting / 2;
    }
    
    NSDictionary *zeroQuantization = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"quantization", [NSString stringWithFormat:@"None"], @"label", nil];
    [self.patternQuantizationArray insertObject:zeroQuantization atIndex:0];
    
    // Put them in the popup
    for( NSDictionary *quantization in self.patternQuantizationArray) {
        [self.patternQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }
}

- (void) updateSequencerPageUI
{
    [self updateStepLengthPopup];
    [self updateSwingPopup];
    [self updateCurrentPattern];
    [self updatePlayMode];

    _debugGridView.needsDisplay = YES;
}

- (void) updateClockBPM
{
    self.clock.bpm = self.sequencer.bpm;
    self.clockTick.bpm = self.sequencer.bpm;
}

- (void) updateStepQuantizationPopup
{
    // TODO
//    [self.stepQuantizationPopup selectItemAtIndex:[self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
//        return [[obj valueForKey:@"quantization"] intValue] == self.sequencerOnMainThread.stepQuantization;
//    }]];
}

- (void) updatePatternQuantizationPopup
{
        // TODO
//    NSUInteger index = [self.patternQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
//        return [[obj valueForKey:@"quantization"] intValue] == self.sequencerOnMainThread.patternQuantization;
//    }];
//    
//    if( index == NSNotFound )
//        index = self.patternQuantizationPopup.itemArray.count - 1;
//    
//    [self.patternQuantizationPopup selectItemAtIndex:index];
//    
//    [self updateUI];
}

- (void) updateCurrentPattern
{
    self.currentPatternSegmentedControl.selectedSegment = [self.sequencer currentlyDisplayingPatternIdForPage:[self.sequencer currentPageId]];
    self.debugGridView.notes = [self.sequencer notesForPattern:[self.sequencer currentlyDisplayingPatternIdForPage:[self.sequencer currentPageId]] inPage:[self.sequencer currentPageId]];
}

- (void) updatePlayMode
{
    self.pagePlaybackControls.selectedSegment = [self.sequencer playModeForPage:[self.sequencer currentPageId]];
}

- (void) updateStepLengthPopup
{
        // TODO
//    [self.stepLengthPopup selectItemAtIndex:[self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
//        return [[[obj valueForKey:@"quantization"] intValue] == [self.sequencer stepLengthForPage:[self.sequencer currentPageId]]];
//    }]];
}

- (void) updateSwingPopup
{
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        if( [[obj valueForKey:@"type"] intValue] == [self.sequencer swingTypeForPage:self.sequencer.currentPageId] && [[obj valueForKey:@"amount"] intValue] == [self.sequencer swingAmountForPage:self.sequencer.currentPageId] )
            return YES;
        else
            return NO;
    }];
    [self.swingPopup selectItemAtIndex:index];
}

- (void) updatePitches
{
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:_sharedPreferences.gridHeight];
    
    for( int i = 0; i < _sharedPreferences.gridHeight; i ++ ) {
        
        int pitch = [self.sequencer pitchAtRow:i forPage:[self.sequencer currentPageId]];
        
        NSMutableDictionary *tableRow = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:i + 1], @"row",
                                        [NSNumber numberWithInt:pitch], @"pitch",
                                        nil];
        if( [self.sequencer transposeForPage:self.sequencer.currentPageId] ) {
            NSString *transposedNote;
            
            int transposedPitch = pitch + [self.sequencer transposeForPage:[self.sequencer currentPageId]];
            if( transposedPitch > 127 )
                transposedPitch = 127;
            else if( transposedPitch < 0 )
                transposedPitch = 0;
            
            if( transposedPitch > pitch )
                transposedNote = [NSString stringWithFormat:@"↑"];
            else if( transposedPitch < pitch )
                transposedNote = [NSString stringWithFormat:@"↓"];
            else
                transposedNote = [NSString stringWithFormat:@"  "];
            
            transposedNote = [NSString stringWithFormat:@"%@ %@", transposedNote, [[[WMPool pool] noteWithMidiNoteNumber:transposedPitch] shortName]];
            [tableRow setObject:transposedNote forKey:@"transposedPitch"];
        }
        
        [newArray addObject:tableRow];
    }
    
    self.currentPagePitches = newArray;
}



#pragma mark – Notifications

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
    
    [self resetPlayPositions];
}

- (void) externalClockStop:(NSNotification *)notification
{
    [self.clock stopClock];
    [self.sequencerPlaybackControls setSelectedSegment:0];
}

- (void) externalClockBPM:(NSNotification *)notification
{
    [self.sequencer setBPMWithoutRegisteringUndo:[[notification.userInfo valueForKey:@"bpm"] floatValue]];
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


#pragma mark - Private methods

- (void) resetPlayPositions
{
    if( self.clock.clockStatus != EatsClockStatus_Stopped )
        [self.clockTick clockSongStop:0];
    [self.clockTick songPositionZero];
    
    //Reset the play positions of all the active loops
    [self.sequencer resetPlayPositionsForAllPlayingPages];
    
    [self updateUI];
}

- (void) checkForThingsOutsideGrid
{
    int count = [self.sequencer checkForNotesOutsideOfGrid];
    if( count > 0 && !self.notesOutsideGridAlert ) {
//                dispatch_async(dispatch_get_main_queue(), ^(void) { TODO check if we need this
            self.notesOutsideGridAlert = [NSAlert alertWithMessageText:@"This song contains notes outside of the grid controller's area."
                                                          defaultButton:@"Leave notes"
                                                        alternateButton:@"Remove notes"
                                                            otherButton:nil
                                              informativeTextWithFormat:@"Would you like to remove these %i notes?", count];
            
            [self.notesOutsideGridAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(notesOutsideGridAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
//                });
    }
    
    [self updateUI];
}

- (void) updateInterfaceToMatchGridSize
{
    // Debug view
    self.debugGridView.gridWidth = self.sharedPreferences.gridWidth;
    self.debugGridView.gridHeight = self.sharedPreferences.gridHeight;
    self.debugGridView.needsDisplay = YES;
    
    // Pattern controls
    [self.currentPatternSegmentedControl setSegmentCount:self.sharedPreferences.gridWidth];
    for( int i = 0; i < self.currentPatternSegmentedControl.segmentCount; i ++ ) {
        [self.currentPatternSegmentedControl setLabel:[NSString stringWithFormat:@"%i", i + 1] forSegment:i];
        [self.currentPatternSegmentedControl setWidth:22.5 forSegment:i];
    }
    
    // Pitch list
    [self updatePitches];
    
    // Pattern quantization
    [self setupPatternQuantizationPopup];
    [self updatePatternQuantizationPopup];
}

- (void) editLabelAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSString *newLabel = [alert.accessoryView valueForKey:@"stringValue"];
    
    if( returnCode == NSOKButton && ![newLabel isEqualToString:@""] ) {
        
        if( newLabel.length > 100 ) // The property can't take a string longer than 100 chars
            newLabel = [newLabel substringToIndex:100];
        [self.sequencer setName:newLabel forPage:self.sequencer.currentPageId];
        [self.currentPageSegmentedControl setLabel:[self.sequencer nameForPage:[self.sequencer currentPageId]] forSegment:[self.sequencer currentPageId]];
    }
}

- (void) notesOutsideGridAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    // Leave them
    if( returnCode == NSOKButton ) {
        
    // Remove them
    } else {
        [self.sequencer removeNotesOutsideOfGrid];
    }
    
    self.notesOutsideGridAlert = nil;
}

- (void) showClockLateIndicator
{
    self.clockLateIndicator.alphaValue = 1.0;
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.3];
    [[self.clockLateIndicator animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

- (void) logDebugInfo
{
    NSLog(@"---- Debug info ----");
    NSLog(@"Grid type %i", _sharedPreferences.gridType);
    NSLog(@"Grid supports variable brightness %i", _sharedPreferences.gridSupportsVariableBrightness);
    NSLog(@"Grid width %u", _sharedPreferences.gridWidth);
    NSLog(@"Grid height %u", _sharedPreferences.gridHeight);
    NSLog(@"sequencer %@", self.sequencer);
    NSLog(@"--------------------");
}



#pragma mark – Document actions

- (void) toggleSequencerPlayback
{
    if( self.clock.clockStatus == EatsClockStatus_Stopped ) {
        [self resetPlayPositions];
        [self.clock startClock];
        self.sequencerPlaybackControls.selectedSegment = 1;
    } else {
        [self.clock stopClock];
        self.sequencerPlaybackControls.selectedSegment = 0;
    }
}

- (void) showPage:(uint)pageId from:(int)direction;
{
    // Direction can be -1 (from left), 0 (calculate automatically), or 1 (from right)
    
    if( self.sequencer.currentPageId == pageId )
        return;
    
    // Switch page with an animation
    
    self.currentPageSegmentedControl.selectedSegment = pageId;
    
    self.pageView.alphaValue = 0.0;
    
    float distanceToAnimate = 100.0;
    
    NSRect frame = self.pageView.frame;
    
    if( direction < 0 ) {
        frame.origin.x -= distanceToAnimate;
        
    } else if( direction > 0 ) {
        frame.origin.x += distanceToAnimate;
        
    } else {
        if( pageId > [self.sequencer currentPageId] )
            frame.origin.x += distanceToAnimate;
        else if ( pageId < [self.sequencer currentPageId] )
            frame.origin.x -= distanceToAnimate;
    }
    
    self.pageView.frame = frame;
    
    [self.sequencer setCurrentPageId:pageId];
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.2];
    [[self.pageView animator] setAlphaValue:1.0];
    [[self.pageView animator] setFrameOrigin:self.pageViewFrameOrigin];
    [NSAnimationContext endGrouping];
}

- (void) showPreviousPage
{
    int newPageId = self.sequencer.currentPageId - 1;
    if( newPageId < 0 )
        newPageId = kSequencerNumberOfPages - 1;
    [self showPage:newPageId from:-1];
}

- (void) showNextPage
{
    int newPageId = self.sequencer.currentPageId + 1;
    if( newPageId >= kSequencerNumberOfPages )
        newPageId = 0;
    [self showPage:newPageId from:1];
}



#pragma mark - Interface actions

- (IBAction)bpmTextField:(NSTextField *)sender
{
    //TODO
}

- (IBAction)bpmStepper:(NSStepper *)sender
{
    //TODO
}


- (IBAction)sequencerPlaybackControls:(NSSegmentedControl *)sender
{
    if( sender.selectedSegment == 0 ) {
        if( self.clock.clockStatus == EatsClockStatus_Stopped )
            [self resetPlayPositions];
        else
            [self.clock stopClock];
    } else {
        if( self.clock.clockStatus != EatsClockStatus_Stopped )
            [self resetPlayPositions];
        [self.clock startClock];
    }
}


- (IBAction) stepQuantizationPopup:(NSPopUpButton *)sender
{
    [self.sequencer setStepQuantization:[[[self.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"] intValue]];
}

- (IBAction) patternQuantizationPopup:(NSPopUpButton *)sender
{
    [self.sequencer setPatternQuantization:[[[self.patternQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"] intValue]];
}

- (IBAction) currentPageSegmentedControl:(NSSegmentedControl *)sender
{
    // Edit name
    if( sender.selectedSegment == [self.sequencer currentPageId] ) {
        // Make a text field, add it to an alert and then show it so you can edit the page name
        
        NSTextField *accessoryTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,200,22)];
        
        accessoryTextField.stringValue = [self.sequencer nameForPage:[self.sequencer currentPageId]];
        
        NSAlert *editLabelAlert = [NSAlert alertWithMessageText:@"Edit the label for this sequencer page."
                                                  defaultButton:@"OK"
                                                alternateButton:@"Cancel"
                                                    otherButton:nil
                                      informativeTextWithFormat:@""];
        [editLabelAlert setAccessoryView:accessoryTextField];
        
        [editLabelAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(editLabelAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
    // Otherwise switch page
    } else {
        [self showPage:(uint)sender.selectedSegment from:0];
    }
}

- (IBAction)currentPatternSegmentedControl:(NSSegmentedControl *)sender
{
        // TODO
//    [self setCurrentPagePattern:(int)sender.selectedSegment];
}

- (IBAction)pagePlaybackControls:(NSSegmentedControl *)sender
{
        // TODO
//    [self setCurrentPagePlayMode:(int)sender.selectedSegment];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    
    // TODO
    
    // We re-create the pitches so that it will trigger KVO
//    NSMutableOrderedSet *newPitches = [NSMutableOrderedSet orderedSetWithCapacity:_currentPageOnMainThread.pitches.count];
//    
//    for( SequencerRowPitch *rowPitch in _currentPageOnMainThread.pitches ) {
//        SequencerRowPitch *newRowPitch = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerRowPitch" inManagedObjectContext:self.managedObjectContextForMainThread];
//        newRowPitch.row = rowPitch.row;
//        newRowPitch.pitch = rowPitch.pitch;
//        [newPitches addObject:rowPitch];
//    }
//    
//    // Then modify the appropriate row
//    NSInteger rowIndex = self.rowPitchesTableView.numberOfRows - 1 - self.rowPitchesTableView.selectedRow;
//    SequencerRowPitch *rowPitch = [newPitches objectAtIndex:rowIndex];
//    rowPitch.pitch = [[_currentPagePitches objectAtIndex:rowIndex] valueForKey:@"pitch"];
//    
//    // And update the page
//    _currentPageOnMainThread.pitches = newPitches;
}

- (IBAction) scalesOpenSheetButton:(NSButton *)sender {
    if (!self.scaleGeneratorSheetController) {
        self.scaleGeneratorSheetController = [[ScaleGeneratorSheetController alloc] init];
        
        self.scaleGeneratorSheetController.indexOfLastSelectedScaleMode = self.indexOflastSelectedScaleMode;
        if( self.lastTonicNoteName )
            self.scaleGeneratorSheetController.tonicNoteName = self.lastTonicNoteName;
        
        [self.scaleGeneratorSheetController beginSheetModalForWindow:self.documentWindow completionHandler:^(NSUInteger returnCode) {
            
            NSString *noteName = self.scaleGeneratorSheetController.tonicNoteName;
            NSString *scaleMode = self.scaleGeneratorSheetController.scaleMode;
            
            // Generate the scale
            if (returnCode == NSOKButton) {
                
                self.indexOflastSelectedScaleMode = self.scaleGeneratorSheetController.indexOfLastSelectedScaleMode;
                
                // TODO (move into Sequencer?)
                
                // Check what note the user entered
                WMNote *tonicNote;
                if ( [[NSScanner scannerWithString:noteName] scanInt:nil] )
                    tonicNote = [[WMPool pool] noteWithMidiNoteNumber:noteName.intValue]; // Lookup by MIDI value if they enetered a number
                else
                    tonicNote = [[WMPool pool] noteWithShortName:noteName]; // Otherwise use the short name
                
                // If we found a note then generate the sequence
                if( tonicNote ) {
                    
                    // Generate pitches
                    NSArray *sequenceOfNotes = [WMPool sequenceOfNotesWithRootShortName:tonicNote.shortName scaleMode:scaleMode length:16];

                    // Put them into the page
                    NSMutableOrderedSet *newPitches = [NSMutableOrderedSet orderedSetWithCapacity:sequenceOfNotes.count];
                    
                    for( WMNote *note in sequenceOfNotes ) {
                        [newPitches addObject:[NSNumber numberWithInt:note.midiNoteNumber]];
                    }
                    
                    [self.sequencer setPitches:newPitches forPage:[self.sequencer currentPageId]];
                    
                    // Remember what scale was just generated
                    self.lastTonicNoteName = tonicNote.shortName;
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
    // TODO
    
//    int pageId = self.currentPageOnMainThread.id.intValue;
//    
//    SequencerPage *page = [self.sequencerOnMainThread.pages objectAtIndex:pageId];
//    page.stepLength = [[self.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
//    
//    [self childMOCChanged];
}

- (IBAction)swingPopup:(NSPopUpButton *)sender
{
        // TODO
    
//    int pageId = self.currentPageOnMainThread.id.intValue;
//    NSUInteger index = [sender indexOfSelectedItem];
//    
//    SequencerPage *page = [self.sequencerOnMainThread.pages objectAtIndex:pageId];
//    page.swingType = [[self.swingArray objectAtIndex:index] valueForKey:@"type"];
//    page.swingAmount = [[self.swingArray objectAtIndex:index] valueForKey:@"amount"];
//    
//    [self childMOCChanged];
}

- (IBAction)velocityGrooveCheckbox:(NSButton *)sender
{
    // TODO
}


- (IBAction)transposeTextField:(NSTextField *)sender
{
    // TODO
}

- (IBAction)transposeStepper:(NSStepper *)sender
{
    // TODO
}



#pragma mark - Keyboard input and cut/copy/paste delegate methods for EatsDebugGridView

- (void) cutCurrentPattern
{
    [self.sequencer pasteboardCutNotesForPattern:[self.sequencer currentlyDisplayingPatternIdForPage:[self.sequencer currentPageId]] inPage:[self.sequencer currentPageId]];
}

- (void) copyCurrentPattern
{
    [self.sequencer pasteboardCopyNotesForPattern:[self.sequencer currentlyDisplayingPatternIdForPage:[self.sequencer currentPageId]] inPage:[self.sequencer currentPageId]];
}

- (void) pasteToCurrentPattern
{
    [self.sequencer pasteboardPasteNotesForPattern:[self.sequencer currentlyDisplayingPatternIdForPage:[self.sequencer currentPageId]] inPage:[self.sequencer currentPageId]];
}

- (void) keyDownFromEatsDebugGridView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags
{
    // Clear
    // Backspace
    if( keyCode.intValue == 51 )
        [self clearPatternStartAlert];
    
    // Send the rest to the main keyboard input handling
    else
        [self keyDownFromKeyboardInputView:keyCode withModifierFlags:modifierFlags];
}



#pragma mark - Keyboard and trackpad input from KeyboardInputView

- (void) keyDownFromKeyboardInputView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags
{
    // Sequencer playback
    // Space
    if( keyCode.intValue == 49 )
       [self toggleSequencerPlayback];
    
    // BPM
    // -
    else if( keyCode.intValue == 27 )
        [self.sequencer decrementBPM];
    // +
    else if( keyCode.intValue == 24 )
        [self.sequencer incrementBPM];

    // Pages
    // F1
    else if( keyCode.intValue == 122 )
        [self showPage:0 from:0];
    // F2
    else if( keyCode.intValue == 120 )
        [self showPage:1 from:0];
    // F3
    else if( keyCode.intValue == 99 )
        [self showPage:2 from:0];
    // F4
    else if( keyCode.intValue == 118 )
        [self showPage:3 from:0];
    // F5
    else if( keyCode.intValue == 96 )
        [self showPage:4 from:0];
    // F6
    else if( keyCode.intValue == 97 )
        [self showPage:5 from:0];
    // F7
    else if( keyCode.intValue == 98 )
        [self showPage:6 from:0];
    // F8
    else if( keyCode.intValue == 100 )
        [self showPage:7 from:0];
    
    // Left
    else if( keyCode.intValue == 123 )
        [self showPreviousPage];
    // Right
    else if( keyCode.intValue == 124 )
        [self showNextPage];
    
    // Patterns
    // 1
    else if( keyCode.intValue == 18 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 10;
        else
            nextPatternId = 0;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 2
    } else if( keyCode.intValue == 19 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 11;
        else
            nextPatternId = 1;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 3
    } else if( keyCode.intValue == 20 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 12;
        else
            nextPatternId = 2;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 4
    } else if( keyCode.intValue == 21 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 13;
        else
            nextPatternId = 3;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 5
    } else if( keyCode.intValue == 23 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 14;
        else
            nextPatternId = 4;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 6
    } else if( keyCode.intValue == 22 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 15;
        else
            nextPatternId = 5;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        
    // 7
    } else if( keyCode.intValue == 26 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 6;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        }
        
    // 8
    } else if( keyCode.intValue == 28 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 7;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        }
        
    // 9
    } else if( keyCode.intValue == 25 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 8;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        }
        
    // 0
    } else if( keyCode.intValue == 29 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 9;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextPatternId:[NSNumber numberWithInt:nextPatternId] forPage:[self.sequencer currentPageId]];
        }
    
    // Play mode
    // p
    } else if( keyCode.intValue == 35 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Pause forPage:[self.sequencer currentPageId]];
    // >
    else if( keyCode.intValue == 47 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Forward forPage:[self.sequencer currentPageId]];
    // <
    else if( keyCode.intValue == 43 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Reverse forPage:[self.sequencer currentPageId]];
    // ? (without any modifier)
    else if( keyCode.intValue == 44 && modifierFlags.intValue == 256 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Random forPage:[self.sequencer currentPageId]];
    
    // Transpose
    // [
    else if( keyCode.intValue == 33 )
        [self.sequencer decrementTransposeForPage:[self.sequencer currentPageId]];
    // ]
    else if( keyCode.intValue == 30 )
        [self.sequencer incrementTransposeForPage:[self.sequencer currentPageId]];
    
    // Debug info
    // d
    else if( keyCode.intValue == 2 )
        [self logDebugInfo];
    
    // Log the rest
//    else
//        NSLog(@"keyDown code: %@ withModifierFlags: %@", keyCode, modifierFlags );
}

- (void) swipeForward
{
    [self showNextPage];
}

- (void) swipeBack
{
    [self showPreviousPage];
}

@end