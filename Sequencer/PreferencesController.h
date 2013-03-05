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

@interface PreferencesController : NSWindowController

- (void)updateGridControllers;
- (void)updateMIDI;
- (void)gridControllerConnected:(EatsGridType)gridType width:(uint)w height:(uint)h;

@end
