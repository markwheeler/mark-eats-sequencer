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
#import "EatsDebugGridView.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

#define SEQUENCER_PAGES 8

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

@property (nonatomic, assign) IBOutlet NSWindow *documentWindow;
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
    
    self.pitchesArrayController.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"row" ascending:NO]];
    
    __block NSNumber *pageId;

    pageId = currentPageOnMainThread.id;
    
    _currentPageOnMainThread = currentPageOnMainThread;
    _currentSequencerPageState = [_sequencerState.pageStates objectAtIndex:pageId.unsignedIntegerValue];
    
    [self.currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentSequencerPageState addObserver:self forKeyPath:@"playMode" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self.currentPageOnMainThread addObserver:self forKeyPath:@"stepLength" options:NSKeyValueObservingOptionNew context:NULL];
    [self.currentPageOnMainThread addObserver:self forKeyPath:@"swing" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self updatePitchesPredicateForPage:pageId.intValue];
    self.pageObjectController.fetchPredicate = [NSPredicate predicateWithFormat:@"self.id == %@", pageId];
    
    [self updateSequencerPageUI];
    
}

- (SequencerPage *) currentPageOnMainThread
{
    return _currentPageOnMainThread;
}


// TODO remove this, just for testing
//- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error
//{
//    NSLog(@"Configuring the thing... (if this doesn't get fired then we'll crash??)");
//    
//    return [super configurePersistentStoreCoordinatorForURL:url ofType:fileType modelConfiguration:configuration storeOptions:storeOptions error:error];
//}



#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        // Create the serial queue
        _bigSerialQueue = dispatch_queue_create("com.MarkEatsSequencer.BigQueue", NULL);
        
        self.isActive = NO;
        
        // Get the prefs singleton
        self.sharedPreferences = [Preferences sharedPreferences];
        
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
    //NSLog(@"%s", __func__);
    
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    [self.currentSequencerPageState removeObserver:self forKeyPath:@"playMode"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"bpm"];
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"stepQuantization"];
    [self.sequencerOnMainThread removeObserver:self forKeyPath:@"patternQuantization"];
    
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"stepLength"];
    [self.currentPageOnMainThread removeObserver:self forKeyPath:@"swing"];
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

- (void) completeSetupOncePersistentStoreIsReady
{
    self.setupComplete = YES;
    
    // How this works:
    // This document's MOC is the parent and has a private queue. It's used across the app
    // There is a child MOC with a main queue type that is used with bindings etc.
    // There is another child MOC which is reserved only for use on the tickQueue and is only used for reading data – just for when we need to know what to play
    // Method below are used for keeping the MOCs in sync (parentMOCSaved: and childMOCChanged)
    
    // Replace the NSPersistentDocument's MOC with a new one that has a PrivateQueue and can be used as a parent
    NSManagedObjectContext *parentMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [parentMOC performBlockAndWait:^(void) {
        parentMOC.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
        parentMOC.undoManager = self.managedObjectContext.undoManager;
    }];
    self.managedObjectContext = parentMOC;
    
    // Create a child MOC for use on the main thead in bindings etc
    self.managedObjectContextForMainThread = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContextForMainThread.parentContext = self.managedObjectContext;
    
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
        self.sequencerOnMainThread = [matches lastObject];
    } else {
        // Create initial structure
        self.sequencerOnMainThread = [Sequencer sequencerWithPages:SEQUENCER_PAGES inManagedObjectContext:self.managedObjectContextForMainThread];
        
        // Add dummy data (can be useful for testing, just adds 16 random notes)
        //[Sequencer addDummyDataToSequencer:self.sequencerOnMainThread inManagedObjectContext:self.managedObjectContextForMainThread];
        
        [self childMOCChanged];
    }
    
    // Setup the SequencerState
    _sequencerState = [[SequencerState alloc] init];
    [_sequencerState createPageStates:SEQUENCER_PAGES];
    for( SequencerPage *page in self.sequencerOnMainThread.pages ) {
        [[_sequencerState.pageStates objectAtIndex:page.id.unsignedIntegerValue] setCurrentStep:[page.loopEnd copy]];
    }
    
    // Get the sequencer and page for background thread stuff
    [self.managedObjectContext performBlockAndWait:^(void) {
        NSError *requestError = nil;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
        NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
        
        self.sequencer = [matches lastObject];
    }];
    
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
    if( returnCode == NSOKButton )
        [self clearPattern];
    self.clearPatternAlert = nil;
}

- (void) clearPattern
{
    int pageId = self.currentPageOnMainThread.id.intValue;
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            SequencerPage *page = [self.sequencer.pages objectAtIndex:pageId];
            [Sequencer clearPattern:[page.patterns objectAtIndex:_currentSequencerPageState.currentPatternId.unsignedIntegerValue]];
            [self.managedObjectContext save:nil];
        }];

        [self updateUI];
    });
}


#pragma mark - Setup and update UI

- (void) setupUI
{
    self.clockLateIndicator.alphaValue = 0.0;
    
    self.debugGridView.managedObjectContext = self.managedObjectContextForMainThread;
    self.debugGridView.sequencerState = self.sequencerState;
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
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"row" ascending: YES];
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
    
    _debugGridView.currentPageId = _currentPageOnMainThread.id.intValue;

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
        
    } else {
        self.currentPatternSegmentedControl.selectedSegment = _currentSequencerPageState.currentPatternId.intValue;
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
}

- (void) updatePitchesPredicateForPage:(int)pageId
{
    self.pitchesArrayController.fetchPredicate = [NSPredicate predicateWithFormat:@"inPage.id == %i AND row < %u", pageId, self.sharedPreferences.gridHeight];
}



#pragma mark - Private methods

- (void) parentMOCSaved:(NSNotification *)notification
{
    [self.managedObjectContextForMainThread mergeChangesFromContextDidSaveNotification:notification];
    [self.managedObjectContextForTickQueue performBlock:^(void){
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
}

- (void) childMOCChanged
{
    [self.managedObjectContextForMainThread save:nil];
    [self.managedObjectContext performBlock:^(void) {
        [self.managedObjectContext save:nil];
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
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            self.sequencer.bpm = [notification.userInfo valueForKey:@"bpm"];
            [self.managedObjectContext save:nil];
        }];
    });
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
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            
            // Make sure all the loops etc fit within the connected grid size
            for( SequencerPage *page in self.sequencer.pages ) {
                if( page.loopStart.intValue >= self.sharedPreferences.gridWidth || page.loopEnd.intValue >= self.sharedPreferences.gridWidth ) {
                    
                    page.loopStart = [NSNumber numberWithInt:0];
                    page.loopEnd = [NSNumber numberWithInt:self.sharedPreferences.gridWidth - 1];
                }
                
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
        [self.currentPatternSegmentedControl setWidth:28.0 forSegment:i];
    }
    
    // Pitch list
    [self updatePitchesPredicateForPage:_currentPageOnMainThread.id.intValue];
    
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
                [self.managedObjectContext save:nil];
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



#pragma mark - Interface actions

- (IBAction)bpmStepper:(NSStepper *)sender
{
    [self childMOCChanged];
    
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            self.sequencer.bpm = [NSNumber numberWithFloat:roundf( self.sequencer.bpm.floatValue )];
            [self.managedObjectContext save:nil];
        }];
    });
}


- (IBAction)bpmTextField:(NSTextField *)sender
{
    [self childMOCChanged];
}

- (IBAction)sequencerPlaybackControls:(NSSegmentedControl *)sender
{
    if( sender.selectedSegment == 0 ) {
        if( self.clock.clockStatus == EatsClockStatus_Stopped )
            [self resetPlayPositions];
        else
            [self.clock stopClock];
    } else {
        [self.clock startClock];
    }
}



- (IBAction) stepQuantizationPopup:(NSPopUpButton *)sender
{
    dispatch_async(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlock:^(void) {
            self.sequencer.stepQuantization = [[self.stepQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
            [self.managedObjectContext save:nil];
        }];
    });
}

- (IBAction) patternQuantizationPopup:(NSPopUpButton *)sender
{
    dispatch_sync(self.bigSerialQueue, ^(void) {
        [self.managedObjectContext performBlockAndWait:^(void) {
            self.sequencer.patternQuantization = [[self.patternQuantizationArray objectAtIndex:[sender indexOfSelectedItem]] valueForKey:@"quantization"];
            [self.managedObjectContext save:nil];
        }];
    });
    [self updateUI];
}

- (IBAction) currentPageSegmentedControl:(NSSegmentedControl *)sender
{
    self.currentPageOnMainThread = [self.sequencerOnMainThread.pages objectAtIndex:sender.selectedSegment];
}

- (IBAction) editLabelButton:(NSButton *)sender
{
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
}

- (IBAction)currentPatternSegmentedControl:(NSSegmentedControl *)sender
{
    BOOL patternQuantizationOn = NO;
    
    if( self.sequencerOnMainThread.patternQuantization.unsignedIntValue > 0 )
        patternQuantizationOn = YES;
    
    self.currentSequencerPageState.nextPatternId = [NSNumber numberWithInteger:sender.selectedSegment];
    
    // If pattern quantization is disabled
    if( !patternQuantizationOn ) {
        [self updateUI];
        [self.gridNavigationController updateGridView];
        
    } else {
        [sender setSelectedSegment:self.currentSequencerPageState.currentPatternId.integerValue];
    }
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
    
    [self updateUI];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
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
                    [self.managedObjectContext performBlock:^(void) {
                        // Check what note the user entered
                        WMNote *tonicNote;
                        if ( [[NSScanner scannerWithString:noteName] scanInt:nil] )
                            tonicNote = [[WMPool pool] noteWithMidiNoteNumber:noteName.intValue]; // Lookup by MIDI value if they enetered a number
                        else
                            tonicNote = [[WMPool pool] noteWithShortName:noteName]; // Otherwise use the short name
                        
                        // If we found a note then generate the sequence
                        if( tonicNote ) {

                            // Generate pitches
                            NSArray *sequenceOfNotes = [WMPool sequenceOfNotesWithRootShortName:tonicNote.shortName scaleMode:scaleMode length:32];

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
                        [self.managedObjectContext save:nil];
                    }];
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
            [self.managedObjectContext save:nil];
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
            [self.managedObjectContext save:nil];
        }];
    });
}

- (IBAction)velocityGrooveCheckbox:(NSButton *)sender
{
    [self childMOCChanged];
}

@end