//
//  EatsMonome.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsMonome.h"
#import "Preferences.h"

@interface EatsMonome ()

#define BRIGHTNESS_CUTOFF 7

@property Preferences   *sharedPreferences;

@end



@implementation EatsMonome

- (id) initWithOSCPort:(OSCOutPort *)port oscPrefix:(NSString *)prefix
{
    self = [super init];
    if (self) {
        
        self.oscOutPort = port;
        self.oscPrefix = prefix;
        
        self.sharedPreferences = [Preferences sharedPreferences];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setRotation:)
                                                     name:kGridControllerSetRotationNotification
                                                   object:nil];
        
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void) lookForMonomesAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort
{
    NSString *oldAddress = [outPort.addressString copy];
    short oldPort = outPort.port;
    
    // Set the port to local SerialOSC default and look there
    [outPort setAddressString:@"127.0.0.1" andPort:12002];
    
    OSCMessage *newMsg;
    
    // Get list
    newMsg = [OSCMessage createWithAddress:@"/serialosc/list"];
    [newMsg addString:@"localhost"];
    [newMsg addInt:[inPort port]];
    [outPort sendThisMessage:newMsg];
    
    // Return the port to it's previous settings
    [outPort setAddressString:oldAddress andPort:oldPort];

}

+ (void) beNotifiedOfMonomeChangesAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort
{
    NSString *oldAddress = [outPort.addressString copy];
    short oldPort = outPort.port;
    
    // Set the port to local SerialOSC default and look there
    [outPort setAddressString:@"127.0.0.1" andPort:12002];
    
    OSCMessage *newMsg;
    
    // Setup notify
    newMsg = [OSCMessage createWithAddress:@"/serialosc/notify"];
    [newMsg addString:@"localhost"];
    [newMsg addInt:[inPort port]];
    [outPort sendThisMessage:newMsg];
    
    // Return the port to it's previous settings
    [outPort setAddressString:oldAddress andPort:oldPort];
}

+ (void) connectToMonomeAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort withPrefix:(NSString *)prefix
{
    OSCMessage *newMsg;
    
    // Set host
    newMsg = [OSCMessage createWithAddress:@"/sys/host"];
    [newMsg addString:@"localhost"];
    [outPort sendThisMessage:newMsg];
    
    // Set port
    newMsg = [OSCMessage createWithAddress:@"/sys/port"];
    [newMsg addInt:[inPort port]];
    [outPort sendThisMessage:newMsg];
    
    // Set prefix
    newMsg = [OSCMessage createWithAddress:@"/sys/prefix"];
    [newMsg addString:prefix];
    [outPort sendThisMessage:newMsg];
    
    // Get info
    newMsg = [OSCMessage createWithAddress:@"/sys/info"];
    [newMsg addInt:[inPort port]];
    [outPort sendThisMessage:newMsg];
    
    // Enable tilt sensor
    newMsg = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/tilt/set", prefix]];
    [newMsg addInt:0];
    [newMsg addInt:1];
    [outPort sendThisMessage:newMsg];
}

+ (void) disconnectFromMonomeAtPort:(OSCOutPort *)outPort withPrefix:(NSString *)prefix
{
    OSCMessage *newMsg;
    
    // Disable tilt sensor
    newMsg = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/tilt/set", prefix]];
    [newMsg addInt:0];
    [newMsg addInt:0];
    [outPort sendThisMessage:newMsg];
    
    // Set port
    newMsg = [OSCMessage createWithAddress:@"/sys/port"];
    [newMsg addInt:999]; // Dummy port so we won't receive anything more
    [outPort sendThisMessage:newMsg];
    
    // Set prefix
    newMsg = [OSCMessage createWithAddress:@"/sys/prefix"];
    [newMsg addString:@"monome"];
    [outPort sendThisMessage:newMsg];
}


+ (BOOL) doesMonomeSupportVariableBrightness:(NSString *)serial
{
    // We want to see if the monome serial starts with m0000 or similar
    // See https://github.com/monome/libmonome/blob/master/src/private/devices.h for serial number patterns
    
    // Now we need to look for each of those above
    NSRange searchedRange = NSMakeRange( 0, serial.length );
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"m[0-9][0-9][0-9][0-9]" options:0 error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:serial options:0 range:searchedRange];
    
    if( match && match.range.location == 0 )
        return YES;
    else
        return NO;
}


- (void) redrawGridController:(NSArray *)gridArray
{
    // Cut up the complete 2D array into 8x8 1D arrays ready for sending to the monome
    
    // For each 8-wide block...
    for(int i = 0; i < [gridArray count] / 8; i ++) {
        
        // ...and for each 8-high block within those
        for( int j = 0; j < [[gridArray objectAtIndex:0] count] / 8; j ++ ) {
            
            // Create a 1D array that's going to get sent as a map
            NSMutableArray *levelsArray = [NSMutableArray arrayWithCapacity:64];
            
            for( int y = 8 * j; y < 8 * (j + 1); y ++ ) {
                for( uint x = 8 * i; x < 8 * (i + 1); x ++ ) {
                    
                    // TODO remove this debug code
                    if( [gridArray count] <= x ) {
                        NSLog( @"WARNING: gridArray count is %lu, trying to access %u", (unsigned long)[gridArray count], x );
                        NSLog( @"DUMP OF gridArray %@", gridArray );
                    }
                    if( [[gridArray objectAtIndex:x] count] <= y ) {
                        NSLog( @"WARNING: gridArray col %i count is %lu, tring to access %i", x, (unsigned long)[[gridArray objectAtIndex:x] count], y );
                        NSLog( @"DUMP OF gridArray %@", gridArray );
                    }
                    
                    [levelsArray addObject:[[gridArray objectAtIndex:x] objectAtIndex:y]];
                }
            }
            
            [self monomeLEDLevelMapXOffset:8 * i yOffset:8 * j levels:levelsArray];
        }
    }
    
}

- (void) clearGridController
{
    [self monomeLEDLevelAll:0];
}


#pragma mark - Private methods

- (void) setRotation:(NSNotification *)notification
{
//    NSLog(@"ROTATION TEST: Set rotation %i", self.sharedPreferences.gridRotation);
    
    // Create and send the OSC message
    OSCMessage *newMsg = [OSCMessage createWithAddress:@"/sys/rotation"];
    [newMsg addInt:self.sharedPreferences.gridRotation];
    [self.oscOutPort sendThisMessage:newMsg];
    
//    NSLog(@"ROTATION TEST: Set rotation done");
}

- (void) monomeLEDLevelSetX:(NSUInteger)x y:(NSUInteger)y level:(NSUInteger)l
{
    NSString *oscAddress;
    NSUInteger level;
    
    // Check what kind of monome we have and adjust accordingly (no code above this should need to worry about it)
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/set", self.oscPrefix];
        level = l;
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/set", self.oscPrefix];
        if(l > BRIGHTNESS_CUTOFF)
            level = 1;
        else
            level = 0;
    }
    
    // Create and send the OSC message
    OSCMessage *newMsg = [OSCMessage createWithAddress:oscAddress];
    [newMsg addInt:(unsigned)x];
    [newMsg addInt:(unsigned)y];
    [newMsg addInt:(unsigned)level];
    [self.oscOutPort sendThisMessage:newMsg];
}

- (void) monomeLEDLevelAll:(NSUInteger)l
{
    NSString *oscAddress;
    NSUInteger level;
    
    // Check what kind of monome we have and adjust accordingly (no code above this should need to worry about it)
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/all", self.oscPrefix];
        level = l;
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/all", self.oscPrefix];
        if(l > BRIGHTNESS_CUTOFF)
            level = 1;
        else
            level = 0;
    }
    
    // Create and send the OSC message
    OSCMessage *newMsg = [OSCMessage createWithAddress:oscAddress];
    [newMsg addInt:(unsigned)level];
    [self.oscOutPort sendThisMessage:newMsg];
}

- (void) monomeLEDLevelMapXOffset:(NSUInteger)x yOffset:(NSUInteger)y levels:(NSArray *)l;
{
    NSString *oscAddress;
    NSMutableArray *levels;
    
    // Check what kind of monome we have and adjust accordingly (no code above this should need to worry about it)
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/map", self.oscPrefix];
        levels = [NSMutableArray arrayWithArray:l];
        
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/map", self.oscPrefix];
        
        // Go through and make everything binary in a new array 'levels'
        levels = [NSMutableArray arrayWithCapacity:64];
        for( NSNumber *level in l ) {
            if( level.intValue > BRIGHTNESS_CUTOFF )
                [levels addObject:[NSNumber numberWithUnsignedInt:1]];
            else
                [levels addObject:[NSNumber numberWithUnsignedInt:0]];
        }
        
        levels = [self convertBinaryArrayToBitmask:levels];
        
    }
    
    // Create and send the OSC message
    OSCMessage *newMsg = [OSCMessage createWithAddress:oscAddress];
    [newMsg addInt:(unsigned)x];
    [newMsg addInt:(unsigned)y];
    for(NSNumber *level in levels) {
        [newMsg addInt:level.intValue];
    }
    
    [self.oscOutPort sendThisMessage:newMsg];
}

- (NSMutableArray *) convertBinaryArrayToBitmask:(NSArray *)binaryArray
{
    // This is used for sending stuff via /map on non vari-bright monomes
    // Should also work for /col and /row but untested
    
    NSMutableArray *bitMaskedLevels = [NSMutableArray arrayWithCapacity:8];
    NSMutableString *binaryRow = [NSMutableString stringWithCapacity:8];
    
    // Make an array of 8 rows of strings representing the binary
    for(int i = 0; i < [binaryArray count]; i += 8) {
        
        // For each bit in the row
        for(int j=0; j<8; j++) {
            [binaryRow insertString:[NSString stringWithFormat:@"%@", binaryArray[i+j]] atIndex:0];
        }
        
        // When we have a row we bitmask it and push it into that array
        [bitMaskedLevels addObject:[NSNumber numberWithLong:strtol( [binaryRow UTF8String], NULL, 2 )]];
        binaryRow = [NSMutableString string];
    }
    
    return bitMaskedLevels;
}

@end
