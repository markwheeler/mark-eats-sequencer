//
//  EatsCommunicationManager.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsCommunicationManager.h"

@interface EatsCommunicationManager ()

@end


@implementation EatsCommunicationManager

+ (id)sharedCommunicationManager {
    static EatsCommunicationManager *sharedCommunicationManager = nil;
    @synchronized(self) {
        if (sharedCommunicationManager == nil)
            sharedCommunicationManager = [[self alloc] init];
    }
    return sharedCommunicationManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        
        // Create MIDI manager
        self.midiManager = [[EatsMIDIManager alloc] init];
        
        // Create OSC manager
        self.oscManager = [[OSCManager alloc] initWithServiceType:@"_monome-osc._udp"];
        [self.oscManager setInPortLabelBase:@"Mark Eats Seq"];
        
        // Set OSC defaults
        self.oscInPort = nil;
        self.oscOutPort = nil;
        self.oscInputPortLabel = @"Mark Eats Sequencer input";
        self.oscOutputPortLabel = @"Mark Eats Sequencer output";
        self.oscPrefix = @"markeatsseq";

        // Create the OSC ports
        uint retries = 0;
        while (self.oscInPort == nil && retries < 50) {
            self.oscInPort = [self.oscManager createNewInputForPort:12234 + retries withLabel:self.oscInputPortLabel];
            retries++;
        }
        if (self.oscInPort == nil)
            NSLog(@"Error creating OSC in port");
        retries = 0;
        while (self.oscOutPort == nil && retries < 50) {
            self.oscOutPort = [self.oscManager createNewOutputToAddress:@"local" atPort:12234 + retries withLabel:self.oscOutputPortLabel];
            retries++;
        }
        if (self.oscOutPort == nil)
            NSLog(@"Error creating OSC out port");

    }
    
    return self;
}

@end
