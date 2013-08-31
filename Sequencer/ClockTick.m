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
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        self.sequencer = sequencer;
        
        kern_return_t kernError;
        mach_timebase_info_data_t timebaseInfo;
        
        kernError = mach_timebase_info(&timebaseInfo);
        if (kernError != KERN_SUCCESS) {
            NSLog(@"Error getting mach_timebase");
        } else {
            // Set the time factors so we can work in ns
            _machTimeToNsFactor = (double)timebaseInfo.numer / timebaseInfo.denom;
            _nsToMachTimeFactor = 1.0 / _machTimeToNsFactor;
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
    
    [self stopNotes:_activeNotes atTime:ns];
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
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( _currentTick % (_ticksPerMeasure / _minQuantization) == 0 ) {
        
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
                uint position = ( playNow * ( _minQuantization / [self.sequencer stepLengthForPage:pageId] ) );
                
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
                        if( playMode == EatsSequencerPlayMode_Reverse )
                            position = _minQuantization - 1 - position;
                        
                        //NSLog(@"Note position: %u", position);
                        
                        // Calculate the swing based on note position etc
                        nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                                         type:[self.sequencer swingTypeForPage:pageId]
                                                                       amount:[self.sequencer swingAmountForPage:pageId]
                                                                          bpm:_bpm
                                                                 qnPerMeasure:_qnPerMeasure
                                                              minQuantization:_minQuantization];
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
                    
                    // This number in the end here is the MIN_QUANTIZATION steps that the note will be in length.
                    int length = roundf( (float)note.length * ( _minQuantization / (float)[self.sequencer stepLengthForPage:pageId] ) );
                    if( length < 1 )
                        NSLog(@"Note added to active notes was too short: %i", length);
                    // Add to activeNotes so we know when to stop it
                    [_activeNotes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                                                                              [NSNumber numberWithInt:channel], @"channel",
                                                                                              [NSNumber numberWithInt:velocity], @"velocity",
                                                                                              [NSNumber numberWithInt:length], @"lengthRemaining",
                                                                                              [NSNumber numberWithInt:pageId], @"fromPageId",
                                                                                              nil]];
                }
                
            }
            
        }
        
        [self incrementTick];

        
    } else {
        [self incrementTick];
    }
    
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
    } else if( _currentTick % (_ticksPerMeasure / [self.sequencer stepLengthForPage:pageId] ) == 0 ) {
        
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
        uint64_t nsSwing = 0;
        
        // We only add swing when playing forward or reverse
        if( playMode == EatsSequencerPlayMode_Forward || playMode == EatsSequencerPlayMode_Reverse ) {
            
            // Position of note in the loop 0 - minQuantization
            uint position = ( [self.sequencer currentStepForPage:pageIdForNote] * ( _minQuantization / [self.sequencer stepLengthForPage:pageIdForNote] ) );
            
            // Reverse position if we're playing in reverse
            if( playMode == EatsSequencerPlayMode_Reverse )
                position = _minQuantization - 1 - position;
            
            nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                             type:[self.sequencer swingTypeForPage:pageIdForNote]
                                                           amount:[self.sequencer swingAmountForPage:pageIdForNote]
                                                              bpm:_bpm
                                                     qnPerMeasure:_qnPerMeasure
                                                  minQuantization:_minQuantization];
        }
        
        // Stop it
        [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                 onChannel:[[note objectForKey:@"channel"] intValue]
              withVelocity:[[note objectForKey:@"velocity"] intValue]
                    atTime:ns + nsSwing];
    }
}

@end
