//
//  AppController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "AppController.h"

@interface AppController()

@property EatsCommunicationManager *sharedCommunicationManager;

@end


@implementation AppController

- (id)init
{
    self = [super init];
    if (self) {
        
        // Get the comms manager for MIDI & OSC
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        [self.sharedCommunicationManager.midiManager setDelegate:self];
        [self.sharedCommunicationManager.oscManager setDelegate:self];
        
        // Register to receive notifications that the list of OSC outputs has changed
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCInPortsChangedNotification object:nil];
        
        // Create the preferences window (makes it easier to keep it up to date)
        if(!self.preferencesController) {
            self.preferencesController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
        }
        
        // Fake an outputs-changed notification to make sure my list of destinations updates (in case it refreshes before I'm awake)
        [self oscOutputsChangedNotification:nil];
    }
    
    return self;
}



#pragma mark - MIDI Manager delegate methods

- (void) setupChanged
{
    NSLog(@"%s", __func__);
    [self.preferencesController updateMIDI];
}

- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n
{
    NSLog(@"%s", __func__);
    
    //uint externalBPM = currentDocument.externalClockCalculator externalClockTick;
    //if(externalBPM)
    //    [currentDocument setBpm: externalBPM];
}



#pragma mark - OSC Manager notifications

- (void) oscOutputsChangedNotification:(NSNotification *)note
{
    NSLog(@"%s", __func__);
    [self.preferencesController updateGridControllers];
}



#pragma mark - Interface actions

- (IBAction)PreferencesMenuItem:(NSMenuItem *)sender {
    [self.preferencesController showWindow:self];
}


@end
