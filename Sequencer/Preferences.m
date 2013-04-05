//
//  Preferences.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Preferences.h"

@implementation Preferences

#pragma mark - Public methods

+ (id) sharedPreferences
{
    static Preferences *sharedPreferences = nil;
    @synchronized(self) {
        if (sharedPreferences == nil)
            sharedPreferences = [[self alloc] init];
    }
    return sharedPreferences;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.gridWidth = 32;
        self.gridHeight = 32;
    }
    return self;
}

- (void) loadPreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    self.gridOSCLabel = [preferences objectForKey:@"gridOSCLabel"];
    self.gridMIDINode = [preferences objectForKey:@"gridMIDINode"];
    
    self.gridAutoConnect = [preferences boolForKey:@"gridAutoConnect"];
    self.gridSupportsVariableBrightness = [preferences boolForKey:@"gridSupportsVariableBrightness"];
    
    self.midiClockSource = [preferences objectForKey:@"midiClockSource"];
    self.sendMIDIClock = [preferences boolForKey:@"sendMIDIClock"];
    
    self.loopFromScrubArea = [preferences boolForKey:@"loopFromScrubArea"];
}

- (void) savePreferences
{    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    NSString *oscLabel = nil;
    VVMIDINode *midiNode = nil;
    if( self.gridAutoConnect ) {
        oscLabel = self.gridOSCLabel;
        midiNode = self.gridMIDINode;
    }
    [preferences setObject:oscLabel forKey:@"gridOSCLabel"];
    [preferences setObject:midiNode forKey:@"gridMIDINode"];
    
    [preferences setBool:self.gridAutoConnect forKey:@"gridAutoConnect"];
    [preferences setBool:self.gridSupportsVariableBrightness forKey:@"gridSupportsVariableBrightness"];
    
    [preferences setObject:self.midiClockSource forKey:@"midiClockSource"];
    [preferences setBool:self.sendMIDIClock forKey:@"sendMIDIClock"];
    
    [preferences setBool:self.loopFromScrubArea forKey:@"loopFromScrubArea"];
    
    [preferences synchronize];
}

@end
