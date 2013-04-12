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
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"

@interface ClockTick ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;

@property uint              currentTick;
@property NSMutableArray    *activeNotes;

@end

@implementation ClockTick


#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        _sharedPreferences = [Preferences sharedPreferences];
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
}



#pragma mark - Clock delegate methods

- (void) clockSongStart:(uint64_t)ns
{
    
    // Create the objects needed for keeping track of active notes
    if(!_activeNotes) {
        _activeNotes = [NSMutableArray arrayWithCapacity:32];
    }
    
    _currentTick = 0;
    
    if( _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        // Send song position 0
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createFromVals:VVMIDISongPosPointerVal :0 :0 :0 :ns];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        
        // Send start
        msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStartVal channel:0 timestamp:ns];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockSongStop:(uint64_t)ns
{    
    if( _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        // Send stop
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStopVal channel:0 timestamp:ns];
        if (msg != nil) {
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        }
    }
    
    [self stopAllActiveMIDINotes:ns];
}

- (void) clockTick:(uint64_t)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    // TODO: Only fire on MIN_QUANTIZATION. Schedule more than 1 clock pulse if need be
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)_currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if( _currentTick % (_ppqn / _midiClockPPQN) == 0
       && _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        [self sendMIDIClockPulseAtTime:ns];
    }
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( _currentTick % (_ticksPerMeasure / _minQuantization) == 0 ) {
        
        
        // Update the current step for each page
        
        for(SequencerPage *page in _sequencer.pages) {
            
            // Play notes for current step, playMode != paused
            if( _currentTick % (_ticksPerMeasure / page.stepLength.intValue) == 0 && page.playMode.intValue != EatsSequencerPlayMode_Pause ) {
                
                // TODO: Something in these lines is causing a memory leak if it's running when we close the document.
                //       Seems to be anything that sets the page's properties means this class doesn't get released quick enough.
                
                // If page has been scrubbed
                if( page.nextStep ) {
                    page.currentStep = [page.nextStep copy];
                    page.nextStep = nil;
                    
                    // Otherwise we need to calculate the next step
                } else {
                    
                    int playNow = page.currentStep.intValue;
                    
                    // Forward
                    if( page.playMode.intValue == EatsSequencerPlayMode_Forward ) {
                        playNow ++;
                        if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                            if( ( page.inLoop.boolValue || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue )
                                playNow = page.loopStart.intValue;
                            else if( page.inLoop.boolValue && playNow < page.loopStart.intValue )
                                playNow = page.loopEnd.intValue;
                        } else {
                            if( ( page.inLoop.boolValue || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue && playNow < page.loopStart.intValue )
                                playNow = page.loopStart.intValue;
                        }
                        
                        if( playNow >= _sharedPreferences.gridWidth )
                            playNow = 0;
                        
                    // Reverse
                    } else if( page.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                        playNow --;
                        if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                            if( ( page.inLoop.boolValue || _sharedPreferences.loopFromScrubArea ) && playNow < page.loopStart.intValue )
                                playNow = page.loopEnd.intValue;
                            else if( page.inLoop.boolValue && playNow > page.loopEnd.intValue )
                                playNow = page.loopStart.intValue;
                        } else {
                            if( ( page.inLoop.boolValue || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue && playNow < page.loopStart.intValue )
                                playNow = page.loopEnd.intValue;
                        }
                        
                        if( playNow < 0 )
                            playNow = _sharedPreferences.gridWidth - 1;
                        
                    // Random
                    } else if( page.playMode.intValue == EatsSequencerPlayMode_Random ) {
                        playNow = [Sequencer randomStepForPage:page ofWidth:_sharedPreferences.gridWidth];
                    }
                    
                    page.currentStep = [NSNumber numberWithInt: playNow];
                }
                
                
                // Are we in a loop
                if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                    if( page.currentStep >= page.loopStart && page.currentStep <= page.loopEnd
                       && page.loopEnd.intValue - page.loopStart.intValue != _sharedPreferences.gridWidth - 1 )
                        page.inLoop = [NSNumber numberWithBool:YES];
                    else
                        page.inLoop = [NSNumber numberWithBool:NO];;
                } else {
                    if( page.currentStep >= page.loopStart || page.currentStep <= page.loopEnd )
                        page.inLoop = [NSNumber numberWithBool:YES];
                    else
                        page.inLoop = [NSNumber numberWithBool:NO];
                }
            }
        }

        
        
        // Check if any of the active notes need to be stopped this tick
        
        NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:8];
        for( NSMutableDictionary *note in _activeNotes ) {
            
            int lengthRemaining = [[note objectForKey:@"lengthRemaining"] intValue];
            lengthRemaining --;
            
            if( lengthRemaining <= 0 ) {
                
                // Calculate swing
                SequencerPage *pageForNote = [note objectForKey:@"fromPage"];
                uint64_t nsSwing = 0;
                
                // We only add swing when playing forward or reverse
                if( pageForNote.playMode.intValue == EatsSequencerPlayMode_Forward || pageForNote.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                    
                    // Position of note in the loop 0 - minQuantization
                    uint position = ( pageForNote.currentStep.intValue * ( _minQuantization / pageForNote.stepLength.intValue ) );
                    
                    // Reverse position if we're playing in reverse
                    if( pageForNote.playMode.intValue == EatsSequencerPlayMode_Reverse )
                        position = _minQuantization - 1 - position;
                    
                    nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                                     type:pageForNote.swingType.intValue
                                                                   amount:pageForNote.swingAmount.intValue
                                                                      bpm:_bpm
                                                             qnPerMeasure:_qnPerMeasure
                                                          minQuantization:_minQuantization];
                }
                
                // Stop it
                [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                         onChannel:[[note objectForKey:@"channel"] intValue]
                      withVelocity:[[note objectForKey:@"velocity"] intValue]
                            atTime:ns + nsSwing];
                [toRemove addObject:note];
                
            } else {
                [note setObject:[NSNumber numberWithInt:lengthRemaining] forKey:@"lengthRemaining"];
            }
        }
        [_activeNotes removeObjectsInArray:toRemove];
        
        
        // Send the notes for each page

        for(SequencerPage *page in _sequencer.pages) {
            
            // Play notes for current step, playMode != paused
            if( _currentTick % (_ticksPerMeasure / page.stepLength.intValue) == 0 && page.playMode.intValue != EatsSequencerPlayMode_Pause ) {
                
                // Send notes that need to be sent
                
                for( SequencerNote *note in [[page.patterns objectAtIndex:page.currentPatternId.intValue] notes] ) {
                    
                    BOOL isPlaying = NO;
                    int pitch = [[[page.pitches objectAtIndex:note.row.intValue] pitch] intValue];
                    
                    // Don't start a note that's already playing
                    for( NSMutableDictionary *note in _activeNotes ) {
                        if( [[note valueForKey:@"pitch"] intValue] == pitch ) {
                            isPlaying = YES;
                        }
                    }
                    
                    // Play it!
                    if( !isPlaying && note.step == page.currentStep ) {
                        
                        //Set the basic note properties
                        int channel = page.channel.intValue;
                        int velocity = floor( 127 * ([note.velocityAsPercentage floatValue] / 100.0 ) );
                        
                        // Calculate swing and velocity
                        
                        uint64_t nsSwing = 0;
                        
                        // We only add swing and velocity groove when playing forward or reverse
                        if( page.playMode.intValue == EatsSequencerPlayMode_Forward || page.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                            
                            // Position of note in the loop 0 - minQuantization
                            uint position = ( note.step.intValue * ( _minQuantization / page.stepLength.intValue ) );
                            
                            // Reverse position if we're playing in reverse
                            if( page.playMode.intValue == EatsSequencerPlayMode_Reverse )
                                position = _minQuantization - 1 - position;
                            
                            //NSLog(@"Note position: %u", position);
                            
                            // Calculate the swing based on note position etc
                            nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                                             type:page.swingType.intValue
                                                                           amount:page.swingAmount.intValue
                                                                              bpm:_bpm
                                                                     qnPerMeasure:_qnPerMeasure
                                                                  minQuantization:_minQuantization];
                            // Velocity groove if enabled
                            if( page.velocityGroove.boolValue ) {
                                velocity = [EatsVelocityUtils calculateVelocityForPosition:position
                                                                              baseVelocity:velocity
                                                                                      type:page.swingType.intValue
                                                                           minQuantization:_minQuantization];
                            }
                        }
                        
                        
                        // Send MIDI note
                        [self startMIDINote:pitch
                                  onChannel:channel
                               withVelocity:velocity
                                     atTime:ns + nsSwing];
                        
                        // This number in the end here is the MIN_QUANTIZATION steps that the note will be in length.
                        int length = roundf( note.length.floatValue * ( _minQuantization / page.stepLength.floatValue ) );
                        if( length < 1 )
                            NSLog(@"Note added to active notes was too short: %i", length);
                        // Add to activeNotes so we know when to stop it
                        [_activeNotes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                                                                                  [NSNumber numberWithInt:channel], @"channel",
                                                                                                  [NSNumber numberWithInt:velocity], @"velocity",
                                                                                                  [NSNumber numberWithInt:length], @"lengthRemaining",
                                                                                                  page, @"fromPage",
                                                                                                  nil]];
                    }
                    
                }
                
            }
            
        }
        
        // Tell the delegate to update the interface (doing this on main thread because it uses non-thread-safe NSManagedObjectContext
        if([_delegate respondsToSelector:@selector(updateUI)])
            [_delegate performSelectorOnMainThread:@selector(updateUI)
                                            withObject:nil
                                         waitUntilDone:NO];
        
    }
    
    // Increment the tick to the next step
    _currentTick++;
    if(_currentTick >= _ticksPerMeasure) _currentTick = 0;
}

- (void) clockLateBy:(uint64_t)ns
{
    // TODO: Create a visual indicator for this
    //NSLog(@"\nClock tick was late by: %fms", (Float64)ns / 1000000.0);
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

- (void) stopAllActiveMIDINotes:(Float64)ns
{
    for( NSDictionary *note in _activeNotes ) {
        [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                 onChannel:[[note objectForKey:@"channel"] intValue]
              withVelocity:[[note objectForKey:@"velocity"] intValue]
                    atTime:ns];
    }
    [_activeNotes removeAllObjects];
}

@end
