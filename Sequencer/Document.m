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

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsClock                     *clock;
@property EatsExternalClockCalculator   *externalClockCalculator;
@property EatsGridNavigationController  *gridNavigationController;

@property (strong) IBOutlet NSWindow *documentWindow;

// Clock stuff
@property NSUInteger        currentTick;
@property VVMIDINode        *clockSource;
@property NSMutableArray    *activeNotes;

- (void) clockSongStart:(NSNumber *)ns;
- (void) clockSongStop:(NSNumber *)ns;
- (void) clockTick:(NSNumber *)ns;
- (void) clockLateBy:(NSNumber *)ns;

@end


@implementation Document


#pragma mark - Setters and getters

@synthesize isActive = _isActive;

- (void)setIsActive:(BOOL)isActive
{
    _isActive = isActive;
    if(self.gridNavigationController) self.gridNavigationController.isActive = isActive;
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

        self.isActive = NO;
        
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Create a Clock and set it up
        self.clock = [[EatsClock alloc] init];
        [self.clock setDelegate:self];
        [self.clock setBpm:[self.sequencer.bpm floatValue]];
        [self.clock setPpqn:PPQN];
        [self.clock setQnPerMeasure:QN_PER_MEASURE];
        
        self.externalClockCalculator = [[EatsExternalClockCalculator alloc] init];
        
        // Create the objects needed for keeping track of active notes
        self.activeNotes = [NSMutableArray array];
        for(int i = 0; i < MIN_QUANTIZATION; i++)
            [self.activeNotes addObject:[NSMutableSet setWithCapacity:32]];
        
        self.gridNavigationController = [[EatsGridNavigationController alloc] initWithManagedObjectContext:self.managedObjectContext];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeMain:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[aController window]];
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
    
    //NSLog(@"Tick: %@ Time: %@", self.currentTick, ns);
    
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
            
            //NSLog(@"playMode: %@ currentStep: %@ nextStep: %@", page.playMode, page.currentStep, page.nextStep);
            
            page.currentStep = [NSNumber numberWithInt:[page.nextStep intValue]];
            
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
                int nextStep = floor(arc4random_uniform([page.loopEnd intValue] + 1 - [page.loopStart intValue]) + [page.loopStart intValue]);
                page.nextStep = [NSNumber numberWithInt: nextStep];
                NSLog(@"%@", page.nextStep);
            }

            // Send notes that need to be sent
            // Fetch notes for current step, playMode != paused (might be able to do this outside of the for loop?)
        
        }

        
        // Test send – 1/8 notes
        if(self.currentTick % (TICKS_PER_MEASURE / 8) == 0) {
            // Key note
            int pitch = 60;
            
            // A simple diatonic scale generator for testing (intervals are 2–2–1–2–2–2–1)
            NSUInteger eighthStep = self.currentTick / (TICKS_PER_MEASURE / 8);
            if(eighthStep == 2)
                pitch += 4;
            else if(eighthStep == 7)
                pitch += 12;
            else if(eighthStep < 2)
                pitch += 2 * (int)eighthStep;
            else
                pitch += (2 * (int)eighthStep) - 1;
            
            // Set note properties
            int channel = 0;
            int velocity = 96;
            // This number in the end here is the number of MIN_QUANTIZATION steps that the note will be in length. Must be between 1 and MIN_QUANTIZATION
            int endStep = ((int)self.currentTick / (TICKS_PER_MEASURE / MIN_QUANTIZATION)) + 2;
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
    
    
        // Update the interface (could use GCD here if it feels like a bottleneck)
        [self.gridNavigationController performSelectorOnMainThread:@selector(updateGridView)
                                                        withObject:nil
                                                     waitUntilDone:NO];
    
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
    [[self.sequencer.pages objectAtIndex:0] setPlayMode:[NSNumber numberWithInt:EatsSequencerPlayMode_Pause]];
}


- (IBAction)sequencerForwardButton:(NSButton *)sender
{
    [[self.sequencer.pages objectAtIndex:0] setPlayMode:[NSNumber numberWithInt:EatsSequencerPlayMode_Forward]];
}

- (IBAction)sequencerReverseButton:(NSButton *)sender
{
    [[self.sequencer.pages objectAtIndex:0] setPlayMode:[NSNumber numberWithInt:EatsSequencerPlayMode_Reverse]];
}

- (IBAction)sequencerRandomButton:(NSButton *)sender
{
    [[self.sequencer.pages objectAtIndex:0] setPlayMode:[NSNumber numberWithInt:EatsSequencerPlayMode_Random]];
}




- (IBAction)introViewButton:(NSButton *)sender
{
        [self.gridNavigationController showView:[NSNumber numberWithInt:EatsGridView_Intro]];
}

- (IBAction)sequencerViewButton:(NSButton *)sender
{
    [self.gridNavigationController showView:[NSNumber numberWithInt:EatsGridView_Sequencer]];
}

- (IBAction)playViewButton:(NSButton *)sender
{
    [self.gridNavigationController showView:[NSNumber numberWithInt:EatsGridView_Play]];
}


- (IBAction)updateGridViewButton:(NSButton *)sender {
    [self.gridNavigationController updateGridView];
}


@end
