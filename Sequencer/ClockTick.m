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
        msg = [VVMIDIMessage createFromVals:VVMIDISongPosPointerVal :0 :0 :0 :-1 :(uint64_t)(mach_absolute_time() * _machTimeToNsFactor)];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockTick:(uint64_t)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)_currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    [self tickMIDIClockPulse:ns];
    [self tickStopNotes:ns];
    [self tickAdvanceAndAutomate:ns];
    
    for( uint pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        [self tickSendModulation:ns forPage:pageId];
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

- (void) tickMIDIClockPulse:(uint64_t)ns
{
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if( _currentTick % ( _ppqn / _midiClockPPQN ) == 0
       && self.sharedPreferences.sendMIDIClock
       && self.sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        [self sendMIDIClockPulseAtTime:ns];
    }
}

- (void) tickStopNotes:(uint64_t)ns
{
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
}

- (void) tickAdvanceAndAutomate:(uint64_t)ns
{
    
    // If this is a 64th...
    if( _currentTick % ( _ticksPerMeasure / MIN_QUANTIZATION ) == 0 ) {
        
        // Send this notification just for animations etc
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_currentTick / ( _ticksPerMeasure / MIN_QUANTIZATION )] forKey:@"tick"];
        [[NSNotificationCenter defaultCenter] postNotificationName:kClockMinQuantizationTick object:self userInfo:userInfo];
        
        // Do automation stuff
        if( self.sequencer.automationMode == EatsSequencerAutomationMode_Recording || self.sequencer.automationMode == EatsSequencerAutomationMode_Playing ) {
            NSSet *changesForThisTick = [self.sequencer automationChangesForTick:self.sequencer.automationCurrentTick];
            
            for( SequencerAutomationChange *change in changesForThisTick ) {
                
                // Change pattern
                if( change.automationType == EatsSequencerAutomationType_SetNextPatternId ) {
                    [self.sequencer setNextPatternIdWithoutAutomation:[change.values valueForKey:@"value"] forPage:change.pageId];
                    
                // Scrub step
                } else if( change.automationType == EatsSequencerAutomationType_SetNextStep ) {
                    [self.sequencer setNextStepWithoutAutomation:[change.values valueForKey:@"value"] forPage:change.pageId];
                    
                // Loop
                } else if( change.automationType == EatsSequencerAutomationType_SetLoop ) {
                    [self.sequencer setLoopStartWithoutRegisteringUndo:[[change.values valueForKey:@"startValue"] intValue] andLoopEnd:[[change.values valueForKey:@"endValue"] intValue] forPage:change.pageId];
                    
                // Transpose
                } else if( change.automationType == EatsSequencerAutomationType_SetTranspose ) {
                    [self.sequencer setTransposeWithoutRegisteringUndo:[[change.values valueForKey:@"value"] intValue] forPage:change.pageId];
                    
                // Play mode
                } else if( change.automationType == EatsSequencerAutomationType_SetPlayMode ) {
                    [self.sequencer setPlayMode:[[change.values valueForKey:@"value"] intValue] forPage:change.pageId];
                    
                }
            }
        }
    }
    
    // Update the current step for each page
    
    for( uint pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        
        EatsSequencerPlayMode playMode = [self.sequencer playModeForPage:pageId];
        int loopStart = [self.sequencer loopStartForPage:pageId];
        int loopEnd = [self.sequencer loopEndForPage:pageId];
        BOOL inLoop = [self.sequencer inLoopForPage:pageId];
        
        BOOL setPageTickThisTick = NO;
        
        // This will return if the user is scrubbing or the page is ready to advance on it's own (or neither)
        EatsStepAdvance needsToAdvance = [self needToAdvanceStep:pageId];
        
        int playNow = [self.sequencer currentStepForPage:pageId];
        
        // If we need to advance and it's not paused
        if( needsToAdvance != EatsStepAdvance_None && playMode != EatsSequencerPlayMode_Pause ) {
            
            // If the page has been scrubbed
            if( needsToAdvance == EatsStepAdvance_Scrubbed ) {
                
                playNow = [[self.sequencer nextStepForPage:pageId] intValue];
                
                
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
            
            // Set the step
            [self.sequencer setCurrentStep:playNow forPage:pageId];
            
            // And make the page tick line up with it
            [self.sequencer setPageTickToCurrentStep:_ticksPerMeasure forPage:pageId];
            setPageTickThisTick = YES;
            
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
                [self.sequencer setNextPatternIdWithoutAutomation:nil forPage:pageId];
            }
            
            // Send notes for playNow
            [self tickSendNotes:ns atStep:playNow forPage:pageId];
        
        }
        
        // Advance the pageTick which is used in calculated smoothed modulation
        if( playMode != EatsSequencerPlayMode_Pause ) {
            
            if( !setPageTickThisTick && [self.sequencer pageTickForPage:pageId] != nil )
                [self.sequencer advancePageTickWithTicksPerMeasure:_ticksPerMeasure forPage:pageId];
            
        } else {
            
            // Set pageTick to nil so we know not to update it
            [self.sequencer setPageTickToNilForPage:pageId];
        }
    }
    
    
    // Advance automation tick if appropriate
    if( _currentTick % (_ticksPerMeasure / MIN_QUANTIZATION ) == 0 && ( self.sequencer.automationMode == EatsSequencerAutomationMode_Recording || self.sequencer.automationMode == EatsSequencerAutomationMode_Playing ) ) {
        [self.sequencer incrementAutomationCurrentTick];
    }
    
}

// Send notes is called from within the above
- (void) tickSendNotes:(uint64_t)ns atStep:(uint)step forPage:(uint)pageId
{
    // Check if we're advancing
    EatsSequencerPlayMode playMode = [self.sequencer playModeForPage:pageId];
    if( playMode == EatsSequencerPlayMode_Pause || ![self.sequencer sendNotesForPage:pageId] )
        return;
    
    // Get the notes
    NSSet *notes = [self.sequencer notesAtStep:step inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
    
    if( !notes.count )
        return;
    
    // Get stuff needed for all notes on this step
    
    int channel = [self.sequencer channelForPage:pageId];
    int stepLength = [self.sequencer stepLengthForPage:pageId];
    uint64_t nsSwing = [self calculateSwingForStep:step forPage:pageId];
    
    // Send notes that need to be sent
    for( SequencerNote *note in notes ) {
        
        int pitch = [self.sequencer pitchAtRow:note.row forPage:pageId];
        
        // Transpose
        pitch += [self.sequencer transposeForPage:pageId];
        if( pitch < SEQUENCER_MIDI_MIN )
            pitch = SEQUENCER_MIDI_MIN;
        if( pitch > SEQUENCER_MIDI_MAX )
            pitch = SEQUENCER_MIDI_MAX;
        
        // Calculate velocity
        
        int velocity = note.velocity;
        
        // We only add swing and velocity groove when playing forward or reverse
        if( playMode == EatsSequencerPlayMode_Forward || playMode == EatsSequencerPlayMode_Reverse ) {
            
            // Velocity groove if enabled
            if( [self.sequencer velocityGrooveForPage:pageId] ) {
                velocity = [EatsVelocityUtils calculateVelocityForPosition:step * ( _minQuantization / stepLength )
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
        
        // Set note length
        
        // This number in the end here is the _ticksPerMeasure steps that the note will be in length.
        int length = roundf( (float)note.length * ( _ticksPerMeasure / (float)stepLength ) );
        
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

- (void) tickSendModulation:(uint64_t)ns forPage:(uint)pageId
{
    EatsStepAdvance needsToAdvance = [self needToAdvanceStep:pageId];
    
    // Tidy up next step (this actually has nothing to do with modulation but has to be done here so needsToAdvance works correctly)
    if( needsToAdvance == EatsStepAdvance_Scrubbed )
        [self.sequencer setNextStepWithoutAutomation:nil forPage:pageId];
    
    // Do some checks to see if we need to actually send modulation...
    
    // No need to send anything if we're paused
    EatsSequencerPlayMode playMode = [self.sequencer playModeForPage:pageId];
    if( playMode == EatsSequencerPlayMode_Pause )
        return;
    
    // And if we're not yet really going
    if( [self.sequencer pageTickForPage:pageId] == nil )
        return;
    
    // Are any of the modulation busses active on this page?
    
    BOOL modulationBusActiveOnThisPage = NO;
    
    for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ ) {
        
        uint modulationDestinationId = [self.sequencer modulationDestinationIdForBus:b forPage:pageId];
        if( modulationDestinationId ) {
            modulationBusActiveOnThisPage = YES;
            break;
        }
    }
    
    if( !modulationBusActiveOnThisPage )
        return;
    
    // Are there any notes in the current pattern?
    if( ![self.sequencer numberOfNotesForPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId] )
        return;
    
    // Are we playing a note this tick?
    
    BOOL playingANote = NO;
    
    NSUInteger numberOfNotesAtStep = [[self.sequencer notesAtStep:[self.sequencer currentStepForPage:pageId] inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId] count];
    
    if( needsToAdvance != EatsStepAdvance_None && numberOfNotesAtStep )
        playingANote = YES;
    
    if( playMode == EatsSequencerPlayMode_Slice ) {
        // If we're not smoothing and the step hasn't changed or it's an empty step then return
        if( ![self.sequencer modulationSmoothForPage:pageId] && ( needsToAdvance == EatsStepAdvance_None || !playingANote ) )
            return;
        
    } else {
        // If we're not smoothing then return if a note isn't playing
        if( ![self.sequencer modulationSmoothForPage:pageId] && !playingANote )
            return;
    }
    
    // Looks like we need to do this!
    
    uint stepLength = [self.sequencer stepLengthForPage:pageId];
    
    
    // Calculate the swing
    
    int pageTickForSwing = [[self.sequencer pageTickForPage:pageId] intValue];
    int pageTicksPerStep = _ticksPerMeasure / stepLength;
    
    // Work out step based on pageTick to allow for reverse adjustment above
    int currentStepForSwing = floor( pageTickForSwing / pageTicksPerStep );
    
    // Calculate swing for this step and next
    
    int nextStepForSwing = currentStepForSwing;
    
    if( playMode == EatsSequencerPlayMode_Forward ) {
        nextStepForSwing ++;
        if( nextStepForSwing >= self.sharedPreferences.gridWidth )
            nextStepForSwing = 0;
    } else if( playMode == EatsSequencerPlayMode_Reverse ) {
        nextStepForSwing --;
        if( nextStepForSwing < 0 )
            nextStepForSwing = self.sharedPreferences.gridWidth - 1;
    }
    
    uint64_t nsSwing = [self calculateSwingForStep:currentStepForSwing forPage:pageId];
    uint64_t nsSwingForNextStep = [self calculateSwingForStep:nextStepForSwing forPage:pageId];
    
    // Work out how far we are through the step
    
    uint pageTickOfCurrentStep = currentStepForSwing * pageTicksPerStep;
    float progressionBetweenSteps;
    
    if( playMode == EatsSequencerPlayMode_Reverse ) {
        // Adjust to look at the end of the notes for reverse mode
        pageTickOfCurrentStep += pageTicksPerStep - 1;
        progressionBetweenSteps = ( pageTickOfCurrentStep - pageTickForSwing ) / (float)pageTicksPerStep;
        
    } else {
        progressionBetweenSteps = ( pageTickForSwing - pageTickOfCurrentStep ) / (float)pageTicksPerStep;
    }
    
    uint64_t nsSwingForModulation = nsSwing * ( 1.0 - progressionBetweenSteps ) + nsSwingForNextStep * progressionBetweenSteps;
    
    
    // Find the modulation values
    
    // Offset the modulation values by almost a step when in reverse so that modulation lines up with the start of the note
    
    int pageTickForVals = pageTickForSwing;
    int currentStepForVals;
    
    if( playMode == EatsSequencerPlayMode_Reverse ) {
        
        pageTickForVals -= pageTicksPerStep - 1;
        if( pageTickForVals < 0 )
            pageTickForVals += self.sharedPreferences.gridWidth * pageTicksPerStep;
        
        // Re-calculate currentStep
        currentStepForVals = floor( pageTickForVals / pageTicksPerStep );
        
    } else {
        currentStepForVals = currentStepForSwing;
    }
    
    // Setup arrays for finding the previous and next modulation values
    
    NSMutableArray *previousModulationValues = [NSMutableArray arrayWithCapacity:NUMBER_OF_MODULATION_BUSSES];
    for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ )
        previousModulationValues[b] = [NSNumber numberWithFloat:0.0];
    
    NSMutableArray *nextModulationValues = [NSMutableArray arrayWithCapacity:NUMBER_OF_MODULATION_BUSSES];
    for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ )
        nextModulationValues[b] = [NSNumber numberWithFloat:0.0];
    
    
    // Find the previous modulation value
    
    NSSet *notesToCheck;
    int previousStepToCheck = currentStepForVals + 1;
    
    // Find the last step to have notes
    while( notesToCheck.count == 0 ) {
        previousStepToCheck --;
        if( previousStepToCheck < 0 )
            previousStepToCheck = self.sharedPreferences.gridWidth - 1;
        notesToCheck = [self.sequencer notesAtStep:previousStepToCheck inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
    }
    
    // Find the highest modulation value from those notes
    for( SequencerNote *note in notesToCheck ) {
        for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ ) {
            float modulationValue = [self.sequencer modulationValueForBus:b forNoteAtStep:note.step atRow:note.row inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
            if( modulationValue > [previousModulationValues[b] floatValue] )
                previousModulationValues[b] = [NSNumber numberWithFloat:modulationValue];
        }
    }
    
    
    // Find the next modulation value
    
    notesToCheck = nil;
    int nextStepToCheck = currentStepForVals;
    
    // Find the last step to have notes
    while( notesToCheck.count == 0 ) {
        nextStepToCheck ++;
        if( nextStepToCheck >= self.sharedPreferences.gridWidth )
            nextStepToCheck = 0;
        notesToCheck = [self.sequencer notesAtStep:nextStepToCheck inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
    }
    
    // Find the highest modulation value from those notes
    for( SequencerNote *note in notesToCheck ) {
        for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ ) {
            float modulationValue = [self.sequencer modulationValueForBus:b forNoteAtStep:note.step atRow:note.row inPattern:[self.sequencer currentPatternIdForPage:pageId] inPage:pageId];
            if( modulationValue > [nextModulationValues[b] floatValue] )
                nextModulationValues[b] = [NSNumber numberWithFloat:modulationValue];
        }
    }
    
    int nextStepToCheckInTicks = nextStepToCheck * pageTicksPerStep;
    int previousStepToCheckInTicks = previousStepToCheck * pageTicksPerStep;
    
    // Work out where we are inbetween the two values
    if( nextStepToCheckInTicks < previousStepToCheckInTicks ) {
        if( pageTickForVals < previousStepToCheckInTicks )
            previousStepToCheckInTicks -= self.sharedPreferences.gridWidth * pageTicksPerStep;
        else
            nextStepToCheckInTicks += self.sharedPreferences.gridWidth * pageTicksPerStep;
    }
    
    int ticksBetweenModulationValues = nextStepToCheckInTicks - previousStepToCheckInTicks;
    
    float progressionBetweenValues = 0.0;
    if( nextStepToCheck != previousStepToCheck )
        progressionBetweenValues = ( pageTickForVals - previousStepToCheckInTicks ) / (float)ticksBetweenModulationValues;
    
    
    // Send the values
    
    for( int b = 0; b < NUMBER_OF_MODULATION_BUSSES; b ++ ) {
        
        uint modulationDestinationId = [self.sequencer modulationDestinationIdForBus:b forPage:pageId];
        
        if( modulationDestinationId ) {
            
            float tweenedModulationValueToSend = [previousModulationValues[b] floatValue] * ( 1.0 - progressionBetweenValues ) + [nextModulationValues[b] floatValue] * progressionBetweenValues;
            
            NSDictionary *modulationDestination = self.sharedPreferences.modulationDestinationsArray[modulationDestinationId];
            [self sendMIDIModulationValue:tweenedModulationValueToSend
                                   ofType:[[modulationDestination objectForKey:@"type"] unsignedIntValue]
                                onChannel:[self.sequencer channelForPage:pageId]
                       toControllerNumber:[[modulationDestination objectForKey:@"controllerNumber"] unsignedIntValue]
                                   atTime:ns + nsSwingForModulation];
        }
    }
}


- (EatsStepAdvance) needToAdvanceStep:(uint)pageId
{
    // If the page has been scrubbed
    if( [self.sequencer nextStepForPage:pageId] && _currentTick % ( _ticksPerMeasure / [self.sequencer stepQuantization] ) == 0 ) {
        return EatsStepAdvance_Scrubbed;
        
    // If the sequence needs to advance
    } else if( _currentTick % ( _ticksPerMeasure / [self.sequencer stepLengthForPage:pageId] ) == 0 && [self.sequencer playModeForPage:pageId] != EatsSequencerPlayMode_Slice ) {
        return EatsStepAdvance_Normal;
        
    } else {
        return EatsStepAdvance_None;
    }
}

- (uint64_t) calculateSwingForStep:(uint)step forPage:(uint)pageId
{
    uint64_t nsSwing = 0;
    
    EatsSequencerPlayMode playMode = [self.sequencer playModeForPage:pageId];
    
    // We only add swing and velocity groove when playing forward or reverse
    if( playMode == EatsSequencerPlayMode_Forward || playMode == EatsSequencerPlayMode_Reverse ) {
        
        int stepLength = [self.sequencer stepLengthForPage:pageId];
        
        // Don't apply swing to the time sigs that don't fit into the loop
        if( _minQuantization % stepLength == 0 ) {
        
            int sixtyFourthsPerStep = _minQuantization / stepLength;
            
            // Position of step in the loop 0 - minQuantization (unless loop is shorter)
            int minQuantPositionOfStep = step * sixtyFourthsPerStep;
            
            // Reverse position if we're playing in reverse
            if( playMode == EatsSequencerPlayMode_Reverse )
                minQuantPositionOfStep = ( self.sharedPreferences.gridWidth * sixtyFourthsPerStep ) - sixtyFourthsPerStep - minQuantPositionOfStep;
            
            // Calculate the swing based on note position etc
            nsSwing = [EatsSwingUtils calculateSwingNsForPosition:minQuantPositionOfStep
                                                             type:[self.sequencer swingTypeForPage:pageId]
                                                           amount:[self.sequencer swingAmountForPage:pageId]
                                                              bpm:_bpm
                                                     qnPerMeasure:_qnPerMeasure
                                                  minQuantization:_minQuantization];
        }
    }
    
    return nsSwing;
}

- (void) incrementTick
{
    // Increment the tick
    _currentTick++;
    if( _currentTick >= _ticksPerMeasure )
        _currentTick = 0;
}



#pragma mark - Private methods for sending and stopping MIDI

- (void) startMIDINote:(int)n
             onChannel:(int)c
          withVelocity:(int)v
                atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
    msg = [VVMIDIMessage createFromVals:VVMIDINoteOnVal :c :n :v :-1 :ns];
    // Send it
	if( msg != nil )
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopMIDINote:(int)n
            onChannel:(int)c
         withVelocity:(int)v
               atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
    // Create a message
    msg = [VVMIDIMessage createFromVals:VVMIDINoteOffVal :c :n :v :-1 :ns];
    // Send it
	if( msg != nil )
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) sendMIDIClockPulseAtTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	// Create a message
	msg = [VVMIDIMessage createWithType:VVMIDIClockVal channel:0 timestamp:ns];
    // Send it
	if( msg != nil )
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) sendMIDIModulationValue:(float)value
                          ofType:(VVMIDIMsgType)type
                       onChannel:(uint)channel
              toControllerNumber:(uint)controllerNumber
                          atTime:(uint64_t)ns
{
    // Create a message
    VVMIDIMessage *msg = nil;
    
    if( type == VVMIDIPitchWheelVal ) {
        uint midiValue = roundf( SEQUENCER_MIDI_MAX_14_BIT * value ); // 0-16383 is the range of the 14bit number pitch bend accepts
        uint leastSignificant = midiValue & 0x7F;
        uint mostSignificant = ( midiValue >> 7 ) & 0x7F;
        msg = [VVMIDIMessage createFromVals:type :channel :leastSignificant :mostSignificant :-1 :ns];
    
    } else if( type == VVMIDIChannelPressureVal ) {
        msg = [VVMIDIMessage createFromVals:type :channel :roundf( SEQUENCER_MIDI_MAX * value ) :-1 :-1 :ns];
    
    } else {
        msg = [VVMIDIMessage createFromVals:type :channel :controllerNumber :roundf( SEQUENCER_MIDI_MAX * value ) :-1 :ns];
    }
    
    // Send it
    if( msg != nil )
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
                                                                                 stepLength:stepLength];
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
