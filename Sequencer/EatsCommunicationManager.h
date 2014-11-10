//
//  EatsCommunicationManager.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Singleton that gives access to MIDI and OSC managers

#import <Foundation/Foundation.h>
#import "EatsGridDevice.h"
#import "EatsMIDIManager.h"
#import <VVOSC/VVOSC.h>

@interface EatsCommunicationManager : NSObject

@property EatsMIDIManager   *midiManager;
@property OSCManager        *oscManager;

@property OSCInPort         *oscInPort;
@property OSCOutPort        *oscOutPort;
@property NSString          *oscInputPortLabel;
@property NSString          *oscOutputPortLabel;
@property NSString          *oscPrefix;

@property NSMutableArray    *availableGridDevices;

+ (id)sharedCommunicationManager;

- (BOOL) addAvailableGridDeviceOfType:(EatsGridType)gridType withLabel:(NSString *)label withDisplayName:(NSString *)displayName atPort:(int)port probablySupportsVariableBrightness:(BOOL)variableBrightness; // Returns YES if it actually added it
- (BOOL) removeAvailableGridDeviceOfType:(EatsGridType)gridType withLabel:(NSString *)label; // Returns YES if it actually removed it

@end
