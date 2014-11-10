//
//  AppController.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PreferencesController.h"
#import "EatsGridDevice.h"
#import <VVMIDI/VVMIDI.h>
#import <Quincy/BWQuincyManager.h>
#import "EatsCommunicationManager.h"

@interface AppController : NSObject <VVMIDIDelegateProtocol, PreferencesControllerDelegateProtocol, BWQuincyManagerDelegate>

@property PreferencesController *preferencesController;

// Preferences controller delegate methods
- (void) gridControllerNone;
- (void) gridControllerConnectToDevice:(EatsGridDevice *)gridDevice;

// MIDI delegate methods
- (void) setupChanged;
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n;

@end
