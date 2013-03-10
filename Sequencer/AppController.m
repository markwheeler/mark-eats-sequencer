//
//  AppController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "AppController.h"
#import "Preferences.h"

@interface AppController()

@property EatsCommunicationManager  *sharedCommunicationManager;
@property Preferences               *sharedPreferences;

@end


@implementation AppController

- (id) init
{
    self = [super init];
    if (self) {
        
        self.sharedPreferences = [Preferences sharedPreferences];
        
        // Defaults being set here for testing (replace with NSUserDefaults)
        self.sharedPreferences.sendMIDIClock = YES;
        self.sharedPreferences.midiClockSource = nil;
        self.sharedPreferences.gridWidth = 8;
        self.sharedPreferences.gridHeight = 8;
        
        
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



#pragma mark - Methods for sending input notifications

- (void) sendGridInputNotificationX:(uint)x Y:(uint)y down:(BOOL)down
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                         [NSNumber numberWithUnsignedInt:y], @"y",
                                                                         [NSNumber numberWithBool:down], @"down",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridInput"
                                                        object:self
                                                      userInfo:inputInfo];
}

- (void) sendButtonInputNotificationId:(uint)id down:(BOOL)down
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:id], @"id",
                                                                         [NSNumber numberWithBool:down], @"down",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ButtonInput"
                                                        object:self
                                                      userInfo:inputInfo];
}

- (void) sendValueInputNotificationId:(uint)id value:(float)value
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:id], @"id",
                                                                         [NSNumber numberWithFloat:value], @"value",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ValueInput"
                                                        object:self
                                                      userInfo:inputInfo];
}



#pragma mark - MIDI Manager delegate methods

- (void) setupChanged
{
    NSLog(@"%s", __func__);
    [self.preferencesController updateMIDI];
    [self.preferencesController updateGridControllers];
}

- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n
{
    NSLog(@"%s", __func__);
    
    //uint externalBPM = currentDocument.externalClockCalculator externalClockTick;
    //if(externalBPM)
    //    [currentDocument setBpm: externalBPM];
}



#pragma mark - OSC Manager notifications and delegate methods

- (void) oscOutputsChangedNotification:(NSNotification *)note
{
    NSLog(@"%s", __func__);
    [self.preferencesController updateGridControllers];
}

- (void) receivedOSCMessage:(OSCMessage *)o
{
    // Work out what to do with the message on the main thread
    [self performSelectorOnMainThread:@selector(processOSCMessage:)
                           withObject:o
                        waitUntilDone:NO];
}

- (void) processOSCMessage:(OSCMessage *)o
{
    // Pick out the messages we want to deal with
    
    // Size info
    
    if([[o address] isEqualTo:@"/sys/size"]) {
        NSMutableArray *sizeValues = [[NSMutableArray alloc] initWithCapacity:2];
        for (NSString *s in [o valueArray]) {
            [sizeValues addObject:[self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
        }
        [self.preferencesController gridControllerConnected:EatsGridType_Monome width:[sizeValues[0] intValue] height:[sizeValues[1] intValue]];
        
        
    // Other SerialOSC info (just skipping them for now)
        
    } else if([[o address] isEqualTo:@"/sys/host"]
              || [[o address] isEqualTo:@"/sys/port"]
              || [[o address] isEqualTo:@"/sys/prefix"]
              || [[o address] isEqualTo:@"/sys/rotation"]
              || [[o address] isEqualTo:@"/sys/id"]) {
        return;
        
        
    // Key presses from the monome
        
    } else if([[o address] isEqualTo:[NSString stringWithFormat:@"/%@/grid/key", self.sharedCommunicationManager.oscPrefix]]) {
        NSMutableArray *keyValues = [[NSMutableArray alloc] initWithCapacity:3];
        for (NSString *i in [o valueArray]) {
            [keyValues addObject:[self stripOSCValue:[NSString stringWithFormat:@"%@", i]]];
        }
        
        [self sendGridInputNotificationX:[keyValues[0] intValue]
                                       Y:[keyValues[1] intValue]
                                    down:[keyValues[2] intValue]];
        
    
    // Other OSC input addressed to us
        
    } else if([[o address] hasPrefix:[NSString stringWithFormat:@"/%@/", self.sharedCommunicationManager.oscPrefix]]) {
        if([o valueCount] > 1) {
            NSMutableString *miscValues = [[NSMutableString alloc] init];
            for (NSString *s in [o valueArray]) {
                [miscValues appendFormat:@"%@ ", [self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
            }
            NSLog(@"OSC received %@ %@", [o address], miscValues);
        } else if([o valueCount]) {
            NSLog(@"OSC received %@ %@", [o address], [self stripOSCValue:[NSString stringWithFormat:@"%@", [o value]]]);
        }
        
        // TODO: send buttonInput and valueInput notifications using methods above.
        
        
        
    // Anything else just gets logged (can probably ignore it)
        
    } else {
        if([o valueCount] > 1) {
            NSMutableString *miscValues = [[NSMutableString alloc] init];
            for (NSString *s in [o valueArray]) {
                [miscValues appendFormat:@"%@ ", [self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
            }
            NSLog(@"OSC received %@ %@", [o address], miscValues);
        } else if([o valueCount]) {
            NSLog(@"OSC received %@ %@", [o address], [self stripOSCValue:[NSString stringWithFormat:@"%@", [o value]]]);
        }
    }
    
}

- (NSString *) stripOSCValue:(NSString *)s
{
    // Find the value in the string
    NSArray *valueItems = [s componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@" >"]];
    return [valueItems[2] stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\""]];
}




#pragma mark - Interface actions

- (IBAction)PreferencesMenuItem:(NSMenuItem *)sender {
    [self.preferencesController showWindow:self];
}


@end
