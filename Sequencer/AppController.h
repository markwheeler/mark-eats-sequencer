//
//  AppController.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PreferencesController.h"
#import <VVMIDI/VVMIDI.h>
#import "EatsCommunicationManager.h"

@interface AppController : NSObject <VVMIDIDelegateProtocol>

@property PreferencesController *preferencesController;

// MIDI delegate methods
- (void) setupChanged;
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n;

@end
