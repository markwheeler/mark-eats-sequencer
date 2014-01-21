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
@property (nonatomic) NSTimer           *gridControllerConnectionTimer;

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
        
        [[BWQuincyManager sharedQuincyManager] setSubmissionURL:@"http://www.markeats.com/quincykit/crash_v200.php"];
        [[BWQuincyManager sharedQuincyManager] setCompanyName:@"Mark Eats"];
        [[BWQuincyManager sharedQuincyManager] setDelegate:self];
    }
    
    return self;
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerNoneNotification object:self];
    [self.sharedPreferences savePreferences];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Delegate for QuincyKit
- (void) showMainApplicationWindow
{
    // For Document based apps this should be empty
}



#pragma mark - Methods for sending input notifications

- (void) sendGridInputNotificationX:(uint)x Y:(uint)y down:(BOOL)down
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                         [NSNumber numberWithUnsignedInt:y], @"y",
                                                                         [NSNumber numberWithBool:down], @"down",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kInputGridNotification
                                                        object:self
                                                      userInfo:inputInfo];
}

// TODO: External control mapping
- (void) sendButtonInputNotificationId:(uint)inputId down:(BOOL)down
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:inputId], @"inputId",
                                                                         [NSNumber numberWithBool:down], @"down",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kInputButtonNotification
                                                        object:self
                                                      userInfo:inputInfo];
}

// TODO: External control mapping
- (void) sendValueInputNotificationId:(uint)inputId value:(float)value
{
    NSDictionary *inputInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:inputId], @"inputId",
                                                                         [NSNumber numberWithFloat:value], @"value",
                                                                         nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kInputValueNotification
                                                        object:self
                                                      userInfo:inputInfo];
}



#pragma mark – Public methods

- (void) gridControllerNone
{
    [self.gridControllerConnectionTimer invalidate];
    self.gridControllerConnectionTimer = nil;
    
    self.sharedPreferences.gridType = EatsGridType_None;
    self.sharedPreferences.gridWidth = 16;
    self.sharedPreferences.gridHeight = 16;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerNoneNotification object:self];
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
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectingNotification object:self];
        NSLog(@"Connecting to grid controller...");
        [self.gridControllerConnectionTimer invalidate];
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
    NSLog(@"Connecting to grid controller timed out");
    [self.gridControllerConnectionTimer invalidate];
    self.gridControllerConnectionTimer = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerNoneNotification object:self];
    self.sharedPreferences.gridOSCLabel = nil;
    self.sharedPreferences.gridMIDINodeName = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectionErrorNotification object:self];
}

- (void) gridControllerSetWidth:(uint)w height:(uint)h
{
    // Set the prefs, making sure the width is divisible by 8
    self.sharedPreferences.gridWidth = w - (w % 8);
    self.sharedPreferences.gridHeight = h - (h % 8);
    
    // Fixed grid size for testing
//    self.sharedPreferences.gridWidth = 8;
//    self.sharedPreferences.gridHeight = 8;
}

- (void) gridControllerConnected:(EatsGridType)gridType
{
    [self.gridControllerConnectionTimer invalidate];
    self.gridControllerConnectionTimer = nil;
    self.sharedPreferences.gridType = EatsGridType_Monome;
    
    if( self.sharedPreferences.tiltMIDIOutputChannel )
        [self gridControllerTiltSensor:[NSNumber numberWithBool:YES]];
    else
        [self gridControllerTiltSensor:[NSNumber numberWithBool:NO]];
    
    NSLog(@"Connected to grid controller: %@ / Size: %ux%u / Type: %i / Varibright: %i", self.sharedPreferences.gridOSCLabel, self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight, self.sharedPreferences.gridType, self.sharedPreferences.gridSupportsVariableBrightness);
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectedNotification object:self];
}

- (void) gridControllerTiltSensor:(NSNumber *)enable
{
    if( self.sharedPreferences.gridType == EatsGridType_Monome ) {
        [EatsMonome monomeTiltSensor:enable.boolValue atPort:self.sharedCommunicationManager.oscOutPort withPrefix:self.sharedCommunicationManager.oscPrefix];
    }
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
    if([node.name isEqualToString:self.sharedPreferences.midiClockSourceName]) {
        for (VVMIDIMessage *m in a) {
            if([m type] == VVMIDIStartVal) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockStartNotification object:self];
                
            } else if([m type] == VVMIDIContinueVal) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockContinueNotification object:self];
                
            } else if([m type] == VVMIDISongPosPointerVal) {
                if([m data1] == 0 && [m data2] == 0)
                    [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockZeroNotification object:self];
            }
            
            else if([m type] == VVMIDIStopVal) {
                [self.externalClockCalculator resetExternalClock];
                [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockStopNotification object:self];
                
            } else if([m type] == VVMIDIClockVal) {
                
                NSNumber *externalBPM = [self.externalClockCalculator externalClockTick:m.timestamp];
                if( externalBPM ) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockBPMNotification object:self userInfo:[NSDictionary dictionaryWithObject:externalBPM forKey:@"bpm"]];
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
            NSLog(@"Auto-connecting...");
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
    
    if( [o.address isEqualTo:@"/sys/size"] ) {
        NSMutableArray *sizeValues = [[NSMutableArray alloc] initWithCapacity:2];
        for ( NSString *s in  o.valueArray ) {
            [sizeValues addObject:[self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
        }
        
        [self gridControllerSetWidth:[sizeValues[0] intValue] height:[sizeValues[1] intValue]];
        
        if( self.gridControllerConnectionTimer )
            [self gridControllerConnected:EatsGridType_Monome];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerSizeChangedNotification object:self];
    
    
    // Rotation
    
    } else if( [o.address isEqualTo:@"/sys/rotation"] ) {
    
        if( o.valueCount == 1 ) {
            int rotation = [[self stripOSCValue:[NSString stringWithFormat:@"%@", o.value]] intValue];
            if( rotation >= 0 && rotation < 360 && rotation % 90 == 0 )
                self.sharedPreferences.gridRotation = rotation;
        }
        
        
    // Other SerialOSC info (just skipping them for now)
        
    } else if( [o.address isEqualTo:@"/sys/host"]
              || [o.address isEqualTo:@"/sys/port"]
              || [o.address isEqualTo:@"/sys/prefix"]
              || [o.address isEqualTo:@"/sys/id"] ) {
        return;
        
        
    // Key presses from the monome
        
    } else if( [o.address isEqualTo:[NSString stringWithFormat:@"/%@/grid/key", self.sharedCommunicationManager.oscPrefix]] ) {
        NSMutableArray *keyValues = [[NSMutableArray alloc] initWithCapacity:3];
        for( NSString *i in o.valueArray ) {
            [keyValues addObject:[self stripOSCValue:[NSString stringWithFormat:@"%@", i]]];
        }
        
        [self sendGridInputNotificationX:[keyValues[0] intValue]
                                       Y:[keyValues[1] intValue]
                                    down:[keyValues[2] intValue]];
    
    
    // Tilt from the monome
    
    } else if( [o.address isEqualTo:[NSString stringWithFormat:@"/%@/tilt", self.sharedCommunicationManager.oscPrefix]] ) {
        
        for( int i = 1; i < o.valueCount - 1; i ++ ) {
            // We ignore the last value, z, because it's not that fun. z just seems to measure 'how upside down' the monome is
            
            int tiltValue = [[self stripOSCValue:[NSString stringWithFormat:@"%@", [o.valueArray objectAtIndex:i]]] intValue];
            int tiltCenter;
            int tiltMin;
            int tiltMax;
            
            if( i == 1 ) { // x
                tiltCenter = self.sharedPreferences.gridTiltXCenter;
                tiltMin = self.sharedPreferences.gridTiltXMin;
                tiltMax = self.sharedPreferences.gridTiltXMax;
            } else { // y
                tiltCenter = self.sharedPreferences.gridTiltYCenter;
                tiltMin = self.sharedPreferences.gridTiltYMin;
                tiltMax = self.sharedPreferences.gridTiltYMax;
            }
            
            // Cut off anything over
            if( tiltValue > tiltMax )
                tiltValue = tiltMax;
            else if( tiltValue < tiltMin )
                tiltValue = tiltMin;
            
            int distanceFromCenter;
            int midiTiltValue;
            
            // Convert to 0-63
            if( tiltValue <= tiltCenter ) {
                distanceFromCenter = tiltCenter - tiltValue;
                midiTiltValue = 63 - roundf( 63.0 * ( (float)distanceFromCenter / ( tiltCenter - tiltMin ) ) );
            
            // or 64-127
            } else {
                distanceFromCenter = tiltValue - tiltCenter;
                midiTiltValue = 63 + roundf( 64.0 * ( (float)distanceFromCenter / ( tiltMax - tiltCenter ) ) );
            }
            
            //NSLog(@"Tilt axis %i conversion: %i -> %i", i, tiltValue, midiTiltValue);
            [self sendTiltFromAxis:i - 1 withValue:midiTiltValue];
        }
        
    
    // Other OSC input addressed to us is logged
        
    } else if([o.address hasPrefix:[NSString stringWithFormat:@"/%@/", self.sharedCommunicationManager.oscPrefix]]) {
        if(o.valueCount > 1) {
            NSMutableString *miscValues = [[NSMutableString alloc] init];
            for (NSString *s in [o valueArray]) {
                [miscValues appendFormat:@"%@ ", [self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
            }
            NSLog(@"OSC received %@ %@", o.address, miscValues);
        } else if(o.valueCount) {
            NSLog(@"OSC received %@ %@", o.address, [self stripOSCValue:[NSString stringWithFormat:@"%@", o.value]]);
        }
        
        // TODO: External control mapping. Send buttonInput and valueInput notifications using methods above.
        
        
    // Anything else just gets ignored
        
    } else {
        if(o.valueCount > 1) {
            NSMutableString *miscValues = [[NSMutableString alloc] init];
            for (NSString *s in o.valueArray) {
                [miscValues appendFormat:@"%@ ", [self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
            }
            //NSLog(@"OSC received %@ %@", [o address], miscValues);
        } else if([o valueCount]) {
            //NSLog(@"OSC received %@ %@", [o address], [self stripOSCValue:[NSString stringWithFormat:@"%@", [o value]]]);
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

- (void) sendTiltFromAxis:(int)axis withValue:(int)midiValue
{
    if( self.sharedPreferences.tiltMIDIOutputChannel ) {
        
        VVMIDIMessage *msg = nil;
        //	Create a message
        msg = [VVMIDIMessage createFromVals:VVMIDIControlChangeVal
                                           :self.sharedPreferences.tiltMIDIOutputChannel.intValue
                                           :1 + axis // Goes out on CC 1-3
                                           :midiValue
                                           timestamp:0];
        // Send it
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}



#pragma mark - Interface actions

- (IBAction) PreferencesMenuItem:(NSMenuItem *)sender
{
    [self.preferencesController showWindow:self];
}

- (IBAction)renamePageMenuItem:(NSMenuItem *)sender {
    EatsDocumentController *documentController = [EatsDocumentController sharedDocumentController];
    [documentController.currentDocument renameCurrentPageStartAlert];
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