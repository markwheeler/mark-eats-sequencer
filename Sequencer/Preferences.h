//
//  Preferences.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EatsGridDevice.h"
#import <VVOSC/VVOSC.h>
#import <VVMIDI/VVMIDI.h>

@interface Preferences : NSObject

@property uint              gridWidth;
@property uint              gridHeight;
@property EatsGridType      gridType;
@property BOOL              gridTiltSensorIsCalibrating;

@property NSString          *gridMonomeId;
@property NSString          *gridMIDINodeName;

@property BOOL              gridAutoConnect;
@property BOOL              gridSupportsVariableBrightness;
@property uint              gridRotation;

@property NSMutableArray    *inputMappings;

@property NSMutableArray    *enabledMIDIOutputNames;

@property NSNumber          *tiltMIDIOutputChannel;
@property NSArray           *tiltMIDIOutputDestinations;

@property NSString          *midiClockSourceName;
@property BOOL              sendMIDIClock;

@property BOOL              showNoteLengthOnGrid;
@property BOOL              loopFromScrubArea;
@property NSNumber          *defaultMIDINoteVelocity;

@property NSArray           *modulationDestinationsArray;

+ (id) sharedPreferences;
- (void) loadPreferences;
- (void) savePreferences;

@end
