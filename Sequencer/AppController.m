//
//  AppController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "AppController.h"
#import "Preferences.h"
#import "EatsExternalClockCalculator.h"
#import "EatsMonome.h"
#import "EatsDocumentController.h"

@interface AppController()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsExternalClockCalculator   *externalClockCalculator;
@property NSTimer                       *gridControllerConnectionTimer;

@end


@implementation AppController

- (id) init
{
    self = [super init];
    if (self) {
        
        self.sharedPreferences = [Preferences sharedPreferences];
        [self.sharedPreferences loadPreferences];
        
        // Create the preferences window (makes it easier to keep it up to date)
        if(!self.preferencesController) {
            self.preferencesController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
            self.preferencesController.delegate = self;
        }
        
        // Get the comms manager for MIDI & OSC
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedCommunicationManager.midiManager.delegate = self;
        self.sharedCommunicationManager.oscManager.delegate = self;
        
        // Register to receive notifications that the list of OSC outputs has changed
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCInPortsChangedNotification object:nil];
        
        // Fake an outputs-changed notification to make sure my list of destinations updates (in case it refreshes before I'm awake)
        [self oscOutputsChangedNotification:nil];
        
        self.externalClockCalculator = [[EatsExternalClockCalculator alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        
        // Firing this with a delay just so all the windows have time to draw etc (might be a better approach but this works!)
        [self performSelector:@selector(checkForFirstRun) withObject:nil afterDelay:0.5];
    }
    
    return self;
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerNone" object:self];
    [self.sharedPreferences savePreferences];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

// TODO
- (void) sendButtonInputNotificationId:(uint)inputId down:(BOOL)down
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:inputId], @"inputId",
                                                                         [NSNumber numberWithBool:down], @"down",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ButtonInput"
                                                        object:self
                                                      userInfo:inputInfo];
}

- (void) sendValueInputNotificationId:(uint)inputId value:(float)value
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:inputId], @"inputId",
                                                                         [NSNumber numberWithFloat:value], @"value",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ValueInput"
                                                        object:self
                                                      userInfo:inputInfo];
}



#pragma mark – Public methods

- (void) gridControllerNone
{
    [self.gridControllerConnectionTimer invalidate];
    
    self.sharedPreferences.gridType = EatsGridType_None;
    self.sharedPreferences.gridWidth = 16;
    self.sharedPreferences.gridHeight = 16;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerNone" object:self];
}

- (void) gridControllerConnectToDeviceType:(NSNumber *)gridType withOSCLabelOrMIDINode:(id)labelOrNode
{
    if( gridType.intValue == EatsGridType_Monome ) {
        
        OSCOutPort *selectedPort = nil;
        
        selectedPort = [self.sharedCommunicationManager.oscManager findOutputWithLabel:(NSString *)labelOrNode];
        if (selectedPort == nil)
            return;
        
        // Set the OSC Out Port
        
        //NSLog(@"Selected OSC out address %@", [selectedPort addressString]);
        //NSLog(@"Selected OSC out port %@", [NSString stringWithFormat:@"%d",[selectedPort port]]);
        
        [self.sharedCommunicationManager.oscOutPort setAddressString:[selectedPort addressString] andPort:[selectedPort port]];
        
        self.sharedPreferences.gridOSCLabel = (NSString *)labelOrNode;
        self.sharedPreferences.gridMIDINodeName = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerConnecting" object:self];
        self.gridControllerConnectionTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                           target:self
                                                         selector:@selector(gridControllerConnectionTimeout:)
                                                         userInfo:nil
                                                          repeats:NO];
        
        [EatsMonome connectToMonomeAtPort:self.sharedCommunicationManager.oscOutPort
                                 fromPort:self.sharedCommunicationManager.oscInPort
                               withPrefix:self.sharedCommunicationManager.oscPrefix];
        
        
    } else if ( gridType.intValue == EatsGridType_Launchpad ) {
        
        // Connect using midiNode
        
    }
    
}

- (void) gridControllerConnectionTimeout:(NSTimer *)timer
{
    [self.gridControllerConnectionTimer invalidate];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerNone" object:self];
    self.sharedPreferences.gridOSCLabel = nil;
    self.sharedPreferences.gridMIDINodeName = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerConnectionError" object:self];
}

- (void) gridControllerConnected:(EatsGridType)gridType width:(uint)w height:(uint)h
{
    [self.gridControllerConnectionTimer invalidate];
    
    // Set the prefs, making sure the width is divisible by 8
    self.sharedPreferences.gridType = EatsGridType_Monome;
    self.sharedPreferences.gridWidth = w - (w % 8);
    self.sharedPreferences.gridHeight = h - (h % 8);
    
    // Fixed grid size for testing
//    self.sharedPreferences.gridWidth = 8;
//    self.sharedPreferences.gridHeight = 8;
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerConnected" object:self];
}



#pragma mark - MIDI Manager delegate methods

- (void) setupChanged
{
    //NSLog(@"%s", __func__);
    
    // Enable only the nodes that have been previously enabled
    NSArray *destNodeArray = [self.sharedCommunicationManager.midiManager.destArray lockCreateArrayCopy];
    
    for( VVMIDINode *node in destNodeArray ) {
        if( [self.sharedPreferences.enabledMIDIOutputNames containsObject:node.name] )
            node.enabled = YES;
        else
            node.enabled = NO;
    }
    
    if( ![self.sharedCommunicationManager.midiManager.sourceNodeNameArray containsObject:self.sharedPreferences.midiClockSourceName] && ![self.sharedCommunicationManager.midiManager.virtualSource.name isEqualToString:self.sharedPreferences.midiClockSourceName] ) {
        self.sharedPreferences.midiClockSourceName = nil;
    }
    
    [self.preferencesController updateMIDI];
}

- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)node
{
    //NSLog(@"%s", __func__);
    
    // If this message is from the clockSource MIDI node
    if([node.name isEqualToString:_sharedPreferences.midiClockSourceName]) {
        for (VVMIDIMessage *m in a) {
            if([m type] == VVMIDIStartVal) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalClockStart" object:self];
                
            } else if([m type] == VVMIDIContinueVal) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalClockContinue" object:self];
                
            } else if([m type] == VVMIDISongPosPointerVal) {
                if([m data1] == 0 && [m data2] == 0)
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalClockZero" object:self];
            }
            
            else if([m type] == VVMIDIStopVal) {
                [_externalClockCalculator resetExternalClock];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalClockStop" object:self];
                
            } else if([m type] == VVMIDIClockVal) {
                
                NSNumber *externalBPM = [_externalClockCalculator externalClockTick:m.timestamp];
                if( externalBPM.intValue >= 20 && externalBPM.intValue <= 300 ) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalClockBPM"
                                                                        object:self
                                                                      userInfo:[NSDictionary dictionaryWithObject:externalBPM forKey:@"bpm"]];
                }
                    
            }
        }
    }
}



#pragma mark - OSC Manager notifications and methods

- (void) oscOutputsChangedNotification:(NSNotification *)note
{
    // Auto-connect and make sure our device hasn't disappeared
    BOOL stillActive = NO;
    for(NSString *s in [self.sharedCommunicationManager.oscManager outPortLabelArray] ) {
        if( [s isEqualToString:self.sharedPreferences.gridOSCLabel] ) {
            stillActive = YES;
            [self gridControllerConnectToDeviceType:[NSNumber numberWithInt:EatsGridType_Monome ] withOSCLabelOrMIDINode:s];
        }
    }
    
    if( !stillActive )
       [self gridControllerNone];
    
    // Update the prefs window
    [self.preferencesController updateOSC];
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
        [self gridControllerConnected:EatsGridType_Monome width:[sizeValues[0] intValue] height:[sizeValues[1] intValue]];
        
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



#pragma mark - Private methods

- (void) checkForFirstRun
{
    // Check if this is a new install
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ( ![userDefaults valueForKey:@"version"] ) {
        [self showWelcomeMessage];
        // Add version number to NSUserDefaults for first version
        [userDefaults setFloat:[[NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"] floatValue] forKey:@"version"];
    }
    
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"version"] == [[NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"] floatValue] ) {
        // Same version, no need to do anything
        
    } else {
        [self showWelcomeMessage];
        // Update version number
        [userDefaults setFloat:[[NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"] floatValue] forKey:@"version"];
    }
}

- (void) showWelcomeMessage
{
    NSAlert *welcomeAlert = [NSAlert alertWithMessageText:@"Would you like to view the User Guide?"
                                            defaultButton:@"Open User Guide"
                                          alternateButton:@"Not now"
                                              otherButton:nil
                                informativeTextWithFormat:@"The User Guide is always available from the Help menu should you wish to view it another time."];
    
    NSInteger result = [welcomeAlert runModal];
    if (result == NSOKButton) {
        [self openUserGuide];
    }
}

- (void) openUserGuide
{
    // Open the user guide PDF from the bundle resources folder
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Mark Eats Sequencer User Guide" ofType:@"pdf"];
    
    if( ![[NSWorkspace sharedWorkspace] openFile:filePath] ) {
        NSLog(@"Failed to open file: %@",filePath);
    }

}



#pragma mark - Interface actions

- (IBAction) PreferencesMenuItem:(NSMenuItem *)sender
{
    [self.preferencesController showWindow:self];
}

- (IBAction) clearMenuItem:(NSMenuItem *)sender
{
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    [documentController.currentDocument clearPatternStartAlert];
}

- (IBAction)helpUserGuideMenuItem:(NSMenuItem *)sender
{
    [self openUserGuide];
}

- (IBAction)helpFeedbackMenuItem:(NSMenuItem *)sender
{
    NSURL *url = [NSURL URLWithString:@"http://markeats.uservoice.com"];
    if( ![[NSWorkspace sharedWorkspace] openURL:url] )
        NSLog(@"Failed to open url: %@",[url description]);
}

- (IBAction)helpWebsiteMenuItem:(NSMenuItem *)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.markeats.com"];
    if( ![[NSWorkspace sharedWorkspace] openURL:url] )
        NSLog(@"Failed to open url: %@",[url description]);
}

@end