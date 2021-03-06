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

typedef enum EatsMonomeSensorType {
    EatsMonomeSensorType_Old,
    EatsMonomeSensorType_New,
} EatsMonomeSensorType;

typedef enum EatsTiltDirection {
    EatsTiltDirection_Left,
    EatsTiltDirection_Right,
    EatsTiltDirection_Up,
    EatsTiltDirection_Down
} EatsTiltDirection;

@interface AppController()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsExternalClockCalculator   *externalClockCalculator;
@property (nonatomic) NSTimer           *gridControllerConnectionTimer;
@property (nonatomic) NSTimer           *gridControllerCalibrationTimer;

@property int                           gridTiltXCenter;
@property int                           gridTiltYCenter;
@property int                           gridTiltRange;
@property int                           gridTiltDeadZone;
@property BOOL                          gridTiltXIsInverted;
@property BOOL                          gridTiltYIsInverted;

@property BOOL                          askingUserForGridSize;

@property NSMutableSet                  *gridTiltSensorCalibrationData;

@property NSArray                       *lastTiltMIDISent; // Ints
@property NSArray                       *lastTiltValueSmoothed; // Floats

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
        
        self.externalClockCalculator = [[EatsExternalClockCalculator alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        
        [self gridControllerLookForDevices];
        
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
    [self gridControllerNone];
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
    
    EatsGridType needToDisconnect = EatsGridType_None;
    if( self.sharedPreferences.gridType == EatsGridType_Monome )
        needToDisconnect = self.sharedPreferences.gridType;
    
    self.sharedPreferences.gridType = EatsGridType_None;
    self.sharedPreferences.gridWidth = 16;
    self.sharedPreferences.gridHeight = 16;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerNoneNotification object:self];
    
    // If we're already connected to a monome then disconnect
    if( needToDisconnect == EatsGridType_Monome ) {
        NSLog(@"Disconnect from monome");
        [EatsMonome disconnectFromMonomeAtPort:self.sharedCommunicationManager.oscOutPort
                                    withPrefix:self.sharedCommunicationManager.oscPrefix];
    }
}

- (void) gridControllerConnectToDevice:(EatsGridDevice *)gridDevice
{
    if( gridDevice.type == EatsGridType_Monome ) {
        
        // Set the OSC out port and address
        [self.sharedCommunicationManager.oscOutPort setAddressString:@"127.0.0.1" andPort:gridDevice.port];
        
        self.sharedPreferences.gridMonomeId = gridDevice.label;
        self.sharedPreferences.gridMIDINodeName = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectingNotification object:self];
        NSLog(@"Connecting to grid controller...");
        [self.gridControllerConnectionTimer invalidate];
        self.gridControllerConnectionTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                           target:self
                                                         selector:@selector(gridControllerConnectionTimeout:)
                                                         userInfo:nil
                                                          repeats:NO];
        [self.gridControllerConnectionTimer setTolerance:0.5]; // High tolerance, not critical here
        
        [EatsMonome connectToMonomeAtPort:self.sharedCommunicationManager.oscOutPort
                                 fromPort:self.sharedCommunicationManager.oscInPort
                               withPrefix:self.sharedCommunicationManager.oscPrefix];
        
        
    } else if ( gridDevice.type == EatsGridType_Launchpad ) {
        
        // Connect using midiNode
        
    }
    
}

- (void) gridControllerConnectionTimeout:(NSTimer *)timer
{
    NSLog(@"Connecting to grid controller timed out");
    [self.gridControllerConnectionTimer invalidate];
    self.gridControllerConnectionTimer = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerNoneNotification object:self];
    self.sharedPreferences.gridMonomeId = nil;
    self.sharedPreferences.gridMIDINodeName = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectionErrorNotification object:self];
}

- (void) gridControllerSetWidth:(uint)w height:(uint)h
{
    self.sharedPreferences.gridWidth = w;
    self.sharedPreferences.gridHeight = h;
    
    // Fixed grid size for testing
//    self.sharedPreferences.gridWidth = 8;
//    self.sharedPreferences.gridHeight = 8;
}

- (void) gridControllerConnected:(EatsGridType)gridType
{
    [self.gridControllerConnectionTimer invalidate];
    self.gridControllerConnectionTimer = nil;
    self.sharedPreferences.gridType = EatsGridType_Monome;
    
    [self gridControllerTiltSensorStartCalibrating];
    
    NSLog(@"Connected to grid controller: %@ / Size: %ux%u / Type: %i / Varibright: %i", self.sharedPreferences.gridMonomeId, self.sharedPreferences.gridWidth, self.sharedPreferences.gridHeight, self.sharedPreferences.gridType, self.sharedPreferences.gridSupportsVariableBrightness);
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerConnectedNotification object:self];
}

- (void) gridControllerTiltSensorStartCalibrating
{
    // What type of grid do we have?
    if( self.sharedPreferences.gridType != EatsGridType_Monome ) {
        // These grids don't support tilt so we're done
        [self gridControllerTiltSensorDoneCalibrating];
        return;
    }
    
    // If we don't get enough data in time we just timeout
    [self.gridControllerCalibrationTimer invalidate];
    self.gridControllerCalibrationTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                                           target:self
                                                                         selector:@selector(gridControllerCalibrationTimeout:)
                                                                         userInfo:nil
                                                                          repeats:NO];
    [self.gridControllerCalibrationTimer setTolerance:0.5]; // High tolerance, not critical here
    
    // Reset all the calibration settings
    self.gridTiltSensorCalibrationData = [NSMutableSet set];
    self.gridTiltRange = 0;
    self.gridTiltDeadZone = 0;
    self.gridTiltXIsInverted = NO;
    self.gridTiltYIsInverted = NO;
    self.lastTiltValueSmoothed = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:0], [NSNumber numberWithFloat:0], [NSNumber numberWithFloat:0], nil];
    self.lastTiltMIDISent = [NSArray arrayWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], nil];
    
    self.sharedPreferences.gridTiltSensorIsCalibrating = YES;
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerCalibratingNotification object:self];
}

- (void) gridControllerTiltSensorDoneCalibrating
{
    [self.gridControllerCalibrationTimer invalidate];
    self.gridControllerCalibrationTimer = nil;
    
    if( self.sharedPreferences.gridType == EatsGridType_Monome ) {
        
        // Pull all the data into separate sets for easy processing
        NSMutableSet *xData = [NSMutableSet setWithCapacity:self.gridTiltSensorCalibrationData.count];
        NSMutableSet *yData = [NSMutableSet setWithCapacity:self.gridTiltSensorCalibrationData.count];
        NSMutableSet *zData = [NSMutableSet setWithCapacity:self.gridTiltSensorCalibrationData.count];
        
        for( NSDictionary *data in self.gridTiltSensorCalibrationData ) {
            [xData addObject:[data valueForKey:@"x"]];
            [yData addObject:[data valueForKey:@"y"]];
            [zData addObject:[data valueForKey:@"z"]];
        }
        
        EatsMonomeSensorType sensorType;
        
        // Work out the values
        if( self.gridTiltSensorCalibrationData.count ) {
            sensorType = [self monomeSensorTypeFromSetOfZTiltData:zData];
            self.gridTiltXCenter = [self rangedAverageFromSetOfTiltData:xData];
            self.gridTiltYCenter = [self rangedAverageFromSetOfTiltData:yData];
            
        // If we didn't get ANY calibration data, just use values that would likely be right for an old sensor type
        } else {
            NSLog(@"No tilt calibration data received, assuming default values");
            sensorType = EatsMonomeSensorType_Old;
            self.gridTiltXCenter = 126;
            self.gridTiltYCenter = 126;
        }
        
        // Set everything else depending on sensor type
        if( sensorType == EatsMonomeSensorType_Old ) {
            // Older monomes
            self.gridTiltRange = 35;
            self.gridTiltDeadZone = 2;
            self.gridTiltXIsInverted = YES;
            self.gridTiltYIsInverted = YES;
        } else {
            // Newer monomes
            self.gridTiltRange = 245;
            self.gridTiltDeadZone = 8;
            self.gridTiltXIsInverted = YES;
            self.gridTiltYIsInverted = NO;
        }
        
        NSLog(@"Calibrated tilt sensor to XCenter: %i / YCenter: %i / Range: %i / DeadZone: %i", self.gridTiltXCenter, self.gridTiltYCenter, self.gridTiltRange, self.gridTiltDeadZone);
    }
    
    self.sharedPreferences.gridTiltSensorIsCalibrating = NO;
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerDoneCalibratingNotification object:self];
}

- (void) gridControllerCalibrationTimeout:(NSTimer *)timer
{
    NSLog(@"Calibration of tilt sensor timed out");
    [self gridControllerTiltSensorDoneCalibrating];
}

- (int) rangedAverageFromSetOfTiltData:(NSSet *)data
{
    int total = 0;
    int min = 999;
    int max = -999;
    
    for( NSNumber *tiltValue in data ) {
        
        total += tiltValue.intValue;
        
        if( tiltValue.intValue < min ) min = tiltValue.intValue;
        if( tiltValue.intValue > max ) max = tiltValue.intValue;
    }
    
    // This is all to remove outliers and deal with both sensor types nicely
    
    // Calculate average to get the center
    float average = (float)total / data.count;
    
    // Re-calculate average within range
    total = 0;
    int totalRemoved = 0;
    int range = max - min;
    float rangePercentage = 0.5;
    
    for( NSNumber *tiltValue in data ) {
        
        if( tiltValue.intValue >= roundf( average - ( range * rangePercentage ) ) && tiltValue.intValue <= roundf( average + ( range * rangePercentage ) ) )
            total += tiltValue.intValue;
        else {
            totalRemoved ++;
            //NSLog(@"Removed value: %i because it fell outside of %f – %f", tiltValue.intValue, roundf( average - ( range * rangePercentage ) ), roundf( average + ( range * rangePercentage ) ) );
        }
    }
    
    float rangedAverage;
    
    // We check here just in case we somehow remove them all – we don't want to divide by zero so we take the regular average instead
    if( totalRemoved >= data.count ) {
        rangedAverage = average;
    } else {
        rangedAverage = (float)total / ( data.count - totalRemoved );
    }
    
    return roundf ( rangedAverage );
}

- (EatsMonomeSensorType) monomeSensorTypeFromSetOfZTiltData:(NSSet *)zData
{
    // If we find a value for z we definitely have a newer sensor
    // This will only fail to detect correctly if the monome is stood perfectly on edge
    
    for( OSCValue *obj in zData) {
        if( obj.intValue )
            return EatsMonomeSensorType_New;
    }
    return EatsMonomeSensorType_Old;
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
                
                uint64_t timeStamp = m.timestamp;
                if( !timeStamp )
                    timeStamp = mach_absolute_time() * _machTimeToNsFactor;
                
                NSNumber *externalBPM = [self.externalClockCalculator externalClockTick:timeStamp];
                if( externalBPM ) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kExternalClockBPMNotification object:self userInfo:[NSDictionary dictionaryWithObject:externalBPM forKey:@"bpm"]];
                }
                
            }
        }
    }
}



#pragma mark - OSC Manager notifications and methods


- (void) receivedOSCMessage:(OSCMessage *)o
{
    // Work out what to do with the message on the main thread
    [self performSelectorOnMainThread:@selector(processOSCMessage:)
                           withObject:[o copy]
                        waitUntilDone:NO];
}

- (void) processOSCMessage:(OSCMessage *)o
{
    
    // Log everything except tilt
//    if( ![o.address isEqualToString:@"/markeatsseq/tilt"] ) {
//        if( o.valueCount > 1 ) {
//            NSMutableString *miscValues = [[NSMutableString alloc] init];
//            for (NSString *s in [o valueArray]) {
//                [miscValues appendFormat:@"%@ ", [self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
//            }
//            NSLog(@"OSC received %@ %@", o.address, miscValues);
//            NSLog( @"valueArray: %@", o.valueArray );
//            
//        } else if(o.valueCount) {
//            NSLog(@"OSC received %@ %@", o.address, [self stripOSCValue:[NSString stringWithFormat:@"%@", o.value]]);
//            NSLog( @"value: %@", o.value );
//        }
//    }
    
    // Pick out the messages we want to deal with
    
    // Device or device added
    
    if( [o.address isEqualTo:@"/serialosc/device"] || [o.address isEqualTo:@"/serialosc/add"] ) {
        
        if( o.valueCount < 1 )
            return;
        
        NSString *monomeId = [self stripOSCValue:[NSString stringWithFormat:@"%@", [o.valueArray objectAtIndex:0]]];
        NSString *displayName = [NSString stringWithFormat:@"%@ (%@)", [[o.valueArray objectAtIndex:1] stringValue], monomeId];
        int monomePort = [[self stripOSCValue:[NSString stringWithFormat:@"%@", [o.valueArray objectAtIndex:2]]] intValue];
        
        BOOL didAdd = [self.sharedCommunicationManager addAvailableGridDeviceOfType:EatsGridType_Monome withLabel:monomeId withDisplayName:displayName atPort:monomePort probablySupportsVariableBrightness:[EatsMonome doesMonomeSupportVariableBrightness:monomeId]];
        
        if( didAdd )
            [self availableGridDevicesHaveChanged];
        
        // Keep receiving notifications
        if( [o.address isEqualTo:@"/serialosc/add"] ) {
            [EatsMonome beNotifiedOfMonomeChangesAtPort:self.sharedCommunicationManager.oscOutPort fromPort:self.sharedCommunicationManager.oscInPort];
        }
        
        
    // Device Removed
    } else if( [o.address isEqualTo:@"/serialosc/remove"] ) {
        
        if( o.valueCount < 1 )
            return;
        
        NSString *monomeId = [self stripOSCValue:[NSString stringWithFormat:@"%@", [o.valueArray objectAtIndex:0]]];
        
        BOOL didRemove = [self.sharedCommunicationManager removeAvailableGridDeviceOfType:EatsGridType_Monome withLabel:monomeId];
        
        if( didRemove )
            [self availableGridDevicesHaveChanged];
        
        [EatsMonome beNotifiedOfMonomeChangesAtPort:self.sharedCommunicationManager.oscOutPort fromPort:self.sharedCommunicationManager.oscInPort];
        
    
    // Size info
    
    } else if( [o.address isEqualTo:@"/sys/size"] ) {
        
        if( self.askingUserForGridSize )
            return;
        
        NSMutableArray *sizeValues = [[NSMutableArray alloc] initWithCapacity:2];
        for ( NSString *s in  o.valueArray ) {
            [sizeValues addObject:[self stripOSCValue:[NSString stringWithFormat:@"%@", s]]];
        }
        
        int width = [sizeValues[0] intValue];
        int height = [sizeValues[1] intValue];
        
        // Did we get an invalid size?
        if( width <= 0 || width % 8 || width > 16 || height <= 0 || height % 8 || height > 16 ) {
            
            NSLog(@"WARNING: Monome returned size: %ix%i", width, height);
            
            self.askingUserForGridSize = YES;
            
            // Bring up an alert to get the user to set the grid size manually
            NSPopUpButton *gridSizePopupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect( 0, 0, 180, 26 )];
            [gridSizePopupButton removeAllItems];
            [gridSizePopupButton addItemWithTitle:@"8x8 (64)"];
            [gridSizePopupButton addItemWithTitle:@"16x8 (128 horizontal)"];
            [gridSizePopupButton addItemWithTitle:@"8x16 (128 vertical)"];
            [gridSizePopupButton addItemWithTitle:@"16x16 (256)"];
            
            NSAlert *askGridSizeAlert = [NSAlert alertWithMessageText:@"What size is your grid?"
                                                    defaultButton:@"OK"
                                                  alternateButton:nil
                                                      otherButton:nil
                                        informativeTextWithFormat:@"Sequencer could not detect the grid size automatically. Sometimes this problem is fixed by disconnecting and reconnecting the USB cable."];
            
            [askGridSizeAlert setAccessoryView:gridSizePopupButton];
            
            NSInteger result = [askGridSizeAlert runModal];
            
            if (result == NSOKButton) {
                if( gridSizePopupButton.indexOfSelectedItem == 1 ) {
                    width = 16;
                    height = 8;
                } else if( gridSizePopupButton.indexOfSelectedItem == 2 ) {
                    width = 8;
                    height = 16;
                } else if( gridSizePopupButton.indexOfSelectedItem == 3 ) {
                    width = 16;
                    height = 16;
                } else {
                    width = 8;
                    height = 8;
                }
            }
            
            self.askingUserForGridSize = NO;
            
            NSLog(@"User selected size: %ix%i", width, height);
        }
        
        [self gridControllerSetWidth:width height:height];
        
        if( self.gridControllerConnectionTimer )
            [self gridControllerConnected:EatsGridType_Monome];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerSizeChangedNotification object:self];
    
    
    // Rotation
    
    } else if( [o.address isEqualTo:@"/sys/rotation"] ) {
    
        if( o.valueCount == 1 ) {
            int rotation = [[self stripOSCValue:[NSString stringWithFormat:@"%@", o.value]] intValue];
//            NSLog(@"ROTATION TEST: Received rotation %i", rotation);
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
//        if( [keyValues[2] intValue] )
//            NSLog(@"ROTATION TEST: Key down %i %i", [keyValues[0] intValue], [keyValues[1] intValue]);
    
    
    // Tilt from the monome
    
    } else if( [o.address isEqualTo:[NSString stringWithFormat:@"/%@/tilt", self.sharedCommunicationManager.oscPrefix]] ) {
        
        //NSLog(@"Tilt x: %i y: %i z: %i", [o.valueArray[1] intValue], [o.valueArray[2] intValue], [o.valueArray[3] intValue]);
        
        // Calibrate
        if( self.sharedPreferences.gridTiltSensorIsCalibrating ) {
            
            // Save it all to process once we have enough
            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:o.valueArray[1], @"x",
                                                                            o.valueArray[2], @"y",
                                                                            o.valueArray[3], @"z",
                                                                            nil];
            [self.gridTiltSensorCalibrationData addObject:data];
            
            // How much data to collect before we end calibration
            if( self.gridTiltSensorCalibrationData.count >= 12 )
                [self gridControllerTiltSensorDoneCalibrating];
        
        // Send it out
        } else if( self.sharedPreferences.tiltMIDIOutputChannel && self.gridTiltRange ) {
        
            // Convert the monome values into MIDI values based on calibrated min/max/center
            
            for( int i = 1; i < o.valueCount - 1; i ++ ) {
                // We ignore the last value, z, because it's not that fun. z just seems to measure how 'upside down' the monome is

                int tiltValue = [[self stripOSCValue:[NSString stringWithFormat:@"%@", [o.valueArray objectAtIndex:i]]] intValue];
                int tiltCenter;

                if( i == 1 ) { // x
                    tiltCenter = self.gridTiltXCenter;
                } else { // y
                    tiltCenter = self.gridTiltYCenter;
                }
                
                int tiltMin = tiltCenter - self.gridTiltRange;
                int tiltMax = tiltCenter + self.gridTiltRange;
                
                // Cut off anything over
                if( tiltValue > tiltMax )
                    tiltValue = tiltMax;
                else if( tiltValue < tiltMin )
                    tiltValue = tiltMin;
                
                int distanceFromCenter;
                float tiltValueA;
                float tiltValueB;
                
                // We split the tilt across 4 MIDI CCs so that they all send 0 when the monome is flat
                
                // CC A
                if( tiltValue <= tiltCenter - self.gridTiltDeadZone ) {
                    distanceFromCenter = tiltCenter - tiltValue - self.gridTiltDeadZone;
                    tiltValueA = (float)distanceFromCenter / ( tiltCenter - self.gridTiltDeadZone - tiltMin );
                    tiltValueB = 0.0;
                
                // CC B
                } else if( tiltValue >= tiltCenter + self.gridTiltDeadZone ) {
                    distanceFromCenter = tiltValue - tiltCenter - self.gridTiltDeadZone;
                    tiltValueA = 0.0;
                    tiltValueB = (float)distanceFromCenter / ( tiltMax - tiltCenter - self.gridTiltDeadZone );
                
                // in the deadzone
                } else {
                    tiltValueA = 0.0;
                    tiltValueB = 0.0;
                }
                
                // Invert if need be
                if( ( i == 1 && self.gridTiltXIsInverted ) || ( i == 2 && self.gridTiltYIsInverted ) ) {
                    float tempMidiValue = tiltValueA;
                    tiltValueA = tiltValueB;
                    tiltValueB = tempMidiValue;
                }
                
                // Map the directions correctly to the order we store the destinations in preferences
                EatsTiltDirection tiltDirectionIdA = 0;
                EatsTiltDirection tiltDirectionIdB = 0;
                
                // Map to line up with grid rotation
                if( self.sharedPreferences.gridRotation == 0 ) {
                    if( i == 1 ) {
                        tiltDirectionIdA = EatsTiltDirection_Left;
                        tiltDirectionIdB = EatsTiltDirection_Right;
                    } else if( i == 2 ) {
                        tiltDirectionIdA = EatsTiltDirection_Down;
                        tiltDirectionIdB = EatsTiltDirection_Up;
                    }
                } else if( self.sharedPreferences.gridRotation == 90 ) {
                    if( i == 1 ) {
                        tiltDirectionIdA = EatsTiltDirection_Up;
                        tiltDirectionIdB = EatsTiltDirection_Down;
                    } else if( i == 2 ) {
                        tiltDirectionIdA = EatsTiltDirection_Left;
                        tiltDirectionIdB = EatsTiltDirection_Right;
                    }
                } else if( self.sharedPreferences.gridRotation == 180 ) {
                    if( i == 1 ) {
                        tiltDirectionIdA = EatsTiltDirection_Right;
                        tiltDirectionIdB = EatsTiltDirection_Left;
                    } else if( i == 2 ) {
                        tiltDirectionIdA = EatsTiltDirection_Up;
                        tiltDirectionIdB = EatsTiltDirection_Down;
                    }
                } else if( self.sharedPreferences.gridRotation == 270 ) {
                    if( i == 1 ) {
                        tiltDirectionIdA = EatsTiltDirection_Down;
                        tiltDirectionIdB = EatsTiltDirection_Up;
                    } else if( i == 2 ) {
                        tiltDirectionIdA = EatsTiltDirection_Right;
                        tiltDirectionIdB = EatsTiltDirection_Left;
                    }
                }
                
                uint tiltDestinationIdA = [self.sharedPreferences.tiltMIDIOutputDestinations[tiltDirectionIdA] intValue];
                uint tiltDestinationIdB = [self.sharedPreferences.tiltMIDIOutputDestinations[tiltDirectionIdB] intValue];
                
                if( tiltDestinationIdA ) {
                    NSDictionary *tiltDestinationA = self.sharedPreferences.modulationDestinationsArray[tiltDestinationIdA];
                    [self sendMIDITiltValue:tiltValueA
                                     ofType:[[tiltDestinationA objectForKey:@"type"] unsignedIntValue]
                         toControllerNumber:[[tiltDestinationA objectForKey:@"controllerNumber"] unsignedIntValue]
                     fromTiltDirection:tiltDirectionIdA];
                }
                if( tiltDestinationIdB ) {
                    NSDictionary *tiltDestinationB = self.sharedPreferences.modulationDestinationsArray[tiltDestinationIdB];
                    [self sendMIDITiltValue:tiltValueB
                                     ofType:[[tiltDestinationB objectForKey:@"type"] unsignedIntValue]
                         toControllerNumber:[[tiltDestinationB objectForKey:@"controllerNumber"] unsignedIntValue]
                          fromTiltDirection:tiltDirectionIdB];
                }
            }
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


- (void) gridControllerLookForDevices
{
    [EatsMonome lookForMonomesAtPort:self.sharedCommunicationManager.oscOutPort fromPort:self.sharedCommunicationManager.oscInPort];
    [EatsMonome beNotifiedOfMonomeChangesAtPort:self.sharedCommunicationManager.oscOutPort fromPort:self.sharedCommunicationManager.oscInPort];
}

- (void) availableGridDevicesHaveChanged
{
    // Auto-connect and make sure our device hasn't disappeared
    BOOL stillActive = NO;
    
    for( EatsGridDevice *gridDevice in self.sharedCommunicationManager.availableGridDevices ) {
        if( gridDevice.type == EatsGridType_Monome && [gridDevice.label isEqualToString:self.sharedPreferences.gridMonomeId] ) {
            stillActive = YES;
            if( self.sharedPreferences.gridType == EatsGridType_None ) {
                NSLog(@"Auto-connecting...");
                [self gridControllerConnectToDevice:gridDevice];
            }
        }
    }
    
    if( !stillActive )
        [self gridControllerNone];
    
    // Update the prefs window
    [self.preferencesController updateAvailableGridDevices];
}

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

- (void) sendMIDITiltValue:(float)value
                    ofType:(VVMIDIMsgType)type
        toControllerNumber:(uint)controllerNumber
         fromTiltDirection:(EatsTiltDirection)directionId
{
    if( self.sharedPreferences.tiltMIDIOutputChannel ) {
        
        // Are the same CCs mapped on both directions on this axis?
        BOOL hasPairedMapping = NO;
        int pairId;
        if( directionId == EatsTiltDirection_Left || directionId == EatsTiltDirection_Up )
            pairId = directionId + 1;
        else
            pairId = directionId - 1;
            
        if( [self.sharedPreferences.tiltMIDIOutputDestinations[directionId] intValue] == [self.sharedPreferences.tiltMIDIOutputDestinations[pairId] intValue] )
            hasPairedMapping = YES;
        
        // Center on grid flat for pitch bend or a paired mapping
        if( type == VVMIDIPitchWheelVal || hasPairedMapping ) {
            value *= 0.5;
            if( directionId == EatsTiltDirection_Right || directionId == EatsTiltDirection_Up )
                value += 0.5;
            else
                value = 0.5 - value;
        }
        
        // Smooth using a weighted average with the previous value (a simple low pass filter)
        float last = [self.lastTiltValueSmoothed[directionId] floatValue];
        
        float alpha = 0.5; // Weight: 1 = no smoothing, 0 = will never move from previous value
        float smoothed = (alpha * value) + ( (1.0 - alpha) * last );
        
        
            // Create a message
            VVMIDIMessage *msg = nil;
            uint midiValue;
        
            if( type == VVMIDIPitchWheelVal ) {
                
                midiValue = roundf( SEQUENCER_MIDI_MAX_14_BIT * smoothed ); // 0-16383 is the range of the 14bit number pitch bend accepts
                
                // Check if we just sent the same value
                if( midiValue != [[self.lastTiltMIDISent objectAtIndex:directionId] intValue] ) {
                    uint leastSignificant = midiValue & 0x7F;
                    uint mostSignificant = ( midiValue >> 7 ) & 0x7F;
                    msg = [VVMIDIMessage createFromVals:type :self.sharedPreferences.tiltMIDIOutputChannel.intValue :leastSignificant :mostSignificant :-1];
                }
                
            } else if( type == VVMIDIChannelPressureVal ) {
                
                midiValue = roundf ( SEQUENCER_MIDI_MAX * smoothed );
                
                // Check if we just sent the same value
                if( midiValue != [[self.lastTiltMIDISent objectAtIndex:directionId] intValue] ) {
                    msg = [VVMIDIMessage createFromVals:type :self.sharedPreferences.tiltMIDIOutputChannel.intValue :roundf( SEQUENCER_MIDI_MAX * value ) :-1 :-1];
                }
                
            } else {
                
                midiValue = roundf ( SEQUENCER_MIDI_MAX * smoothed );
                
                // Check if we just sent the same value
                if( midiValue != [[self.lastTiltMIDISent objectAtIndex:directionId] intValue] ) {
                    msg = [VVMIDIMessage createFromVals:type :self.sharedPreferences.tiltMIDIOutputChannel.intValue :controllerNumber :roundf( SEQUENCER_MIDI_MAX * value ) :-1];
                }
            }
            
            // Send it
            if( msg != nil )
                [_sharedCommunicationManager.midiManager sendMsg:msg];

        
        // Save it
        NSMutableArray *newLastTiltMIDISent = [self.lastTiltMIDISent mutableCopy];
        NSMutableArray *newLastTiltValueSmoothed = [self.lastTiltValueSmoothed mutableCopy];
        
        [newLastTiltMIDISent replaceObjectAtIndex:directionId withObject:[NSNumber numberWithUnsignedInt:midiValue]];
        [newLastTiltValueSmoothed replaceObjectAtIndex:directionId withObject:[NSNumber numberWithFloat:smoothed]];
        
        self.lastTiltMIDISent = [newLastTiltMIDISent copy];
        self.lastTiltValueSmoothed = [newLastTiltValueSmoothed copy];
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