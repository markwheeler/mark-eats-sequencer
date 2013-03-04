//
//  PreferencesController.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EatsCommunicationManager.h"

@interface PreferencesController : NSWindowController

@property EatsCommunicationManager *sharedCommunicationManager;

- (void)updateGridControllers;
- (void)updateMIDI;

@end
