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
#import "EatsExternalClockCalculator.h"
#import "EatsGridNavigationController.h"

@interface Document ()

#define PPQN 48
#define QN_PER_MEASURE 4
#define TICKS_PER_MEASURE (PPQN * QN_PER_MEASURE)
#define MIDI_CLOCK_PPQN 24
#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsClock                     *clock;
@property EatsExternalClockCalculator   *externalClockCalculator;
@property EatsGridNavigationController  *gridNavigationController;

@property NSMutableArray                *quantizationArray;
@property NSArray                       *swingArray;

// Clock stuff
@property NSUInteger        currentTick;
@property VVMIDINode        *clockSource;
@property NSMutableArray    *activeNotes;

@property (weak) IBOutlet NSWindow              *documentWindow;
@property (weak) IBOutlet NSWindow              *scaleGeneratorSheet;
@property (weak) IBOutlet NSArrayController     *pitchesArrayController;
@property (weak) IBOutlet NSObjectController    *pageObjectController;

@property (weak) IBOutlet NSTableView   *rowPitchesTableView;
@property (weak) IBOutlet NSPopUpButton *stepQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton *patternQuantizationPopup;
@property (weak) IBOutlet NSPopUpButton *stepLengthPopup;
@property (weak) IBOutlet NSPopUpButton *swingPopup;
@property (weak) IBOutlet NSPopUpButton *currentPagePopup;

- (void) clockSongStart:(NSNumber *)ns;
- (void) clockSongStop:(NSNumber *)ns;
- (void) clockTick:(NSNumber *)ns;
- (void) clockLateBy:(NSNumber *)ns;

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
        
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create a Clock and set it up
        self.clock = [[EatsClock alloc] init];
        [self.clock setDelegate:self];
        [self.clock setPpqn:PPQN];
        [self.clock setQnPerMeasure:QN_PER_MEASURE];
        
        self.externalClockCalculator = [[EatsExternalClockCalculator alloc] init];
        
        // Create the objects needed for keeping track of active notes
        self.activeNotes = [NSMutableArray array];
        for(int i = 0; i < MIN_QUANTIZATION; i++)
            [self.activeNotes addObject:[NSMutableSet setWithCapacity:32]];
        
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
        
        // Create the gridNavigationController
        self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.managedObjectContext];
        
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.sequencer removeObserver:self forKeyPath:@"bpm"];
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
        self.sequencer = [Sequencer sequencerWithPages:8 width:16 height:8 inManagedObjectContext:self.managedObjectContext];
        
        [Sequencer addDummyDataToSequencer:self.sequencer inManagedObjectContext:self.managedObjectContext];
    }
    
    // Set the current page to the first one
    self.currentPage = [self.sequencer.pages objectAtIndex:0];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[aController window]];
    
    // BPM
    [self updateClockBPM];
    [self.sequencer addObserver:self
                     forKeyPath:@"bpm"
                        options:NSKeyValueObservingOptionNew
                         context:NULL];
    
    // Setup the UI
    [self.stepQuantizationPopup removeAllItems];
    [self.patternQuantizationPopup removeAllItems];
    [self.stepLengthPopup removeAllItems];
    
    for( NSDictionary *quantization in self.quantizationArray) {
        [self.stepQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.patternQuantizationPopup addItemWithTitle:[quantization valueForKey:@"label"]];
        [self.stepLengthPopup addItemWithTitle:[quantization valueForKey:@"label"]];
    }

    [self.stepQuantizationPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencer.stepQuantization];
    }]];
    
    [self.patternQuantizationPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.sequencer.patternQuantization];
    }]];
    
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
    
    [self updateSequencerPageUI];

}

- (void)windowWillClose:(NSNotification *)notification
{
    [self.clock stopClock];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (void)didBecomeMain:(NSNotification *)notification
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    if( documentController.lastActiveDocument != self ) {
        [documentController setActiveDocument:self];
        [self.gridNavigationController updateGridView];
    }
}



#pragma mark - Private methods

- (uint) randomStepForPage:(SequencerPage *)page
{
    return floor(arc4random_uniform([page.loopEnd intValue] + 1 - [page.loopStart intValue]) + [page.loopStart intValue]);
}


- (void) updateSequencerPageUI
{
    [self.stepLengthPopup selectItemAtIndex:[self.quantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"quantization"] isEqualTo:self.currentPage.stepLength];
    }]];
    
    [self.swingPopup selectItemAtIndex:[self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return [[obj valueForKey:@"swing"] isEqualTo:self.currentPage.swing];
    }]];
}

- (void) updateClockBPM
{
    self.clock.bpm = [self.sequencer.bpm floatValue];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ( [keyPath isEqual:@"bpm"] )
        [self updateClockBPM];
}

- (void)scaleGeneratorSheetDidEnd:(NSWindow *)sheet
         returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo
{
    if(returnCode == NSOKButton) {
        NSLog(@"Sheet info: %@", contextInfo);
    }
}


#pragma mark - Clock delegate methods

- (void) clockSongStart:(NSNumber *)ns
{
    self.currentTick = 0;
    
    if(self.sharedPreferences.sendMIDIClock) {
        // Send song position 0
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createFromVals:VVMIDISongPosPointerVal :0 :0 :0 :[ns unsignedLongLongValue]];
        if (msg != nil)
            [self.sharedCommunicationManager.midiManager sendMsg:msg];
        
        // Send start
        msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStartVal channel:0 timestamp:[ns unsignedLongLongValue]];
        if (msg != nil)
            [self.sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockSongStop:(NSNumber *)ns
{
    [self.externalClockCalculator resetExternalClock];
    
    if(self.sharedPreferences.sendMIDIClock) {
        // Send stop
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStopVal channel:0 timestamp:[ns unsignedLongLongValue]];
        if (msg != nil) {
            [self.sharedCommunicationManager.midiManager sendMsg:msg];
        }
    }
    
    [self stopAllActiveMIDINotes:ns];
}

- (void) clockTick:(NSNumber *)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    NSLog(@"Tick: %lu Time: %@", (unsigned long)self.currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"Main thread %s", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if(self.currentTick % (PPQN / MIDI_CLOCK_PPQN) == 0 && self.sharedPreferences.sendMIDIClock) {
        [self sendMIDIClockPulseAtTime:[ns unsignedLongLongValue]];
    }
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( self.currentTick % (TICKS_PER_MEASURE / MIN_QUANTIZATION) == 0 ) {
        
        // Check if any of the active notes need to be stopped this tick
        NSMutableSet *notesToStop = [self.activeNotes objectAtIndex:self.currentTick / (TICKS_PER_MEASURE / MIN_QUANTIZATION)];
        for( NSDictionary *note in notesToStop ) {
            [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                     onChannel:[[note objectForKey:@"channel"] intValue]
                  withVelocity:[[note objectForKey:@"velocity"] intValue]
                        atTime:[ns unsignedLongLongValue]];
        }
        [notesToStop removeAllObjects];
        
        
        // Update the sequencer pages and send notes
        
        for(SequencerPage *page in self.sequencer.pages) {
            
            // Advance sequencer steps
            
            if( self.currentTick % (TICKS_PER_MEASURE / [page.stepLength intValue]) == 0 && [page.playMode intValue] != EatsSequencerPlayMode_Pause ) {
            
                //NSLog(@"playMode: %@ currentStep: %@ nextStep: %@", page.playMode, page.currentStep, page.nextStep);
                
                page.currentStep = [page.nextStep copy];
                
                if( [page.playMode intValue] == EatsSequencerPlayMode_Forward ) {
                    int nextStep = [page.currentStep intValue] + 1;
                    if( nextStep > [page.loopEnd intValue])
                        nextStep = [page.loopStart intValue];
                    page.nextStep = [NSNumber numberWithInt: nextStep];
                    
                } else if( [page.playMode intValue] == EatsSequencerPlayMode_Reverse ) {
                    int nextStep = [page.currentStep intValue] - 1;
                    if( nextStep < [page.loopStart intValue])
                        nextStep = [page.loopEnd intValue];
                    page.nextStep = [NSNumber numberWithInt: nextStep];
                    
                } else if( [page.playMode intValue] == EatsSequencerPlayMode_Random ) {
                    int nextStep = [self randomStepForPage:page];
                    page.nextStep = [NSNumber numberWithInt: nextStep];
                }

                // Send notes that need to be sent
                // Fetch notes for current step, playMode != paused (might be able to do this outside of the for loop?)
                
                NSFetchRequest *notesRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
                notesRequest.predicate = [NSPredicate predicateWithFormat:@"(step == %@) AND (inPattern == %@) AND (inPattern.inPage == %@)", page.currentStep, page.patterns[0], page];
                
                NSArray *notesMatches = [self.managedObjectContext executeFetchRequest:notesRequest error:nil];
                
                for( SequencerNote *note in notesMatches ) {

                    //Set note properties
                    int channel = [page.channel intValue];
                    int velocity = [note.velocity intValue];
                    int pitch = [[[page.pitches objectAtIndex:[note.row intValue]] pitch] intValue];
                    //NSLog(@"Pitch: %i Step: %i", [note.row intValue], [note.step intValue]);
                    
                    // This number in the end here is the number of MIN_QUANTIZATION steps that the note will be in length. Must be between 1 and MIN_QUANTIZATION
                    int endStep = ((int)self.currentTick / (TICKS_PER_MEASURE / MIN_QUANTIZATION)) + 2; // TODO: base this on note.length
                    if(endStep >= MIN_QUANTIZATION) endStep -= MIN_QUANTIZATION;

                    // Send MIDI note
                    [self startMIDINote:pitch
                              onChannel:channel
                           withVelocity:velocity
                                 atTime:[ns unsignedLongLongValue]];

                    // Add to activeNotes so we know when to stop it
                    [[self.activeNotes objectAtIndex:endStep] addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                                                         [NSNumber numberWithInt:channel], @"channel",
                                                                         [NSNumber numberWithInt:velocity], @"velocity",
                                                                         nil]];
                    
                    // TODO: See if it's possible to check if notes are being sent late based on their timestamp vs current time

                }
                    
            }
        
        }
    
    
        // Update the interface
        [self.gridNavigationController updateGridView];
        //[self.gridNavigationController performSelectorOnMainThread:@selector(updateGridView)
        //                                                withObject:nil
        //                                             waitUntilDone:NO];
    
    }
    
    // Increment the tick to the next step
    self.currentTick++;
    if(self.currentTick >= TICKS_PER_MEASURE) self.currentTick = 0;
}

- (void) clockLateBy:(NSNumber *)ns
{
    // TODO: Create a visual indicator for this
    NSLog(@"\nClock tick was late by: %fms", [ns floatValue] / 1000000.0);
}



#pragma mark - Private methods for sending and stopping MIDI

- (void) startMIDINote:(int)n
             onChannel:(int)c
          withVelocity:(int)v
                atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createFromVals:VVMIDINoteOnVal :c :n :v :ns];
    // Send it
	if (msg != nil)
		[self.sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopMIDINote:(int)n
            onChannel:(int)c
         withVelocity:(int)v
               atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createFromVals:VVMIDINoteOffVal :c :n :v :ns];
    // Send it
	if (msg != nil)
		[self.sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) sendMIDIClockPulseAtTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createWithType:VVMIDIClockVal channel:0 timestamp:ns];
    // Send it
	if (msg != nil)
		[self.sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopAllActiveMIDINotes:(NSNumber *)ns
{
    for( NSMutableSet *notesToStop in self.activeNotes ) {
        for( NSDictionary *note in notesToStop ) {
            [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                     onChannel:[[note objectForKey:@"channel"] intValue]
                  withVelocity:[[note objectForKey:@"velocity"] intValue]
                        atTime:[ns unsignedLongLongValue]];
        }
        [notesToStop removeAllObjects];
    }
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
    page.nextStep = [page.currentStep copy];
}


- (IBAction)sequencerForwardButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Forward];
    page.nextStep = [NSNumber numberWithInt:[page.currentStep intValue] + 1];
}

- (IBAction)sequencerReverseButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Reverse];
    page.nextStep = [NSNumber numberWithInt:[page.currentStep intValue] - 1];
}

- (IBAction)sequencerRandomButton:(NSButton *)sender
{
    SequencerPage *page = [self.sequencer.pages objectAtIndex:0];
    page.playMode = [NSNumber numberWithInt:EatsSequencerPlayMode_Random];
    page.nextStep = [NSNumber numberWithInt:[self randomStepForPage:page]];
}

- (IBAction)scalesOpenSheetButton:(NSButton *)sender { 
    if (!self.scaleGeneratorSheet)
        [NSBundle loadNibNamed:@"ScaleGeneratorSheet" owner:self];
    [NSApp beginSheet:self.scaleGeneratorSheet
       modalForWindow:self.documentWindow
        modalDelegate:self
       didEndSelector:@selector(scaleGeneratorSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)cancelScalesButton:(NSButton *)sender
{
    [NSApp endSheet: self.scaleGeneratorSheet returnCode:NSCancelButton];
    [self.scaleGeneratorSheet close];
    self.scaleGeneratorSheet = nil;
}

- (IBAction)generateScalesButton:(NSButton *)sender
{
    [NSApp endSheet: self.scaleGeneratorSheet returnCode:NSOKButton];
    [self.scaleGeneratorSheet close];
    self.scaleGeneratorSheet = nil;
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
