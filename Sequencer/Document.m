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
#import "EatsWMNoteValueTransformer.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24

typedef enum DocumentPageAnimationDirection {
    DocumentPageAnimationDirection_Left,
    DocumentPageAnimationDirection_Right
} DocumentPageAnimationDirection;

@property EatsClock                     *clock;
@property ClockTick                     *clockTick;
@property EatsGridNavigationController  *gridNavigationController;
@property ScaleGeneratorSheetController *scaleGeneratorSheetController;

@property NSAlert                       *notesOutsideGridAlert;
@property NSAlert                       *clearPatternAlert;
@property BOOL                          checkedForThingsOutsideGrid;
@property uint                          indexOflastSelectedScaleMode;
@property NSString                      *lastTonicNoteName;
@property NSPoint                       pageViewFrameOrigin;

@property (nonatomic, assign) IBOutlet NSWindow *documentWindow;

@property (weak) IBOutlet KeyboardInputView     *pageView;

@property (weak) IBOutlet NSTextField           *bpmTextField;
@property (weak) IBOutlet NSStepper             *bpmStepper;
@property (weak) IBOutlet NSImageView           *clockLateIndicator;

@property (weak) IBOutlet NSSegmentedControl    *sequencerPlaybackControls;
@property (weak) IBOutlet NSPopUpButton         *stepQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton         *patternQuantizationPopup;
@property (weak) IBOutlet NSSegmentedControl    *currentPageSegmentedControl;


@property (weak) IBOutlet NSTextField           *channelStaticTextField;
@property (weak) IBOutlet NSSegmentedControl    *currentPatternSegmentedControl;
@property (weak) IBOutlet NSSegmentedControl    *pagePlaybackControls;
@property (weak) IBOutlet NSTableView           *rowPitchesTableView;
@property (weak) IBOutlet NSPopUpButton         *stepLengthPopup;
@property (weak) IBOutlet NSPopUpButton         *swingPopup;
@property (weak) IBOutlet NSButton              *velocityGrooveCheckbox;
@property (weak) IBOutlet NSTextField           *transposeTextField;
@property (weak) IBOutlet NSStepper             *transposeStepper;

@property (weak) IBOutlet EatsDebugGridView     *debugGridView;


@end


@implementation Document


#pragma mark - Setters and getters

@synthesize isActive = _isActive;

- (void)setIsActive:(BOOL)isActive
{
    @synchronized( self ) {
        _isActive = isActive;
    }
    
    if(self.gridNavigationController)
        self.gridNavigationController.isActive = isActive;
}

- (BOOL)isActive
{
    BOOL result;
    @synchronized( self ) {
        result = _isActive;
    }
    return result;
}


#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        self.isActive = NO;
        
        // Get the prefs singleton
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create the Sequencer
        self.sequencer = [[Sequencer alloc] init];
        self.sequencer.undoManager = self.undoManager;
        
        // Add dummy data for testing
        //[self.sequencer addDummyData];
        
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
    
    // Create the gridNavigationController TODO: Bring this back
    self.gridNavigationController = [[EatsGridNavigationController alloc] initWithSequencer:self.sequencer];
    self.gridNavigationController.delegate = self;
    self.gridNavigationController.isActive = self.isActive;
    
    // Setup UI
    [self setupUI];
    
    // Set everything to match the model
    [self updateAllNonPageSpecificInterface];
    [self updateAllPageSpecificInterface];
    
    // Window notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeMain:) name:NSWindowDidBecomeMainNotification object:[aController window]];
    
    // Grid controller notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerConnected:) name:kGridControllerConnectedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerNone:) name:kGridControllerNoneNotification object:nil];
    
    // External clock notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalClockStart:) name:kExternalClockStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalClockContinue:) name:kExternalClockContinueNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalClockZero:) name:kExternalClockZeroNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalClockStop:) name:kExternalClockStopNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalClockBPM:) name:kExternalClockBPMNotification object:nil];
    
    // Sequencer song notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songBPMDidChange:) name:kSequencerSongBPMDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songStepQuantizationDidChange:) name:kSequencerSongStepQuantizationDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songPatternQuantizationDidChange:) name:kSequencerSongPatternQuantizationDidChangeNotification object:self.sequencer];
    
    // Sequencer page notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageNameDidChange:) name:kSequencerPageNameDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageStepLengthDidChange:) name:kSequencerPageStepLengthDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageSwingDidChange:) name:kSequencerPageSwingDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageVelocityGrooveDidChange:) name:kSequencerPageVelocityGrooveDidChangeNotification object:self.sequencer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageTransposeDidChange:) name:kSequencerPageTransposeDidChangeNotification object:self.sequencer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pagePitchesDidChange:) name:kSequencerPagePitchesDidChangeNotification object:self.sequencer];
    
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
    
    // Match the grid (even if it's the default there's stuff in here that needs to get called)
    [self updateInterfaceToMatchGridSize];
    
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
        
//        [self.gridNavigationController updateGridView]; TODO
    }
    
    // Doing this here rather than in didLoad because it can cause the alert to detach from the window if we create it too early
    if( !self.checkedForThingsOutsideGrid ) {
        [self checkForThingsOutsideGrid];
        self.checkedForThingsOutsideGrid = YES;
    }
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
        [self.sequencer clearNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    }
    self.clearPatternAlert = nil;
}


#pragma mark - Setup UI

- (void) setupUI
{
    self.pageViewFrameOrigin = self.pageView.frame.origin;
    self.pageView.delegate = self;
    
    self.clockLateIndicator.alphaValue = 0.0;
    
    self.debugGridView.delegate = self;
    
    // Setup step quantization popup
    [self.stepQuantizationPopup removeAllItems];
    [self.stepLengthPopup removeAllItems];
    for( NSDictionary *quantization in self.sequencer.stepQuantizationArray) {
        [self.stepQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.stepLengthPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }
    
    [self setupPatternQuantizationPopup];
    
    // Add items to swing popup with separators between swing types
    [self.swingPopup removeAllItems];
    for( NSDictionary *swing in self.sequencer.swingArray) {
        if( [[swing valueForKey:@"label"] isEqualTo:@"-"])
            [self.swingPopup.menu addItem: [NSMenuItem separatorItem]];
        else
            [self.swingPopup addItemWithTitle:[swing valueForKey:@"label"]];
    }
    
    // Set page names
    for(int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        [self.currentPageSegmentedControl setLabel:[self.sequencer nameForPage:pageId] forSegment:pageId];
    }
    
    // Table view default sort
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"row" ascending: NO];
    [self.rowPitchesTableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    self.rowPitchesTableView.delegate = self;
}

- (void) setupPatternQuantizationPopup
{
    [self.patternQuantizationPopup removeAllItems];
    for( NSDictionary *quantization in self.sequencer.patternQuantizationArray) {
        [self.patternQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }
}



#pragma mark - Private methods

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

- (void) resetPlayPositions
{
    if( self.clock.clockStatus != EatsClockStatus_Stopped )
        [self.clockTick clockSongStop:0];
    [self.clockTick songPositionZero];
    
    // Reset the play positions of all the active loops
    [self.sequencer resetPlayPositionsForAllPlayingPages];
}

- (void) checkForThingsOutsideGrid
{
    if( ![NSThread isMainThread] )
        NSLog(@"WARNING: Should be on main thread"); // TODO
    NSUInteger count = [self.sequencer checkForNotesOutsideOfGrid];
    if( count > 0 && !self.notesOutsideGridAlert ) {
        //                dispatch_async(dispatch_get_main_queue(), ^(void) { TODO check if we need this
        self.notesOutsideGridAlert = [NSAlert alertWithMessageText:@"This song contains notes outside of the grid controller's area."
                                                     defaultButton:@"Leave notes"
                                                   alternateButton:@"Remove notes"
                                                       otherButton:nil
                                         informativeTextWithFormat:@"Would you like to remove these %li notes?", (unsigned long)count];
        
        [self.notesOutsideGridAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(notesOutsideGridAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        //                });
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

- (void) logDebugInfo
{
    NSLog(@"---- Debug info ----");
    NSLog(@"Source: %@", self.sharedPreferences.midiClockSourceName);
    NSLog(@"Grid type: %i", self.sharedPreferences.gridType);
    NSLog(@"Grid supports variable brightness: %i", self.sharedPreferences.gridSupportsVariableBrightness);
    NSLog(@"Grid width: %u", self.sharedPreferences.gridWidth);
    NSLog(@"Grid height: %u", self.sharedPreferences.gridHeight);
    NSArray *sequencerDebugInfo = [[self.sequencer debugInfo] componentsSeparatedByString:@"\r"];
    for( NSString *line in sequencerDebugInfo )
        NSLog(@"%@", line);
    NSLog(@"--------------------");
}



#pragma mark – Notifications

// Grid controller notifications
- (void) gridControllerConnected:(NSNotification *)notification
{
    [self checkForThingsOutsideGrid];
    [self updateInterfaceToMatchGridSize];
}

- (void) gridControllerNone:(NSNotification *)notification
{
    [self updateInterfaceToMatchGridSize];
}

// External clock notifications
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
    float newBPM = [[notification.userInfo valueForKey:@"bpm"] floatValue];
    
    if( newBPM > SEQUENCER_SONG_BPM_MAX )
        newBPM = SEQUENCER_SONG_BPM_MAX;
    else if( newBPM < SEQUENCER_SONG_BPM_MIN )
        newBPM = SEQUENCER_SONG_BPM_MIN;
    
    [self.sequencer setBPMWithoutRegisteringUndo:newBPM];
}


// Sequencer song notifications
- (void) songBPMDidChange:(NSNotification *)notification
{
    [self updateBPM];
}

- (void) songStepQuantizationDidChange:(NSNotification *)notification
{
    [self updateStepQuantizationPopup];
}

- (void) songPatternQuantizationDidChange:(NSNotification *)notification
{
    [self updatePatternQuantizationPopup];
}

// Sequencer page notifications
- (void) pageNameDidChange:(NSNotification *)notification
{
    [self updateNameForPage:[[notification.userInfo valueForKey:@"pageId"] unsignedIntValue]];
}

- (void) pageStepLengthDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
       [self updateStepLengthPopup];
}

- (void) pageSwingDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updateSwingPopup];
}

- (void) pageVelocityGrooveDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updateVelocityGroove];
}

- (void) pageTransposeDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updateTranspose];
        [self updatePitches];
    }
}

- (void) pagePitchesDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updatePitches];
}

- (void) pagePatternNotesDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPattern:notification] )
        [self updatePatternNotes];
}

- (void) noteLengthDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPattern:notification] )
        [self updatePatternNotes];
}

// Sequencer state notifications
- (void) stateCurrentPageDidChangeLeft:(NSNotification *)notification
{
    [self updatePageFromDirection:DocumentPageAnimationDirection_Left];
}

- (void) stateCurrentPageDidChangeRight:(NSNotification *)notification
{
    [self updatePageFromDirection:DocumentPageAnimationDirection_Right];
}

// Sequencer page state notifications
- (void) pageStateCurrentPatternIdDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updatePatternNotes];
        [self updateCurrentPattern];
    }
}

- (void) pageStateNextPatternIdDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updateCurrentPattern];
    }
}

- (void) pageStateCurrentStepDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updatePatternNotes];
}

- (void) pageStateNextStepDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] )
        [self updatePatternNotes];
}

- (void) pageStatePlayModeDidChange:(NSNotification *)notification
{
    if( [self.sequencer isNotificationFromCurrentPage:notification] ) {
        [self updatePlayMode];
        [self updatePatternNotes];
    }
}


#pragma mark - Interface updates

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
    [self.sequencer updatePatternQuantizationSettings];
    [self setupPatternQuantizationPopup];
    [self updatePatternQuantizationPopup];
}

- (void) updateAllNonPageSpecificInterface
{
    [self updateBPM];
    [self updateStepQuantizationPopup];
    [self updatePatternQuantizationPopup];
}

- (void) updateAllPageSpecificInterface
{
    [self updateCurrentPattern];
    [self updatePatternNotes];
    [self updateChannel];
    [self updatePitches];
    [self updatePlayMode];
    [self updateStepLengthPopup];
    [self updateSwingPopup];
    [self updateVelocityGroove];
    [self updateTranspose];
}

- (void) updateBPM
{
    self.clock.bpm = self.sequencer.bpm;
    self.clockTick.bpm = self.sequencer.bpm;
    self.bpmTextField.floatValue = self.sequencer.bpm;
    self.bpmStepper.floatValue = self.sequencer.bpm;
}

- (void) showClockLateIndicator
{
    self.clockLateIndicator.alphaValue = 1.0;
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.3];
    [[self.clockLateIndicator animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

- (void) updateStepQuantizationPopup
{
    [self.stepQuantizationPopup selectItemAtIndex:[self.sequencer.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == [self.sequencer stepQuantization] );
        return result;
    }]];
}

- (void) updatePatternQuantizationPopup
{
    NSUInteger index = [self.sequencer.patternQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == [self.sequencer patternQuantization] );
        return result;
    }];

    if( index == NSNotFound )
        index = self.patternQuantizationPopup.itemArray.count - 1;

    [self.patternQuantizationPopup selectItemAtIndex:index];
}

- (void) updatePageFromDirection:(DocumentPageAnimationDirection)direction;
{
    // Switch page with an animation
    // Direction can be -1 (from left), 0 (calculate automatically), or 1 (from right)
    
    self.currentPageSegmentedControl.selectedSegment = self.sequencer.currentPageId;
    
    self.pageView.alphaValue = 0.0;
    
    float distanceToAnimate = 100.0;
    
    NSRect frame = self.pageView.frame;
    
    if( direction == DocumentPageAnimationDirection_Left ) {
        frame.origin.x -= distanceToAnimate;
        
    } else if( direction == DocumentPageAnimationDirection_Right ) {
        frame.origin.x += distanceToAnimate;
        
    }
    
    self.pageView.frame = frame;
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.2];
    [[self.pageView animator] setAlphaValue:1.0];
    [[self.pageView animator] setFrameOrigin:self.pageViewFrameOrigin];
    [NSAnimationContext endGrouping];
    
    [self updateAllPageSpecificInterface];
}

- (void) updateAllPageNames
{
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        [self.currentPageSegmentedControl setLabel:[self.sequencer nameForPage:pageId] forSegment:pageId];
    }
}

- (void) updateNameForPage:(uint)pageId
{
    [self.currentPageSegmentedControl setLabel:[self.sequencer nameForPage:pageId] forSegment:pageId];
}

- (void) updateChannel
{
    self.channelStaticTextField.stringValue = [NSString stringWithFormat:@"Channel %i", [self.sequencer channelForPage:self.sequencer.currentPageId]];
}

- (void) updateCurrentPattern
{
    self.currentPatternSegmentedControl.selectedSegment = [self.sequencer currentPatternIdForPage:self.sequencer.currentPageId];
    [self updatePatternNotes];
}

- (void) updatePatternNotes
{
    self.debugGridView.notes = [self.sequencer notesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
    if( [self.sequencer playModeForPage:self.sequencer.currentPageId] == EatsSequencerPlayMode_Reverse )
        self.debugGridView.drawNotesForReverse = YES;
    else
        self.debugGridView.drawNotesForReverse = NO;
    self.debugGridView.currentStep = [self.sequencer currentStepForPage:self.sequencer.currentPageId];
    self.debugGridView.nextStep = [self.sequencer nextStepForPage:self.sequencer.currentPageId];
    self.debugGridView.needsDisplay = YES;
}

- (void) updatePitches
{
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.sharedPreferences.gridHeight];
    
    for( int i = 0; i < self.sharedPreferences.gridHeight; i ++ ) {
        
        int pitch = [self.sequencer pitchAtRow:i forPage:self.sequencer.currentPageId];
        
        NSMutableDictionary *tableRow = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:i + 1], @"row",
                                         [NSNumber numberWithInt:pitch], @"pitch",
                                         nil];
        if( [self.sequencer transposeForPage:self.sequencer.currentPageId] ) {
            NSString *transposedNote;
            
            int transposedPitch = pitch + [self.sequencer transposeForPage:self.sequencer.currentPageId];
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

- (void) updatePlayMode
{
    self.pagePlaybackControls.selectedSegment = [self.sequencer playModeForPage:self.sequencer.currentPageId];
}

- (void) updateStepLengthPopup
{
    [self.stepLengthPopup selectItemAtIndex:[self.sequencer.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == [self.sequencer stepLengthForPage:self.sequencer.currentPageId] );
        return result;
    }]];
}

- (void) updateSwingPopup
{
    NSUInteger index = [self.sequencer.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"type"] intValue] == [self.sequencer swingTypeForPage:self.sequencer.currentPageId]
                       && [[obj valueForKey:@"amount"] intValue] == [self.sequencer swingAmountForPage:self.sequencer.currentPageId] );
        return result;
    }];
    [self.swingPopup selectItemAtIndex:index];
}

- (void) updateVelocityGroove
{
    self.velocityGrooveCheckbox.state = [self.sequencer velocityGrooveForPage:self.sequencer.currentPageId];
}

- (void) updateTranspose
{
    self.transposeTextField.intValue = [self.sequencer transposeForPage:self.sequencer.currentPageId];
    self.transposeStepper.intValue = [self.sequencer transposeForPage:self.sequencer.currentPageId];
}



#pragma mark - Interface actions

- (IBAction) bpmTextField:(NSTextField *)sender
{
    [self.sequencer setBPM:sender.floatValue];
}

- (IBAction) bpmStepper:(NSStepper *)sender
{
    if( sender.floatValue > self.sequencer.bpm )
       [self.sequencer incrementBPM];
    else if( sender.floatValue < self.sequencer.bpm )
        [self.sequencer decrementBPM];
}

- (IBAction) sequencerPlaybackControls:(NSSegmentedControl *)sender
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
    [self.sequencer setStepQuantization:[[[self.sequencer.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"] intValue]];
}

- (IBAction) patternQuantizationPopup:(NSPopUpButton *)sender
{
    [self.sequencer setPatternQuantization:[[[self.sequencer.patternQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"] intValue]];
}

- (IBAction) currentPageSegmentedControl:(NSSegmentedControl *)sender
{
    // Edit name
    if( sender.selectedSegment == self.sequencer.currentPageId ) {
        // Make a text field, add it to an alert and then show it so you can edit the page name
        
        NSTextField *accessoryTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,200,22)];
        
        accessoryTextField.stringValue = [self.sequencer nameForPage:self.sequencer.currentPageId];
        
        NSAlert *editLabelAlert = [NSAlert alertWithMessageText:@"Edit the label for this sequencer page."
                                                  defaultButton:@"OK"
                                                alternateButton:@"Cancel"
                                                    otherButton:nil
                                      informativeTextWithFormat:@""];
        [editLabelAlert setAccessoryView:accessoryTextField];
        
        [editLabelAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(editLabelAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
    // Otherwise switch page
    } else {
        [self.sequencer setCurrentPageId:(int)sender.selectedSegment];
    }
}

- (void) editLabelAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSString *newLabel = [alert.accessoryView valueForKey:@"stringValue"];
    
    if( returnCode == NSOKButton && ![newLabel isEqualToString:@""] ) {
        
        if( newLabel.length > 100 ) // Don't allow a string longer than 100 chars
            newLabel = [newLabel substringToIndex:100];
        [self.sequencer setName:newLabel forPage:self.sequencer.currentPageId];
    }
}


- (IBAction) currentPatternSegmentedControl:(NSSegmentedControl *)sender
{
    [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInteger:sender.selectedSegment] forPage:self.sequencer.currentPageId];
}

- (void) controlTextDidEndEditing:(NSNotification *)obj
{
    NSInteger rowIndex = self.rowPitchesTableView.numberOfRows - 1 - self.rowPitchesTableView.selectedRow;
    [self.sequencer setPitch:[[[_currentPagePitches objectAtIndex:rowIndex] valueForKey:@"pitch"] intValue] atRow:(uint)rowIndex forPage:self.sequencer.currentPageId];
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
                    NSMutableArray *newPitches = [NSMutableArray arrayWithCapacity:sequenceOfNotes.count];
                    
                    for( WMNote *note in sequenceOfNotes ) {
                        [newPitches addObject:[NSNumber numberWithInt:note.midiNoteNumber]];
                    }
                    
                    [self.sequencer setPitches:newPitches forPage:self.sequencer.currentPageId];
                    
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

- (IBAction) pagePlaybackControls:(NSSegmentedControl *)sender
{
    [self.sequencer setPlayMode:(int)sender.selectedSegment forPage:self.sequencer.currentPageId];
}

- (IBAction) stepLengthPopup:(NSPopUpButton *)sender
{
    NSDictionary *stepQuantization = [self.sequencer.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]];
    [self.sequencer setStepLength:[[stepQuantization valueForKey:@"quantization"] intValue] forPage:self.sequencer.currentPageId];
}

- (IBAction)swingPopup:(NSPopUpButton *)sender
{
    NSDictionary *swing = [self.sequencer.swingArray objectAtIndex:[sender indexOfSelectedItem]];
    [self.sequencer setSwingType:[[swing valueForKey:@"type"] intValue] andSwingAmount:[[swing valueForKey:@"amount"] intValue] forPage:self.sequencer.currentPageId];
}

- (IBAction)velocityGrooveCheckbox:(NSButton *)sender
{
    [self.sequencer setVelocityGroove:sender.state forPage:self.sequencer.currentPageId];
}


- (IBAction)transposeTextField:(NSTextField *)sender
{
    [self.sequencer setTranspose:sender.intValue forPage:self.sequencer.currentPageId];
}

- (IBAction)transposeStepper:(NSStepper *)sender
{
    [self.sequencer setTranspose:sender.intValue forPage:self.sequencer.currentPageId];
}



#pragma mark - Keyboard input and cut/copy/paste delegate methods for EatsDebugGridView

- (void) cutCurrentPattern
{
    [self.sequencer pasteboardCutNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
}

- (void) copyCurrentPattern
{
    [self.sequencer pasteboardCopyNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
}

- (void) pasteToCurrentPattern
{
    [self.sequencer pasteboardPasteNotesForPattern:[self.sequencer currentPatternIdForPage:self.sequencer.currentPageId] inPage:self.sequencer.currentPageId];
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
        [self.sequencer setCurrentPageId:0];
    // F2
    else if( keyCode.intValue == 120 )
        [self.sequencer setCurrentPageId:1];
    // F3
    else if( keyCode.intValue == 99 )
        [self.sequencer setCurrentPageId:2];
    // F4
    else if( keyCode.intValue == 118 )
        [self.sequencer setCurrentPageId:3];
    // F5
    else if( keyCode.intValue == 96 )
        [self.sequencer setCurrentPageId:4];
    // F6
    else if( keyCode.intValue == 97 )
        [self.sequencer setCurrentPageId:5];
    // F7
    else if( keyCode.intValue == 98 )
        [self.sequencer setCurrentPageId:6];
    // F8
    else if( keyCode.intValue == 100 )
        [self.sequencer setCurrentPageId:7];
    
    // Left
    else if( keyCode.intValue == 123 )
        [self.sequencer decrementCurrentPageId];
    // Right
    else if( keyCode.intValue == 124 )
        [self.sequencer incrementCurrentPageId];
    
    // Patterns
    // 1
    else if( keyCode.intValue == 18 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 10;
        else
            nextPatternId = 0;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 2
    } else if( keyCode.intValue == 19 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 11;
        else
            nextPatternId = 1;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 3
    } else if( keyCode.intValue == 20 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 12;
        else
            nextPatternId = 2;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 4
    } else if( keyCode.intValue == 21 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 13;
        else
            nextPatternId = 3;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 5
    } else if( keyCode.intValue == 23 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 14;
        else
            nextPatternId = 4;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 6
    } else if( keyCode.intValue == 22 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 15;
        else
            nextPatternId = 5;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
        else
            [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        
    // 7
    } else if( keyCode.intValue == 26 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 6;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        }
        
    // 8
    } else if( keyCode.intValue == 28 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 7;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        }
        
    // 9
    } else if( keyCode.intValue == 25 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 8;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        }
        
    // 0
    } else if( keyCode.intValue == 29 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 9;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self.sequencer setNextOrCurrentPatternIdForAllPages:[NSNumber numberWithInt:nextPatternId]];
            else
                [self.sequencer setNextOrCurrentPatternId:[NSNumber numberWithInt:nextPatternId] forPage:self.sequencer.currentPageId];
        }
    
    // Play mode
    // p
    } else if( keyCode.intValue == 35 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Pause forPage:self.sequencer.currentPageId];
    // >
    else if( keyCode.intValue == 47 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Forward forPage:self.sequencer.currentPageId];
    // <
    else if( keyCode.intValue == 43 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Reverse forPage:self.sequencer.currentPageId];
    // ? (without any modifier)
    else if( keyCode.intValue == 44 && modifierFlags.intValue == 256 )
        [self.sequencer setPlayMode:EatsSequencerPlayMode_Random forPage:self.sequencer.currentPageId];
    
    // Transpose
    // [
    else if( keyCode.intValue == 33 )
        [self.sequencer decrementTransposeForPage:self.sequencer.currentPageId];
    // ]
    else if( keyCode.intValue == 30 )
        [self.sequencer incrementTransposeForPage:self.sequencer.currentPageId];
    
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
    [self.sequencer incrementCurrentPageId];
}

- (void) swipeBack
{
    [self.sequencer decrementCurrentPageId];
}

@end