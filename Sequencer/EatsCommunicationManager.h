//
//  EatsCommunicationManager.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Singleton that gives access to MIDI and OSC managers

#import <Foundation/Foundation.h>
#import "EatsMIDIManager.h"
#import <VVOSC/VVOSC.h>

@interface EatsCommunicationManager : NSObject

@property EatsMIDIManager   *midiManager;
@property OSCManager        *oscManager;

@property OSCInPort         *oscInPort;
@property OSCOutPort        *oscOutPort;
@property NSString          *oscInputPortLabel;
@property NSString          *oscOutputPortLabel;

+ (id)sharedCommunicationManager;

@end
