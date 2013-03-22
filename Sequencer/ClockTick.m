//
//  ClockTick.m
//  Sequencer
//
//  Created by Mark Wheeler on 21/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ClockTick.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"

@interface ClockTick ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;

@property NSUInteger        currentTick;
@property NSMutableArray    *activeNotes;

- (void) clockSongStart:(NSNumber *)ns;
- (void) clockSongStop:(NSNumber *)ns;
- (void) clockTick:(NSNumber *)ns;
- (void) clockLateBy:(NSNumber *)ns;

@end

@implementation ClockTick


#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
}



#pragma mark - Clock delegate methods

- (void) clockSongStart:(NSNumber *)ns
{
    
    // Create the objects needed for keeping track of active notes
    if(!self.activeNotes) {
        self.activeNotes = [NSMutableArray array];
        for(int i = 0; i < self.minQuantization; i++)
            [self.activeNotes addObject:[NSMutableSet setWithCapacity:32]];
    }
    
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
    
    // [self.externalClockCalculator resetExternalClock]; TODO: Add external clock support back in (AppController? Or at Document level?)
    
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

- (void) clockTick:(NSNumber *)ns // TODO: Something in this method is causeing a retain cycle if it's running when we close the document
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    // TODO: Only fire on MIN_QUANTIZATION. Schedule more than 1 clock pulse if need be
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)self.currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if(self.currentTick % (self.ppqn / self.midiClockPPQN) == 0 && self.sharedPreferences.sendMIDIClock) {
        [self sendMIDIClockPulseAtTime:[ns unsignedLongLongValue]];
    }
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( self.currentTick % (self.ticksPerMeasure / self.minQuantization) == 0 ) {
        
        // Check if any of the active notes need to be stopped this tick
        NSMutableSet *notesToStop = [self.activeNotes objectAtIndex:self.currentTick / (self.ticksPerMeasure / self.minQuantization)];
        for( NSDictionary *note in notesToStop ) {
            [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                     onChannel:[[note objectForKey:@"channel"] intValue]
                  withVelocity:[[note objectForKey:@"velocity"] intValue]
                        atTime:[ns unsignedLongLongValue]];
        }
        [notesToStop removeAllObjects];
        
        // Update the sequencer pages and send notes
        
        // Create a managedObjectContext so we stay thread safe
        //NSManagedObjectContext *managedObjectContextForThread = [[NSManagedObjectContext alloc] init];
        //[managedObjectContextForThread setPersistentStoreCoordinator:self.managedObjectContext.persistentStoreCoordinator];
        
        // For each page...
        for(SequencerPage *page in self.sequencer.pages) {
            
            // Play notes for current step, playMode != paused
            if( self.currentTick % (self.ticksPerMeasure / [page.stepLength intValue]) == 0 && [page.playMode intValue] != EatsSequencerPlayMode_Pause ) {
                
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
                    int nextStep = [Sequencer randomStepForPage:page];
                    page.nextStep = [NSNumber numberWithInt: nextStep];
                }
                
                // Send notes that need to be sent
                
                // Using fetch requests (commented this out because the thread-specific MOC doesn't have the latest changes, seems easier to just look through the set)
                //NSFetchRequest *notesRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
                //notesRequest.predicate = [NSPredicate predicateWithFormat:@"(step == %@) AND (inPattern == %@) AND (inPattern.inPage == %@)", page.currentStep, page.patterns[0], page];
                //NSArray *notesMatches = [managedObjectContextForThread executeFetchRequest:notesRequest error:nil];
                
                
                for( SequencerNote *note in [[page.patterns objectAtIndex:[page.currentPattern intValue]] notes] ) {
                    
                    if( note.step == page.currentStep ) {
                        
                        //Set note properties
                        int channel = [page.channel intValue];
                        int velocity = [note.velocity intValue];
                        int pitch = [[[page.pitches objectAtIndex:[note.row intValue]] pitch] intValue];
                        
                        // This number in the end here is the number of MIN_QUANTIZATION steps that the note will be in length. Must be between 1 and MIN_QUANTIZATION
                        int endStep = ((int)self.currentTick / ( self.ticksPerMeasure / self.minQuantization )) + 2; // TODO: base this on note.length
                        if(endStep >= self.minQuantization) endStep -= self.minQuantization;
                        
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
            
        }
        
        
        // Tell the delegate to update the interface (doing this on main thread because it uses non-thread-safe NSManagedObjectContext
        if([self.delegate respondsToSelector:@selector(updateUI)])
            [self.delegate performSelectorOnMainThread:@selector(updateUI)
                                            withObject:nil
                                         waitUntilDone:NO];
        
    }
    
    // Increment the tick to the next step
    self.currentTick++;
    if(self.currentTick >= self.ticksPerMeasure) self.currentTick = 0;
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

@end
