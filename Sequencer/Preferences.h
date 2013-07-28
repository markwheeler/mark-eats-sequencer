//
//  Preferences.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VVOSC/VVOSC.h>
#import <VVMIDI/VVMIDI.h>

typedef enum EatsGridType{
    EatsGridType_None,
    EatsGridType_Monome,
    EatsGridType_Launchpad
} EatsGridType;

@interface Preferences : NSObject

@property uint              gridWidth;
@property uint              gridHeight;
@property EatsGridType      gridType;
@property NSString          *gridOSCLabel;
@property NSString          *gridMIDINodeName;

@property BOOL              gridAutoConnect;
@property BOOL              gridSupportsVariableBrightness;

@property NSMutableArray    *enabledMIDIOutputNames;

@property NSString          *midiClockSourceName;
@property BOOL              sendMIDIClock;

@property BOOL              loopFromScrubArea;
@property NSNumber          *defaultMIDINoteVelocity;

+ (id) sharedPreferences;
- (void) loadPreferences;
- (void) savePreferences;

@end
