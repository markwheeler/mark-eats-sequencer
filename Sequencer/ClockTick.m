//
//  ClockTick.m
//  Sequencer
//
//  Created by Mark Wheeler on 21/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ClockTick.h"
#import "EatsCommunicationManager.h"
#import "EatsSwingUtils.h"
#import "EatsVelocityUtils.h"
#import "Preferences.h"
#import "Sequencer.h"

typedef enum EatsStepAdvance {
    EatsStepAdvance_None,
    EatsStepAdvance_Normal,
    EatsStepAdvance_Scrubbed
} EatsStepAdvance;

@interface ClockTick ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;

@property (nonatomic) double            machTimeToNsFactor;
@property (nonatomic) double            nsToMachTimeFactor;

@property (nonatomic) uint              currentTick;
@property (nonatomic) NSMutableArray    *activeNotes;

@end

@implementation ClockTick


#pragma mark - Public methods

- (id)initWithSequencer:(Sequencer *)sequencer
{
    self = [super init];
    if (self) {
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        self.sequencer = sequencer;
        
        kern_return_t kernError;
        mach_timebase_info_data_t timebaseInfo;
        
        kernError = mach_timebase_info(&timebaseInfo);
        if (kernError != KERN_SUCCESS) {
            NSLog(@"Error getting mach_timebase");
        } else {
            // Set the time factors so we can work in ns
            self.machTimeToNsFactor = (double)timebaseInfo.numer / timebaseInfo.denom;
            self.nsToMachTimeFactor = 1.0 / self.machTimeToNsFactor;
        }
    }
    return self;
}

//- (void) dealloc
//{
//    NSLog(@"%s", __func__);
//}



#pragma mark - Clock delegate methods

- (void) clockSongStart:(uint64_t)ns
{
    // Create the objects needed for keeping track of active notes
    if(!_activeNotes) {
        _activeNotes = [NSMutableArray arrayWithCapacity:32];
    }
    
    _currentTick = 0;
    
    if( self.sharedPreferences.sendMIDIClock
       && self.sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        
        if( !ns )
            ns = (uint64_t)(mach_absolute_time() * _machTimeToNsFactor);
        
        // Send start
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStartVal channel:0 timestamp:ns];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockSongStop:(uint64_t)ns
{
    if( self.sharedPreferences.sendMIDIClock
       && self.sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        
        if( !ns )
            ns = (uint64_t)(mach_absolute_time() * _machTimeToNsFactor);
        
        // Send stop
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStopVal channel:0 timestamp:ns];
        if (msg != nil) {
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        }
    }
    
    // Stop all notes as soon as possible
    for( NSMutableDictionary *note in _activeNotes ) {
        
        uint64_t startedAtNs = [[note objectForKey:@"startedAtNs"] unsignedLongLongValue];
        uint64_t stopAtNs;
        
        if( startedAtNs < ns )
            stopAtNs = ns;
        else
            stopAtNs = startedAtNs + 50; // Adding 50 just to make sure it definitely goes out after the note on
        
        // Stop it
        [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                 onChannel:[[note objectForKey:@"channel"] intValue]
              withVelocity:[[note objectForKey:@"velocity"] intValue]
                    atTime:stopAtNs];
    }
    
    [_activeNotes removeAllObjects];
}

- (void) songPositionZero
{
    if( self.sharedPreferences.sendMIDIClock
       && self.sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        // Send song position 0
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createFromVals:VVMIDISongPosPointerVal :0 :0 :0 :(uint64_t)(mach_absolute_time() * _machTimeToNsFactor)];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockTick:(uint64_t)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    // Could also potentially re-work to only fire on MIN_QUANTIZATION? Schedule more than 1 clock pulse if need be
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)_currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if( _currentTick % (_ppqn / _midiClockPPQN) == 0
       && self.sharedPreferences.sendMIDIClock
       && self.sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        [self sendMIDIClockPulseAtTime:ns];
    }
    
    
    // Check if any of the active notes need to be stopped this tick
    
    NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:8];
    for( NSMutableDictionary *note in _activeNotes ) {
        
        int lengthRemaining = [[note objectForKey:@"lengthRemaining"] intValue];
        lengthRemaining --;
        
        if( lengthRemaining <= 0 )
            [toRemove addObject:note];
        else
            [note setObject:[NSNumber numberWithInt:lengthRemaining] forKey:@"lengthRemaining"];
    }
    
    [self stopNotes:toRemove atTime:ns];
    [_activeNotes removeObjectsInArray:toRemove];
    
    
    // Do automation stuff if this is a 64th
    if( _currentTick % (_ticksPerMeasure / MIN_QUANTIZATION ) == 0 && ( self.sequencer.automationMode == EatsSequencerAutomationMode_Recording || self.sequencer.automationMode == EatsSequencerAutomationMode_Playing ) ) {
        
        NSSet *changesForThisTick = [self.sequencer automationChangesForTick:self.sequencer.automationCurrentTick];
        
        for( SequencerAutomationChange *change in changesForThisTick ) {
            
            // Change pattern
            if( change.automationType == EatsSequencerAutomationType_SetNextPatternId ) {
                // Setting currentPatternId rather than next so as to make the loop change regardless of what loop may be set
                [self.sequencer setCurrentPatternId:[[change.values valueForKey:@"value"] intValue] forPage:change.pageId];
                
            // Scrub step
            } else if( change.automationType == EatsSequencerAutomationType_SetNextStep ) {
                [self.sequencer setNextStep:[change.values valueForKey:@"value"] forPage:change.pageId];
               
            // Loop
            } else if( change.automationType == EatsSequencerAutomationType_SetLoop ) {
                [self.sequencer setLoopStart:[[change.values valueForKey:@"startValue"] intValue] andLoopEnd:[[change.values valueForKey:@"endValue"] intValue] forPage:change.pageId];
                
            // Transpose
            } else if( change.automationType == EatsSequencerAutomationType_SetTranspose ) {
                [self.sequencer setTranspose:[[change.values valueForKey:@"value"] intValue] forPage:change.pageId];
                
            // Play mode
            } else if( change.automationType == EatsSequencerAutomationType_SetPlayMode ) {
                [self.sequencer setPlayMode:[[change.values valueForKey:@"value"] intValue] forPage:change.pageId];
                
            }
        }
    }
    
    
    // Update the current step for each page and send new notes
    
    for(uint pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        
        // This will return if the user is scrubbing or the page is ready to advance on it's own (or neither)
        EatsStepAdvance needsToAdvance = [self needToAdvanceStep:pageId];
        
        // If we need to advance and it's not paused
        if( needsToAdvance != EatsStepAdvance_None && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Pause ) {
            
            int playMode = [self.sequencer playModeForPage:pageId];
            int playNow;
            int loopStart = [self.sequencer loopStartForPage:pageId];
            int loopEnd = [self.sequencer loopEndForPage:pageId];
            BOOL inLoop = [self.sequencer inLoopForPage:pageId];
            
            // If the page has been scrubbed
            if( needsToAdvance == EatsStepAdvance_Scrubbed ) {
                
                playNow = [[self.sequencer nextStepForPage:pageId] intValue];
                [self.sequencer setNextStep:nil forPage:pageId];
                
                
            // Otherwise we need to calculate the next step
            } else {
                
                playNow = [self.sequencer currentStepForPage:pageId];
                
                // Forward
                if( playMode == EatsSequencerPlayMode_Forward ) {
                    playNow ++;
                    if( loopStart <= loopEnd ) {
                        if( ( inLoop || self.sharedPreferences.loopFromScrubArea ) && playNow > loopEnd )
                            playNow = loopStart;
                        else if( inLoop && playNow < loopStart )
                            playNow = loopEnd;
                    } else {
                        if( ( inLoop || self.sharedPreferences.loopFromScrubArea ) && playNow > loopEnd && playNow < loopStart )
                            playNow = loopStart;
                    }
                    
                    if( playNow >= self.sharedPreferences.gridWidth )
                        playNow = 0;
                    
                // Reverse
                } else if( playMode == EatsSequencerPlayMode_Reverse ) {
                    playNow --;
                    if( loopStart <= loopEnd ) {
                        if( ( inLoop || self.sharedPreferences.loopFromScrubArea ) && playNow < loopStart )
                            playNow = loopEnd;
                        else if( inLoop && playNow > loopEnd )
                            playNow = loopStart;
                    } else {
                        if( ( inLoop || self.sharedPreferences.loopFromScrubArea ) && playNow > loopEnd && playNow < loopStart )
                            playNow = loopEnd;
                    }
                    
                    if( playNow < 0 )
                        playNow = self.sharedPreferences.gridWidth - 1;
                    
                // Random
                } else if( playMode == EatsSequencerPlayMode_Random ) {
                    
                    int loopEndForRandom;
                    if( loopEnd >= loopStart )
                        loopEndForRandom = loopEnd;
                    else
                        loopEndForRandom = loopEnd + self.sharedPreferences.gridWidth;
                    
                    int range = loopEndForRandom + 1 - loopStart;
                    
                    int randomStep = floor(arc4random_uniform(range) + loopStart);
                    if( randomStep >= self.sharedPreferences.gridWidth )
                        randomStep -= self.sharedPreferences.gridWidth;
                    
                    playNow = randomStep;
                }
                
            }
            
            [self.sequencer setCurrentStep:playNow forPage:pageId];
            
            
            // Are we in a loop
            if( loopStart <= loopEnd ) {
                if( playNow >= loopStart && playNow <= loopEnd && loopEnd - loopStart != self.sharedPreferences.gridWidth - 1 )
                    [self.sequencer setInLoop:YES forPage:pageId];
                else
                    [self.sequencer setInLoop:NO forPage:pageId];
            } else {
                if( playNow >= loopStart || playNow <= loopEnd )
                    [self.sequencer setInLoop:YES forPage:pageId];
                else
                    [self.sequencer setInLoop:NO forPage:pageId];
            }
            
            
            // OK now we know what the step is we can get on with acting upon it!
            
            
            // Position of step in the loop 0 - minQuantization (unless loop is shorter)
            int position = ( playNow * ( _minQuantization / [self.sequencer stepLengthForPage:pageId] ) );
            
            // Use the appropriate value if pattern quantization is set to none
            int patternQuantization = [self.sequencer patternQuantization];
            if( patternQuantization == 0 )
                patternQuantization = self.sharedPreferences.gridWidth;
            
            // Position of step within loop 0 – minQuantization
            int positionWithinLoop;
            if( playMode == EatsSequencerPlayMode_Reverse )
                positionWithinLoop = ( ( (self.sharedPreferences.gridWidth - 1 - (float)playNow ) / self.sharedPreferences.gridWidth) * _minQuantization );
            else
                positionWithinLoop = ( ( (float)playNow / self.sharedPreferences.gridWidth ) * _minQuantization );
            
            // Check if we need to advance the pattern (depending on where we are within it)
            if( [self.sequencer nextPatternIdForPage:pageId] && positionWithinLoop % (_minQuantization / patternQuantization ) == 0 ) {
                [self.sequencer setCurrentPatternId:[[self.sequencer nextPatternIdForPage:pageId] intValue] forPage:pageId];
                [self.sequencer setNextPatternId:nil forPage:pageId];
            }


            // Get the notes
            
            NSSet *notes = [self.sequencer notesAtStep:playNow inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
            
            // Send notes that need to be sent
            for( SequencerNote *note in notes ) {
                
                int pitch = [self.sequencer pitchAtRow:note.row forPage:pageId];
                
                // Transpose
                pitch += [self.sequencer transposeForPage:pageId];
                if( pitch < SEQUENCER_MIDI_MIN )
                    pitch = SEQUENCER_MIDI_MIN;
                if( pitch > SEQUENCER_MIDI_MAX )
                    pitch = SEQUENCER_MIDI_MAX;
                
                //Set the basic note properties
                int channel = [self.sequencer channelForPage:pageId];
                int velocity = note.velocity;
                
                // Calculate swing and velocity
                
                uint64_t nsSwing = 0;
                
                // We only add swing and velocity groove when playing forward or reverse
                if( playMode == EatsSequencerPlayMode_Forward || playMode == EatsSequencerPlayMode_Reverse ) {
                    
                    // Reverse position if we're playing in reverse
                    if( playMode == EatsSequencerPlayMode_Reverse ) {
                        int sixtyFourthsPerStep = _minQuantization / [self.sequencer stepLengthForPage:pageId];
                        position = ( self.sharedPreferences.gridWidth * sixtyFourthsPerStep ) - sixtyFourthsPerStep - position;
                    }
                    
                    // Don't apply swing to the time sigs that don't fit into the loop
                    if( _minQuantization % [self.sequencer stepLengthForPage:pageId] == 0 ) {
                    
                        // Calculate the swing based on note position etc
                        nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                                         type:[self.sequencer swingTypeForPage:pageId]
                                                                       amount:[self.sequencer swingAmountForPage:pageId]
                                                                          bpm:_bpm
                                                                 qnPerMeasure:_qnPerMeasure
                                                              minQuantization:_minQuantization];
                    }
                    
                    // Velocity groove if enabled
                    if( [self.sequencer velocityGrooveForPage:pageId] ) {
                        velocity = [EatsVelocityUtils calculateVelocityForPosition:position
                                                                      baseVelocity:velocity
                                                                              type:[self.sequencer swingTypeForPage:pageId]
                                                                   minQuantization:_minQuantization];
                    }
                }
                
                
                // Send MIDI note
                [self startMIDINote:pitch
                          onChannel:channel
                       withVelocity:velocity
                             atTime:ns + nsSwing];
                
                // This number in the end here is the _ticksPerMeasure steps that the note will be in length.
                int length = roundf( (float)note.length * ( _ticksPerMeasure / (float)[self.sequencer stepLengthForPage:pageId] ) );
                if( length < 1 )
                    NSLog(@"WARNING: Note added to active notes was too short: %i", length);
                
                // Add to, or update, activeNotes so we know when to stop the note
                
                NSUInteger index = [_activeNotes indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
                    BOOL result = ( [[obj valueForKey:@"channel"] intValue] == channel && [[obj valueForKey:@"pitch"] intValue] == pitch );
                    return result;
                }];
                
                // If the note isn't already playing then make an entry for it
                if( index == NSNotFound ) {
                    [_activeNotes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                             [NSNumber numberWithInt:channel], @"channel",
                                             [NSNumber numberWithInt:velocity], @"velocity",
                                             [NSNumber numberWithInt:length], @"lengthRemaining",
                                             [NSNumber numberWithInt:pageId], @"fromPageId",
                                             [NSNumber numberWithUnsignedLongLong:ns +nsSwing], @"startedAtNs",
                                             nil]];
                    
                // If the note is playing then either update it's length, or leave it, depending on if this will make it longer or not
                } else {
                    
                    NSMutableDictionary *note = [_activeNotes objectAtIndex:index];
                    if( [[note valueForKey:@"lengthRemaining"] intValue] < length )
                        [note setObject:[NSNumber numberWithInt:length] forKey:@"lengthRemaining"];
                }
                
            }
            
        }
        
    }
    
    // Advance automation tick if appropriate
    if( _currentTick % (_ticksPerMeasure / MIN_QUANTIZATION ) == 0 && ( self.sequencer.automationMode == EatsSequencerAutomationMode_Recording || self.sequencer.automationMode == EatsSequencerAutomationMode_Playing ) ) {
        [self.sequencer incrementAutomationCurrentTick];
    }
    
    [self incrementTick];
    
}

- (void) clockLateBy:(uint64_t)ns
{
    //NSLog(@"\nClock tick was late by: %fms", (Float64)ns / 1000000.0);
    
    if( [_delegate respondsToSelector:@selector(showClockLateIndicator)] )
        [_delegate performSelectorOnMainThread:@selector(showClockLateIndicator) withObject:nil waitUntilDone:NO];
}



#pragma mark - Private methods

- (EatsStepAdvance) needToAdvanceStep:(uint)pageId
{
    
    // If the page has been scrubbed
    if( [self.sequencer nextStepForPage:pageId] && _currentTick % ( _ticksPerMeasure / [self.sequencer stepQuantization] ) == 0 ) {
        return EatsStepAdvance_Scrubbed;
        
    // If the sequence needs to advance
    } else if( _currentTick % (_ticksPerMeasure / [self.sequencer stepLengthForPage:pageId] ) == 0 && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Slice ) {
        
        return EatsStepAdvance_Normal;
        
    } else {
        return EatsStepAdvance_None;
    }
    
}

- (void) incrementTick
{
    // Increment the tick
    _currentTick++;
    if(_currentTick >= _ticksPerMeasure) _currentTick = 0;
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
		[_sharedCommunicationManager.midiManager sendMsg:msg];
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
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) sendMIDIClockPulseAtTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createWithType:VVMIDIClockVal channel:0 timestamp:ns];
    // Send it
	if (msg != nil)
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopNotes:(NSArray *)notes atTime:(uint64_t)ns
{
    
    for( NSMutableDictionary *note in notes ) {
        
        // Calculate swing
        int pageIdForNote = [[note objectForKey:@"fromPageId"] intValue];
        int playMode = [self.sequencer playModeForPage:pageIdForNote];
        int stepLength = [self.sequencer stepLengthForPage:pageIdForNote];
        int64_t nsSwing = 0;
        int64_t nsLengthAdjustment = 0;
        
        // We only add swing when playing forward or reverse && with time sigs that match up to the loop
        if( ( playMode == EatsSequencerPlayMode_Forward || playMode == EatsSequencerPlayMode_Reverse ) && _minQuantization % stepLength == 0 ) {
            
            // Position of note in the loop 0 - ticksPerMeasure
            uint position = ( [self.sequencer currentStepForPage:pageIdForNote] * ( _minQuantization / stepLength ) );
            
            // Reverse position if we're playing in reverse
            if( playMode == EatsSequencerPlayMode_Reverse ) {
                int sixtyFourthsPerStep = _minQuantization / stepLength;
                position = ( self.sharedPreferences.gridWidth * sixtyFourthsPerStep ) - sixtyFourthsPerStep - position;
            }
            
            nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                             type:[self.sequencer swingTypeForPage:pageIdForNote]
                                                           amount:[self.sequencer swingAmountForPage:pageIdForNote]
                                                              bpm:_bpm
                                                     qnPerMeasure:_qnPerMeasure
                                                  minQuantization:_minQuantization];
            
            // Calculate note length adjustment depending on swing
            nsLengthAdjustment = [EatsSwingUtils calculateNoteLengthAdjustmentNsForPosition:position
                                                                                       type:[self.sequencer swingTypeForPage:pageIdForNote]
                                                                                     amount:[self.sequencer swingAmountForPage:pageIdForNote]
                                                                                        bpm:_bpm
                                                                               qnPerMeasure:_qnPerMeasure
                                                                            minQuantization:_minQuantization
                                                                                 stepLength:[self.sequencer stepLengthForPage:pageIdForNote]];
            
            //NSLog(@"Length adjustment for position %u in ms %f", position, nsLengthAdjustment / 1000000.0);
        }
        
        // Stop it
        [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                 onChannel:[[note objectForKey:@"channel"] intValue]
              withVelocity:[[note objectForKey:@"velocity"] intValue]
                    atTime:ns + nsSwing + nsLengthAdjustment - 50];
        // Here we subtract 50ns to make sure that if a note is repeating the 'off' gets processed before the 'on'.
        // It's a bit hacky (we're actually making all the notes too short) but it's such a tiny ammount that it works fine.
    }
}

@end
