//
//  PreferencesController.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Preferences.h"
#import "EatsCommunicationManager.h"

@protocol PreferencesControllerDelegateProtocol

- (void) gridControllerNone;
- (void) gridControllerConnectToDeviceType:(NSNumber *)gridType withOSCLabelOrMIDINode:(id)labelOrNode;

@end


@interface PreferencesController : NSWindowController

@property (nonatomic, weak) id delegate;

@property (nonatomic) NSMutableArray              *inputMappingData;

- (void) updateOSC;
- (void) updateMIDI;

@end
