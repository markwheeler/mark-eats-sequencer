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
        _midiManager = [[EatsMIDIManager alloc] init];
        NSLog(@"MIDI source: %@", _midiManager.virtualSource.name);
        NSLog(@"MIDI destination: %@", _midiManager.virtualDest.name);
        
        // Create OSC manager
        _oscManager = [[OSCManager alloc] initWithServiceType:@"_monome-osc._udp"];
        [_oscManager setInPortLabelBase:@"Mark Eats Seq"];
        
        // Set OSC defaults
        _oscInPort = nil;
        _oscOutPort = nil;
        _oscInputPortLabel = @"Mark Eats Sequencer input";
        _oscOutputPortLabel = @"Mark Eats Sequencer output";
        _oscPrefix = @"markeatsseq";

        // Create the OSC ports
        uint retries = 0;
        while (_oscInPort == nil && retries < 50) {
            _oscInPort = [_oscManager createNewInputForPort:12234 + retries withLabel:_oscInputPortLabel];
            retries++;
        }
        if (_oscInPort)
            NSLog(@"OSC in port: %hu", _oscInPort.port);
        else
            NSLog(@"Error creating OSC in port");
        retries = 0;
        while (_oscOutPort == nil && retries < 50) {
            _oscOutPort = [_oscManager createNewOutputToAddress:@"local" atPort:12234 + retries withLabel:_oscOutputPortLabel];
            retries++;
        }
        if (_oscOutPort)
            NSLog(@"OSC out port: %hu", _oscOutPort.port);
        else
            NSLog(@"Error creating OSC out port");

        NSLog(@"OSC prefix: %@", _oscPrefix);
    }
    
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
}

@end
