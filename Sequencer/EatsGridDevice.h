//
//  EatsGridDevice.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/11/2014.
//  Copyright (c) 2014 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <VVMIDI/VVMIDINode.h>

typedef enum EatsGridType{
    EatsGridType_None,
    EatsGridType_Monome,
    EatsGridType_Launchpad
} EatsGridType;

@interface EatsGridDevice : NSObject

@property EatsGridType                  type;
@property NSString                      *label;
@property NSString                      *displayName;
@property BOOL                          probablySupportsVariableBrightness;
@property int                           port;
//@property VVMIDINode                    *midiNode; // For future, if MIDI grid controller support is added

@end
