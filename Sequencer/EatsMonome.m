//
//  EatsMonome.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsMonome.h"

@interface EatsMonome ()

#define BRIGHTNESS_CUTOFF 7

@property BOOL monomeSupportsVariableBrightness;

@end



@implementation EatsMonome

- (id) initWithOSCPort:(OSCOutPort *)port oscPrefix:(NSString *)prefix
{
    self = [super init];
    if (self) {
        
        self.oscOutPort = port;
        self.oscPrefix = prefix;
        
    }
    return self;
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
    
    // Set rotation to zero (other rotations aren't supported for now)
    newMsg = [OSCMessage createWithAddress:@"/sys/rotation"];
    [newMsg addInt:0];
    [outPort sendThisMessage:newMsg];
    
    // Get info
    newMsg = [OSCMessage createWithAddress:@"/sys/info"];
    [newMsg addInt:[inPort port]];
    [outPort sendThisMessage:newMsg];
}

- (void) redrawGridController:(NSArray *)gridArray
{
    
    // Cut up the complete 2D array into 8x8 1D arrays ready for sending to the monome
    
    // For each 8-wide block...
    for(int i = 0; i < [gridArray count] / 8; i++) {
        
        // ...and for each 8-high block within those
        for(int j = 0; j < [[gridArray objectAtIndex:0] count] / 8; j++) {
            
            // Create a 1D array that's going to get sent as a map
            NSMutableArray *levelsArray = [NSMutableArray arrayWithCapacity:64];
            
            for(int y = 0 + 8 * j; y < 8 * (j + 1); y++) {
                for(NSUInteger x = 0 + 8 * i; x < 8 * (i + 1); x++) {
                    [levelsArray addObject:[[gridArray objectAtIndex:x] objectAtIndex:y]];
                }
            }
            
            [self monomeLEDLevelMapXOffset:0 + 8 * i yOffset:0 + 8 * j levels:levelsArray];
        }
    }
    
}

- (void) clearGridController
{
    [self monomeLEDLevelAll:0];
}


#pragma mark - Private methods

- (void) monomeLEDLevelSetX:(NSUInteger)x y:(NSUInteger)y level:(NSUInteger)l
{
    NSString *oscAddress;
    NSUInteger level;
    
    // Check what kind of monome we have and adjust accordingly (no code above this should need to worry about it)
    if(self.monomeSupportsVariableBrightness) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/set", self.oscPrefix];
        level = l;
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/set", self.oscPrefix];
        if(l > BRIGHTNESS_CUTOFF) level = 1;
        else level = 0;
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
    if(self.monomeSupportsVariableBrightness) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/all", self.oscPrefix];
        level = l;
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/all", self.oscPrefix];
        if(l > BRIGHTNESS_CUTOFF) level = 1;
        else level = 0;
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
    if(self.monomeSupportsVariableBrightness) {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/level/map", self.oscPrefix];
        levels = [NSMutableArray arrayWithArray:l];
        
    } else {
        oscAddress = [NSString stringWithFormat:@"/%@/grid/led/map", self.oscPrefix];
        
        // Go through and make everything binary in a new array 'levels'
        levels = [NSMutableArray arrayWithCapacity:64];
        for(NSNumber *level in l) {
            if([level intValue] > BRIGHTNESS_CUTOFF)
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
        [newMsg addInt:[level intValue]];
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
        [bitMaskedLevels addObject:[NSNumber numberWithLong:strtol([binaryRow UTF8String], NULL, 2)]];
        binaryRow = [NSMutableString string];
    }
    
    return bitMaskedLevels;
}

@end
