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
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

#define SEQUENCER_PAGES 8

#define SEQUENCER_NOTES_DATA_PASTEBOARD_TYPE @"com.MarkEats.Sequencer.SequencerNotesData";

@property BOOL                          setupComplete;

@property EatsClock                     *clock;
@property ClockTick                     *clockTick;
@property EatsGridNavigationController  *gridNavigationController;
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
@property (weak) IBOutlet NSObjectController    *pageObjectController;

@property (weak) IBOutlet KeyboardInputView *pageView;

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
@synthesize currentPageOnMainThread = _currentPageOnMainThread;

- (void)setIsActive:(BOOL)isActive
{
    _isActive = isActive;
    if(self.gridNavigationController) self.gridNavigationController.isActive = isActive;
}

- (BOOL)isActive
{
    return _isActive;
}

- (void) setCurrentPageOnMainThread:(SequencerPage *)currentPageOnMainThread
{
    
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"playMode"];
    
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"stepLength"];
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"swing"];
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"transpose"];
    
    __block NSNumber *pageId;

    pageId = currentPageOnMainThread.id;
    
    _currentPageOnMainThread = currentPageOnMainThread;
    _currentSequencerPageState = [_sequencerState.pageStates objectAtIndex:pageId.unsignedIntegerValue];
    
    [self.currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentSequencerPageState addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self.currentPageOnMainThread addObserver:self forKeyPath:@"stepLength" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPageOnMainThread addObserver:self forKeyPath:@"swing" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPageOnMainThread addObserver:self forKeyPath:@"transpose" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self updatePitches];
    self.pageObjectController.fetchPredicate = [NSPredicate predicateWithFormat:@"self.id == %@", pageId];
    
    [self updateSequencerPageUI];
    
}

- (SequencerPage *) currentPageOnMainThread
{
    return _currentPageOnMainThread;
}



#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        //NSLog(@"---- Init Document ----");
        
        // Create the serial queue
        _bigSerialQueue = dispatch_queue_create("com.MarkEatsSequencer.BigQueue", NULL);
        
        self.isActive = NO;
        
        // Get the prefs singleton
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create the SequencerState
        _sequencerState = [[SequencerState alloc] init];
        [_sequencerState createPageStates:SEQUENCER_PAGES];
        
        // Create the step quantization settings
        self.stepQuantizationArray = [NSMutableArray array];
        int quantizationSetting = MIN_QUANTIZATION;
        while ( quantizationSetting >= MAX_QUANTIZATION ) {
            
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
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"playMode"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"bpm"];
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"stepQuantization"];
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"patternQuantization"];
    
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"stepLength"];
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"swing"];
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"transpose"];
    
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
    
    self.managedObjectContextForMainThread = self.managedObjectContext;
    
    // Hacky way to get an autosave to generate an NSPersistentStore.
    // Code snippet from http://stackoverflow.com/questions/14257287/how-to-force-creation-of-default-persistentstore-autosave-in-nspersistentdocumen
    [self updateChangeCount:NSChangeDone];
    [self autosaveDocumentWithDelegate:self didAutosaveSelector:@selector(document:didAutosave:contextInfo:) contextInfo:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[aController window]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidBecomeKey:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[aController window]];
}

// Called by the autosave operation started in awakeFromNib.
// Code snippet from http://stackoverflow.com/questions/14257287/how-to-force-creation-of-default-persistentstore-autosave-in-nspersistentdocumen
- (void)document:(NSDocument *)document didAutosave:(BOOL)didAutosaveSuccessfully contextInfo:(void *)contextInfo
{
    [self updateChangeCount:NSChangeUndone];
    
    if( !self.setupComplete )
        [self completeSetupOncePersistentStoreIsReady];
}

-(BOOL) configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error
{
    NSMutableDictionary *newOptions = [NSMutableDictionary dictionaryWithDictionary:storeOptions];
    [newOptions setValue:@"YES" forKey:NSMigratePersistentStoresAutomaticallyOption];
    [newOptions setValue:@"YES" forKey:NSInferMappingModelAutomaticallyOption]; // Set this to NO if we want to use a mapping model
    
    return [super configurePersistentStoreCoordinatorForURL:url ofType:fileType modelConfiguration:configuration storeOptions:newOptions error:error];
}

- (void) completeSetupOncePersistentStoreIsReady
{
    self.setupComplete = YES;
    
    // How this works:
    // This document's MOC is the parent and has a private queue. It's used across the app
    // There is a child MOC with a main queue type that is used with bindings etc.
    // There is another child MOC which is reserved only for use on the tickQueue and is only used for reading data – just for when we need to know what to play
    // Method below are used for keeping the MOCs in sync (parentMOCSaved: and childMOCChanged)
    
    NSUndoManager *undoManager = self.managedObjectContext.undoManager;
    
    // Replace the NSPersistentDocument's MOC with a new one that has a PrivateQueue and can be used as a parent
    NSManagedObjectContext *parentMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [parentMOC performBlockAndWait:^(void) {
        parentMOC.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
    }];
    self.managedObjectContext = parentMOC;
    
    // Create a child MOC for use on the main thead in bindings etc
    self.managedObjectContextForMainThread = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContextForMainThread.parentContext = self.managedObjectContext;
    self.managedObjectContextForMainThread.undoManager = undoManager;
    
    // Create a child MOC for use on the tickQueue
    self.managedObjectContextForTickQueue = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.managedObjectContextForTickQueue.parentContext = self.managedObjectContext;
    
    // Register for MOC notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(parentMOCSaved:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.managedObjectContext];
    
    
    
    // Setup the Core Data object
    NSError *requestError = nil;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
    NSArray *matches = [self.managedObjectContextForMainThread executeFetchRequest:request error:&requestError];
    
    if( requestError )
        NSLog(@"Request error: %@", requestError);
    
    if( [matches count] ) {
        // Get an existing Sequencer
        self.sequencerOnMainThread = [matches lastObject];
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            // Get the sequencer for background thread stuff
            NSError *requestError = nil;
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
            NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);
            
            self.sequencer = [matches lastObject];
        }];
        
    } else {
        // Create initial structure
        [self.managedObjectContextForMainThread processPendingChanges];
        [self.managedObjectContextForMainThread.undoManager disableUndoRegistration];
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            self.sequencer = [Sequencer sequencerWithPages:SEQUENCER_PAGES inManagedObjectContext:self.managedObjectContext];
            
            // Add dummy data (can be useful for testing, just adds 16 random notes)
            //[Sequencer addDummyDataToSequencer:self.sequencer inManagedObjectContext:self.managedObjectContext];
            
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
        [self.managedObjectContextForMainThread processPendingChanges];
        [self.managedObjectContextForMainThread.undoManager enableUndoRegistration];
        
        // Get the sequencer for main thread stuff
        NSError *requestError = nil;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
        NSArray *matches = [self.managedObjectContextForMainThread executeFetchRequest:request error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
        
        self.sequencerOnMainThread = [matches lastObject];
        
        // TODO Remove this once confident that creation bugs are all fixed
        if( [[[self.sequencerOnMainThread.pages objectAtIndex:0] pitches] count] == 0 || [[[self.sequencerOnMainThread.pages objectAtIndex:0] patterns] count] == 0 )
            NSLog(@"WARNING: Page 0 has no pitches or patterns");
    }
    
    // Setup the SequencerState
    for( SequencerPage *page in self.sequencerOnMainThread.pages ) {
        [[_sequencerState.pageStates objectAtIndex:page.id.unsignedIntegerValue] setCurrentStep:[page.loopEnd copy]];
    }
    
    // Setup UI
    [self setupUI];
    
    // Set the current page to the first one
    self.currentPageOnMainThread = [self.sequencerOnMainThread.pages objectAtIndex:0];
    
    // Create a Clock and set it up
    self.clockTick = [[ClockTick alloc] initWithManagedObjectContext:self.managedObjectContextForTickQueue andSequencerState:self.sequencerState];
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
    
    // KVO
    [self.sequencerOnMainThread addObserver:self forKeyPath:@"bpm" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencerOnMainThread addObserver:self forKeyPath:@"stepQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    [self.sequencerOnMainThread addObserver:self forKeyPath:@"patternQuantization" options:NSKeyValueObservingOptionNew context:NULL];
    // Seems odd to comment these out as you would think that would throw an error when setCurrentPage is called... but it works?!
    //[self.currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    //[self.currentSequencerPageState addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    //[self.currentPageOnMainThread addObserver:self forKeyPath:@"stepLength" options:NSKeyValueObservingOptionNew context:NULL];
    //[self.currentPageOnMainThread addObserver:self forKeyPath:@"swing" options:NSKeyValueObservingOptionNew context:NULL];
    //[self.currentPageOnMainThread addObserver:self forKeyPath:@"transpose" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Create the gridNavigationController
    self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.managedObjectContext andSequencerState:_sequencerState andQueue:_bigSerialQueue];
    self.gridNavigationController.delegate = self;
    self.gridNavigationController.isActive = self.isActive;
    
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

- (void) windowDidBecomeMain:(NSNotification *)notification
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    if( documentController.lastActiveDocument != self ) {
        [documentController setActiveDocument:self];
        
        // Added this check as in theory we might not be ready
        if( _currentPageOnMainThread )
            [self updateUI];
    }
}

- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
    // Commented this out as it seems that just checking when a grid controller is connected should be enough?
//    if( !self.checkedForThingsOutsideGrid ) {
//        self.checkedForThingsOutsideGrid = YES;
//        [self checkForThingsOutsideGrid];
//    }
}

- (void) updateUI
{
    [self updateCurrentPattern];
    
    _debugGridView.needsDisplay = YES;
    
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
    if( returnCode == NSOKButton ) {
                uint patternId;
        
        // If pattern quantization is disabled
        if( _sequencerOnMainThread.patternQuantization.intValue == 0 && _currentSequencerPageState.nextPatternId )
            patternId = _currentSequencerPageState.nextPatternId.unsignedIntValue;
        
        else
            patternId = _currentSequencerPageState.currentPatternId.unsignedIntValue;
        
        [self clearPattern:[NSNumber numberWithInt:patternId] inPage:_currentPageOnMainThread.id];
    }
    self.clearPatternAlert = nil;
}


#pragma mark - Setup and update UI

- (void) setupUI
{
    self.clockLateIndicator.alphaValue = 0.0;
    
    self.debugGridView.delegate = self;
    self.debugGridView.sequencerState = self.sequencerState;
    self.debugGridView.pasteboardType = SEQUENCER_NOTES_DATA_PASTEBOARD_TYPE;
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
    
    for(SequencerPage *page in self.sequencerOnMainThread.pages) {
        [self.currentPageSegmentedControl setLabel:page.name forSegment:[page.id intValue]];
    }
    
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
    self.clock.bpm = self.sequencerOnMainThread.bpm.floatValue;
    self.clockTick.bpm = self.sequencerOnMainThread.bpm.floatValue;
}

- (void) updateStepQuantizationPopup
{
    [self.stepQuantizationPopup selectItemAtIndex:[self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencerOnMainThread.stepQuantization];
    }]];
}

- (void) updatePatternQuantizationPopup
{
    NSUInteger index = [self.patternQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencerOnMainThread.patternQuantization];
    }];
    
    if( index == NSNotFound )
        index = self.patternQuantizationPopup.itemArray.count - 1;
    
    [self.patternQuantizationPopup selectItemAtIndex:index];
    
    if( [[[self.patternQuantizationArray objectAtIndex:index] valueForKey:@"quantization"] intValue] == 0 )
        self.debugGridView.patternQuantizationOn = NO;
    else
        self.debugGridView.patternQuantizationOn = YES;
    
}

- (void) updateCurrentPattern
{
    BOOL patternQuantizationOn = NO;
    
    if( self.sequencerOnMainThread.patternQuantization.unsignedIntValue > 0 )
        patternQuantizationOn = YES;
    
    // If pattern quantization is disabled
    if( !patternQuantizationOn && _currentSequencerPageState.nextPatternId ) {
        self.currentPatternSegmentedControl.selectedSegment = _currentSequencerPageState.nextPatternId.intValue;
        self.debugGridView.currentPattern = [_currentPageOnMainThread.patterns objectAtIndex:_currentSequencerPageState.nextPatternId.intValue];
        
    } else {
        self.currentPatternSegmentedControl.selectedSegment = _currentSequencerPageState.currentPatternId.intValue;
        self.debugGridView.currentPattern = [_currentPageOnMainThread.patterns objectAtIndex:_currentSequencerPageState.currentPatternId.intValue];
    }
}

- (void) updatePlayMode
{
    self.pagePlaybackControls.selectedSegment = _currentSequencerPageState.playMode.integerValue;
}

- (void) updateStepLengthPopup
{
    [self.stepLengthPopup selectItemAtIndex:[self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.currentPageOnMainThread.stepLength];
    }]];
}

- (void) updateSwingPopup
{
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        if( [[obj valueForKey:@"type"] isEqualTo:self.currentPageOnMainThread.swingType] && [[obj valueForKey:@"amount"] isEqualTo:self.currentPageOnMainThread.swingAmount] )
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
    
    if ( object == self.sequencerOnMainThread && [keyPath isEqual:@"bpm"] )
        [self updateClockBPM];
    else if ( object == self.sequencerOnMainThread && [keyPath isEqual:@"stepQuantization"] )
        [self updateStepQuantizationPopup];
    else if ( object == self.sequencerOnMainThread && [keyPath isEqual:@"patternQuantization"] )
        [self updatePatternQuantizationPopup];
    
    else if ( object == self.currentSequencerPageState && [keyPath isEqual:@"currentPatternId"] )
        [self updateCurrentPattern];
    else if ( object == self.currentSequencerPageState && [keyPath isEqual:@"playMode"] )
        [self updatePlayMode];
    
    else if ( object == self.currentPageOnMainThread && [keyPath isEqual:@"stepLength"] )
        [self updateStepLengthPopup];
    else if ( object == self.currentPageOnMainThread && [keyPath isEqual:@"swing"] )
        [self updateSwingPopup];
    else if ( object == self.currentPageOnMainThread && [keyPath isEqual:@"transpose"] )
        [self updatePitches];
}

- (void) updatePitches
{
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:_sharedPreferences.gridHeight];
    
    for( int i = 0; i < _sharedPreferences.gridHeight; i ++ ) {
        
        NSNumber *pitch = [[_currentPageOnMainThread.pitches objectAtIndex:i] pitch];
        
        NSMutableDictionary *tableRow = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:i + 1], @"row",
                                                                                          pitch, @"pitch",
                                                                                          nil];
        if( _currentPageOnMainThread.transpose.intValue ) {
            NSString *transposedNote;
            
            int transposedPitch = pitch.intValue + _currentPageOnMainThread.transpose.intValue;
            if( transposedPitch > 127 )
                transposedPitch = 127;
            else if( transposedPitch < 0 )
                transposedPitch = 0;
            
            if( transposedPitch > pitch.intValue )
                transposedNote = [NSString stringWithFormat:@"↑"];
            else if( transposedPitch < pitch.intValue )
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



#pragma mark - Private methods

- (void) parentMOCSaved:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.managedObjectContextForMainThread mergeChangesFromContextDidSaveNotification:notification];
        
        [self.managedObjectContextForTickQueue performBlockAndWait:^(void){
            [self.managedObjectContextForTickQueue mergeChangesFromContextDidSaveNotification:notification];
        }];
        
        // This snippet is from http://cutecoder.org/featured/asynchronous-core-data-document/
        // It nudges the file modified date to prevent 'file has been changed by another application' errors
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSURL* fileURL = [self fileURL];
        NSDictionary* fileAttributes = [fileManager attributesOfItemAtPath:[fileURL path] error:nil];
        NSDate* modificationDate = fileAttributes[NSFileModificationDate];
        if (modificationDate) {
            // set the modification date to prevent NSDocument's "file was saved by another application" error.
            [self setFileModificationDate:modificationDate];
        }
    });
}

- (void) childMOCChanged
{
    NSError *saveMainError = nil;
    [self.managedObjectContextForMainThread save:&saveMainError];
    if( saveMainError )
        NSLog(@"Save error: %@", saveMainError);
    
    [self.managedObjectContext performBlock:^(void) {
        NSError *saveError = nil;
        [self.managedObjectContext save:&saveError];
        if( saveError )
            NSLog(@"Save error: %@", saveError);
    }];
}

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
    // We don't want this showing up in undo history
    [self.managedObjectContextForMainThread processPendingChanges];
    [self.managedObjectContextForMainThread.undoManager disableUndoRegistration];
    
    dispatch_sync(_bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            _sequencer.bpm = [notification.userInfo valueForKey:@"bpm"];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
    
    [self.managedObjectContextForMainThread processPendingChanges];
    [self.managedObjectContextForMainThread.undoManager enableUndoRegistration];
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

- (void) resetPlayPositions
{
    if( self.clock.clockStatus != EatsClockStatus_Stopped )
        [self.clockTick clockSongStop:0];
    [self.clockTick songPositionZero];
    
    //Reset the play positions of all the active loops
    int i = 0;
    for( SequencerPageState *pageState in _sequencerState.pageStates ) {
        if( pageState.playMode.intValue == EatsSequencerPlayMode_Pause || pageState.playMode.intValue == EatsSequencerPlayMode_Forward ) {
            pageState.currentStep = [[[_sequencerOnMainThread.pages objectAtIndex:i] loopEnd] copy];
            pageState.inLoop = YES;
        } else if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
            pageState.currentStep = [[[_sequencerOnMainThread.pages objectAtIndex:i] loopStart] copy];
            pageState.inLoop = YES;
        }
        i ++;
    }
    
    [self updateUI];
    [self.gridNavigationController updateGridView];
}

- (void) checkForThingsOutsideGrid
{
    [self.managedObjectContextForMainThread processPendingChanges];
    [self.managedObjectContextForMainThread.undoManager disableUndoRegistration];
    
    dispatch_sync(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            // Make sure all the loops etc fit within the connected grid size
            for( SequencerPage *page in self.sequencer.pages ) {
                if( page.loopStart.intValue >= self.sharedPreferences.gridWidth || page.loopEnd.intValue >= self.sharedPreferences.gridWidth ) {
                    
                    page.loopStart = [NSNumber numberWithInt:0];
                    page.loopEnd = [NSNumber numberWithInt:self.sharedPreferences.gridWidth - 1];
                }
                
                if( page.transposeZeroStep.intValue >= self.sharedPreferences.gridWidth )
                    page.transposeZeroStep = [NSNumber numberWithUnsignedInt:(self.sharedPreferences.gridWidth) / 2 - 1];
                
                NSError *saveError = nil;
                [self.managedObjectContext save:&saveError];
                if( saveError )
                    NSLog(@"Save error: %@", saveError);
                
                SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:page.id.intValue];
                
                if( pageState.currentStep.intValue >= self.sharedPreferences.gridWidth )
                    pageState.currentStep = [page.loopEnd copy];
                if( pageState.nextStep.intValue >= self.sharedPreferences.gridWidth )
                    pageState.nextStep = nil;
                if( pageState.currentPatternId.intValue >= self.sharedPreferences.gridWidth )
                    pageState.currentPatternId = [NSNumber numberWithInt:0];
                if( pageState.nextPatternId.intValue >= self.sharedPreferences.gridWidth )
                    pageState.nextPatternId = nil;
            }
            
            // Get the notes

            NSError *requestError = nil;
            NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
            noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step >= %u) OR (row >= %u)", self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight];
            
            NSUInteger count = [self.managedObjectContext countForFetchRequest:noteRequest error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);

            if( count > 0 && !self.notesOutsideGridAlert ) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    self.notesOutsideGridAlert = [NSAlert alertWithMessageText:@"This song contains notes outside of the grid controller's area."
                                                                  defaultButton:@"Leave notes"
                                                                alternateButton:@"Remove notes"
                                                                    otherButton:nil
                                                      informativeTextWithFormat:@"Would you like to remove these %lu notes?", count];
                    
                    [self.notesOutsideGridAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(notesOutsideGridAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
                });
            }
        }];
        
        [self.gridNavigationController updateGridView];
    });
    
    [self.managedObjectContextForMainThread processPendingChanges];
    [self.managedObjectContextForMainThread.undoManager enableUndoRegistration];

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
        self.currentPageOnMainThread.name = newLabel;
        [self.currentPageSegmentedControl setLabel:self.currentPageOnMainThread.name forSegment:[self.currentPageOnMainThread.id intValue]];
    }
}

- (void) notesOutsideGridAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    // Leave them
    if( returnCode == NSOKButton ) {
        
    // Remove them
    } else {
        
        // Remove the notes
        dispatch_async(self.bigSerialQueue, ^(void) {
            [self.managedObjectContext performBlockAndWait:^(void) {
                
                NSError *requestError = nil;
                NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
                noteRequest.predicate = [NSPredicate predicateWithFormat:@"(step >= %u) OR (row >= %u)", self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight];
                
                NSArray *matches = [self.managedObjectContext executeFetchRequest:noteRequest error:&requestError];
                
                if( requestError )
                    NSLog(@"Request error: %@", requestError);
                
                for( SequencerNote *note in matches ) {
                    [self.managedObjectContext deleteObject:note];
                }
                NSError *saveError = nil;
                [self.managedObjectContext save:&saveError];
                if( saveError )
                    NSLog(@"Save error: %@", saveError);
            }];
            
            [self updateUI];
        });
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
    NSLog(@"sequencerOnMainThread %@", _sequencerOnMainThread);
    NSLog(@"sequencerOnMainThread.pages[0] %@", [_sequencerOnMainThread.pages objectAtIndex:0]);
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

- (void) showPage:(uint)pageId
{
    if( self.currentPageOnMainThread.id.intValue == pageId )
        return;
    
    // Switch page with an animation
    
    self.currentPageSegmentedControl.selectedSegment = pageId;
    
    self.pageView.alphaValue = 0.0;
    
    NSRect frame = self.pageView.frame;
    if( pageId > _currentPageOnMainThread.id.integerValue )
        frame.origin.x += 100.0;
    else if ( pageId < _currentPageOnMainThread.id.integerValue )
        frame.origin.x -= 100.0;
    self.pageView.frame = frame;
    
    self.currentPageOnMainThread = [self.sequencerOnMainThread.pages objectAtIndex:pageId];
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.2];
    [[self.pageView animator] setAlphaValue:1.0];
    [[self.pageView animator] setFrameOrigin:self.pageViewFrameOrigin];
    [NSAnimationContext endGrouping];
}

- (void) showPreviousPage
{
    int newPageId = self.currentPageOnMainThread.id.intValue - 1;
    if( newPageId < 0 )
        newPageId = SEQUENCER_PAGES - 1;
    [self showPage:newPageId];
}

- (void) showNextPage
{
    int newPageId = self.currentPageOnMainThread.id.intValue + 1;
    if( newPageId >= SEQUENCER_PAGES )
        newPageId = 0;
    [self showPage:newPageId];
}

- (void) decrementBPM
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            float newBPM = roundf( [_sequencer.bpm floatValue] ) - 1;
            if( newBPM < 20 )
                newBPM = 20;
            _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
    });
}

- (void) incrementBPM
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            float newBPM = roundf( [_sequencer.bpm floatValue] ) + 1;
            if( newBPM > 300 )
                newBPM = 300;
            _sequencer.bpm = [NSNumber numberWithFloat:newBPM];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
    });
}

- (void) setCurrentPagePattern:(int)patternId
{
    BOOL patternQuantizationOn = NO;
    
    if( self.sequencerOnMainThread.patternQuantization.unsignedIntValue > 0 )
        patternQuantizationOn = YES;
    
    self.currentSequencerPageState.nextPatternId = [NSNumber numberWithInt:patternId];
    
    // If pattern quantization is disabled
    if( !patternQuantizationOn ) {
        [self updateUI];
        [self.gridNavigationController updateGridView];
        
    } else {
        self.currentPatternSegmentedControl.selectedSegment = self.currentSequencerPageState.currentPatternId.integerValue;
    }
}

- (void) setAllPagePatterns:(int)patternId
{
    BOOL patternQuantizationOn = NO;
    
    if( self.sequencerOnMainThread.patternQuantization.unsignedIntValue > 0 )
        patternQuantizationOn = YES;
    
    for( SequencerPageState *pageState in self.sequencerState.pageStates ) {
        pageState.nextPatternId = [NSNumber numberWithInt:patternId];   
    }
    
    // If pattern quantization is disabled
    if( !patternQuantizationOn ) {
        [self updateUI];
        [self.gridNavigationController updateGridView];
        
    } else {
        self.currentPatternSegmentedControl.selectedSegment = self.currentSequencerPageState.currentPatternId.integerValue;
    }
}

- (void) setCurrentPagePlayMode:(EatsSequencerPlayMode)playMode
{
    if( self.currentSequencerPageState.playMode.intValue == playMode )
        return;
    
    self.currentSequencerPageState.playMode = [NSNumber numberWithInteger:playMode];
    
    self.currentSequencerPageState.nextStep = nil;
    
    [self.gridNavigationController updateGridView];
    [self updateUI];
}

- (void) decrementCurrentPageTranspose
{
    int pageId = _currentPageOnMainThread.id.intValue;
    
    dispatch_sync(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            SequencerPage *page = [_sequencer.pages objectAtIndex:pageId];
            
            int newTranspose = page.transpose.intValue - 1;
            if( newTranspose < - 127 )
                newTranspose = -127;
            
            page.transpose = [NSNumber numberWithInt:newTranspose];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
    });
    
    [self.gridNavigationController updateGridView];
}

- (void) incrementCurrentPageTranspose
{
    int pageId = _currentPageOnMainThread.id.intValue;
    
    dispatch_sync(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            SequencerPage *page = [_sequencer.pages objectAtIndex:pageId];
            
            int newTranspose = page.transpose.intValue + 1;
            if( newTranspose > 127 )
                newTranspose = 127;
            
            page.transpose = [NSNumber numberWithInt:newTranspose];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
        
    });
    
    [self.gridNavigationController updateGridView];
}

- (void) clearPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId
{
    dispatch_sync(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            SequencerPage *page = [self.sequencer.pages objectAtIndex:pageId.intValue];
            [Sequencer clearPattern:[page.patterns objectAtIndex:patternId.intValue]];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
    
    [self updateUI];
}

- (void) cutPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId
{
    [self copyPattern:patternId inPage:pageId];
    [self clearPattern:patternId inPage:pageId];
}

- (void) copyPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId
{
    // In order to avoid doing anything complicated and making the core data stuff support coding, here we just turn notes into an array of
    // dictionary objects and then make them into NSData
    
    SequencerPattern *pattern = [[[_sequencerOnMainThread.pages objectAtIndex:pageId.unsignedIntValue] patterns] objectAtIndex:patternId.unsignedIntValue];
    
    if( pattern.notes.count ) {
        
        NSMutableArray *notesArray = [NSMutableArray arrayWithCapacity:pattern.notes.count];
        
        for( SequencerNote *note in pattern.notes) {
            NSDictionary *noteProperties = [NSDictionary dictionaryWithObjectsAndKeys:note.length, @"length",
                                                                                     note.row, @"row",
                                                                                     note.step, @"step",
                                                                                     note.velocity, @"velocity",
                                                                                     nil];
            [notesArray addObject:noteProperties];
        }
        
        NSData *notesData = [NSKeyedArchiver archivedDataWithRootObject:notesArray];
        
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        
        NSString *pasteboardType = SEQUENCER_NOTES_DATA_PASTEBOARD_TYPE;
        NSArray *pasteboardTypes = [NSArray arrayWithObject:pasteboardType];
        [pasteboard declareTypes:pasteboardTypes owner:nil];
        
        [pasteboard setData:notesData forType:pasteboardType];
    }
}

- (void) pastePattern:(NSNumber *)patternId inPage:(NSNumber *)pageId
{
    NSString *pasteboardType = SEQUENCER_NOTES_DATA_PASTEBOARD_TYPE;
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    
    NSData *notesData = [pasteboard dataForType:pasteboardType];
    if( notesData ) {
        NSArray *newNotes = [NSKeyedUnarchiver unarchiveObjectWithData:notesData];
        
        NSMutableSet *newNotesSet = [NSMutableSet setWithCapacity:newNotes.count];
            
        for( NSDictionary *noteProperties in newNotes ) {
            SequencerNote *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:self.managedObjectContextForMainThread];
            newNote.length = [noteProperties valueForKey:@"length"];
            newNote.row = [noteProperties valueForKey:@"row"];
            newNote.step = [noteProperties valueForKey:@"step"];
            newNote.velocity = [noteProperties valueForKey:@"velocity"];
            [newNotesSet addObject:newNote];
        }
        
        SequencerPattern *pattern = [[[_sequencerOnMainThread.pages objectAtIndex:pageId.unsignedIntValue] patterns] objectAtIndex:patternId.unsignedIntValue];
        pattern.notes = newNotesSet;

        [self childMOCChanged];
        [self updateUI];
    }
}



#pragma mark - Interface actions

- (IBAction)bpmTextField:(NSTextField *)sender
{
    if( !_sequencerOnMainThread.bpm )
        _sequencerOnMainThread.bpm = [NSNumber numberWithInt:100];
    
    [self childMOCChanged];
}

- (IBAction)bpmStepper:(NSStepper *)sender
{
    [self childMOCChanged];
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            self.sequencer.bpm = [NSNumber numberWithFloat:roundf( self.sequencer.bpm.floatValue )];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
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
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            self.sequencer.stepQuantization = [[self.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
}

- (IBAction) patternQuantizationPopup:(NSPopUpButton *)sender
{
    dispatch_sync(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            self.sequencer.patternQuantization = [[self.patternQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
    [self updateUI];
}

- (IBAction) currentPageSegmentedControl:(NSSegmentedControl *)sender
{
    // Edit name
    if( sender.selectedSegment == _currentPageOnMainThread.id.integerValue ) {
        // Make a text field, add it to an alert and then show it so you can edit the page name
        
        NSTextField *accessoryTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,200,22)];
        
        accessoryTextField.stringValue = self.currentPageOnMainThread.name;
        
        NSAlert *editLabelAlert = [NSAlert alertWithMessageText:@"Edit the label for this sequencer page."
                                                  defaultButton:@"OK"
                                                alternateButton:@"Cancel"
                                                    otherButton:nil
                                      informativeTextWithFormat:@""];
        [editLabelAlert setAccessoryView:accessoryTextField];
        
        [editLabelAlert beginSheetModalForWindow:self.documentWindow modalDelegate:self didEndSelector:@selector(editLabelAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
    // Otherwise switch page
    } else {
        [self showPage:(uint)sender.selectedSegment];
    }
}

- (IBAction)currentPatternSegmentedControl:(NSSegmentedControl *)sender
{
    [self setCurrentPagePattern:(int)sender.selectedSegment];
}

- (IBAction)pagePlaybackControls:(NSSegmentedControl *)sender
{
    [self setCurrentPagePlayMode:(int)sender.selectedSegment];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSInteger rowIndex = self.rowPitchesTableView.numberOfRows - 1 - self.rowPitchesTableView.selectedRow;
    SequencerRowPitch *rowPitch = [_currentPageOnMainThread.pitches objectAtIndex:rowIndex];
    rowPitch.pitch = [[_currentPagePitches objectAtIndex:rowIndex] valueForKey:@"pitch"];
    
    [self childMOCChanged];
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
                
                int pageId = self.currentPageOnMainThread.id.intValue;
                
                dispatch_async(self.bigSerialQueue, ^(void) {
                    [self.managedObjectContext performBlockAndWait:^(void) {
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
                            int r = 0;
                            
                            for( WMNote *note in sequenceOfNotes ) {
                                
                                SequencerPage *page = [self.sequencer.pages objectAtIndex:pageId];
                                SequencerRowPitch *rowPitch = [page.pitches objectAtIndex:r];
                                rowPitch.pitch = [NSNumber numberWithInt:note.midiNoteNumber];
                                r++;
                            }
                            
                            // Remember what scale was just generated
                            self.lastTonicNoteName = tonicNote.shortName;
                        }
                        NSError *saveError = nil;
                        [self.managedObjectContext save:&saveError];
                        if( saveError )
                            NSLog(@"Save error: %@", saveError);
                    }];
                    [self updatePitches];
                });
                
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
    int pageId = self.currentPageOnMainThread.id.intValue;
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            SequencerPage *page = [self.sequencer.pages objectAtIndex:pageId];
            page.stepLength = [[self.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
}

- (IBAction)swingPopup:(NSPopUpButton *)sender
{
    int pageId = self.currentPageOnMainThread.id.intValue;
    NSUInteger index = [sender indexOfSelectedItem];
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            SequencerPage *page = [self.sequencer.pages objectAtIndex:pageId];
            page.swingType = [[self.swingArray objectAtIndex:index] valueForKey:@"type"];
            page.swingAmount = [[self.swingArray objectAtIndex:index] valueForKey:@"amount"];
            NSError *saveError = nil;
            [self.managedObjectContext save:&saveError];
            if( saveError )
                NSLog(@"Save error: %@", saveError);
        }];
    });
}

- (IBAction)velocityGrooveCheckbox:(NSButton *)sender
{
    [self childMOCChanged];
}


- (IBAction)transposeTextField:(NSTextField *)sender
{
    if( !_currentPageOnMainThread.transpose )
        _currentPageOnMainThread.transpose = [NSNumber numberWithInt:0];
    [self childMOCChanged];
    [self.gridNavigationController updateGridView];
}

- (IBAction)transposeStepper:(NSStepper *)sender
{
    [self childMOCChanged];
    [self.gridNavigationController updateGridView];
}



#pragma mark - Keyboard shortcuts

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

- (void) keyDownFromKeyboardInputView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags
{
    // Sequencer playback
    // Space
    if( keyCode.intValue == 49 )
       [self toggleSequencerPlayback];
    
    // BPM
    // -
    else if( keyCode.intValue == 27 )
        [self decrementBPM];
    // +
    else if( keyCode.intValue == 24 )
        [self incrementBPM];

    // Pages
    // F1
    else if( keyCode.intValue == 122 )
        [self showPage:0];
    // F2
    else if( keyCode.intValue == 120 )
        [self showPage:1];
    // F3
    else if( keyCode.intValue == 99 )
        [self showPage:2];
    // F4
    else if( keyCode.intValue == 118 )
        [self showPage:3];
    // F5
    else if( keyCode.intValue == 96 )
        [self showPage:4];
    // F6
    else if( keyCode.intValue == 97 )
        [self showPage:5];
    // F7
    else if( keyCode.intValue == 98 )
        [self showPage:6];
    // F8
    else if( keyCode.intValue == 100 )
        [self showPage:7];
    
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
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 2
    } else if( keyCode.intValue == 19 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 11;
        else
            nextPatternId = 1;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 3
    } else if( keyCode.intValue == 20 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 12;
        else
            nextPatternId = 2;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 4
    } else if( keyCode.intValue == 21 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 13;
        else
            nextPatternId = 3;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 5
    } else if( keyCode.intValue == 23 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 14;
        else
            nextPatternId = 4;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 6
    } else if( keyCode.intValue == 22 ) {
        int nextPatternId;
        if( modifierFlags.intValue & NSShiftKeyMask )
            nextPatternId = 15;
        else
            nextPatternId = 5;
        
        if( modifierFlags.intValue & NSAlternateKeyMask )
            [self setAllPagePatterns:nextPatternId];
        else
            [self setCurrentPagePattern:nextPatternId];
        
    // 7
    } else if( keyCode.intValue == 26 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 6;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self setAllPagePatterns:nextPatternId];
            else
                [self setCurrentPagePattern:nextPatternId];
        }
        
    // 8
    } else if( keyCode.intValue == 28 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 7;
        
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self setAllPagePatterns:nextPatternId];
            else
                [self setCurrentPagePattern:nextPatternId];
        }
        
    // 9
    } else if( keyCode.intValue == 25 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 8;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self setAllPagePatterns:nextPatternId];
            else
                [self setCurrentPagePattern:nextPatternId];
        }
        
    // 0
    } else if( keyCode.intValue == 29 ) {
        if( !(modifierFlags.intValue & NSShiftKeyMask) ) {
            int nextPatternId = 9;
            
            if( modifierFlags.intValue & NSAlternateKeyMask )
                [self setAllPagePatterns:nextPatternId];
            else
                [self setCurrentPagePattern:nextPatternId];
        }
    
    // Play mode
    // p
    } else if( keyCode.intValue == 35 )
        [self setCurrentPagePlayMode:EatsSequencerPlayMode_Pause];
    // >
    else if( keyCode.intValue == 47 )
        [self setCurrentPagePlayMode:EatsSequencerPlayMode_Forward];
    // <
    else if( keyCode.intValue == 43 )
        [self setCurrentPagePlayMode:EatsSequencerPlayMode_Reverse];
    // ?
    else if( keyCode.intValue == 44 )
        [self setCurrentPagePlayMode:EatsSequencerPlayMode_Random];
    
    // Transpose
    // [
    else if( keyCode.intValue == 33 )
        [self decrementCurrentPageTranspose];
    // ]
    else if( keyCode.intValue == 30 )
        [self incrementCurrentPageTranspose];
    
    // Debug info
    // d
    else if( keyCode.intValue == 2 )
        [self logDebugInfo];
    
    // Log the rest
//    else
//        NSLog(@"keyDown code: %@ withModifierFlags: %@", keyCode, modifierFlags );
}

@end