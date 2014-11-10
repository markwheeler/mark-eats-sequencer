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
#import "EatsGridDevice.h"

@protocol PreferencesControllerDelegateProtocol

- (void) gridControllerNone;
- (void) gridControllerConnectToDevice:(NSDictionary *)gridDevice;

@end


@interface PreferencesController : NSWindowController

@property (nonatomic, weak) id delegate;

@property (nonatomic) NSMutableArray              *inputMappingData;

- (void) updateAvailableGridDevices;
- (void) updateMIDI;

@end
