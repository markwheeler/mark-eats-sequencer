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

- (NSDictionary *) defaultPreferences
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"gridAutoConnect", nil];
}

- (void) loadPreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    // Default values
    [preferences registerDefaults:[self defaultPreferences]];
    
    // Load user settings
    self.gridOSCLabel = [preferences objectForKey:@"gridOSCLabel"];
    self.gridMIDINodeName = [preferences objectForKey:@"gridMIDINodeName"];
    
    self.gridAutoConnect = [preferences boolForKey:@"gridAutoConnect"];
    self.gridSupportsVariableBrightness = [preferences boolForKey:@"gridSupportsVariableBrightness"];
    
    self.midiClockSourceName = [preferences objectForKey:@"midiClockSourceName"];
    self.sendMIDIClock = [preferences boolForKey:@"sendMIDIClock"];
    
    if( [preferences arrayForKey:@"enabledMIDIOutputNames"] )
        self.enabledMIDIOutputNames = [[preferences arrayForKey:@"enabledMIDIOutputNames"] mutableCopy];
    else
        self.enabledMIDIOutputNames = [NSMutableArray arrayWithCapacity:16];
    
    self.loopFromScrubArea = [preferences boolForKey:@"loopFromScrubArea"];
    self.modeSwitchMethod = [preferences objectForKey:@"modeSwitchMethod"];
}

- (void) savePreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    NSString *oscLabel = nil;
    NSString *midiNodeName = nil;
    if( self.gridAutoConnect ) {
        oscLabel = self.gridOSCLabel;
        midiNodeName = self.gridMIDINodeName;
    }
    [preferences setObject:oscLabel forKey:@"gridOSCLabel"];
    [preferences setObject:midiNodeName forKey:@"gridMIDINodeName"];
    
    [preferences setBool:self.gridAutoConnect forKey:@"gridAutoConnect"];
    [preferences setBool:self.gridSupportsVariableBrightness forKey:@"gridSupportsVariableBrightness"];
    
    [preferences setObject:self.midiClockSourceName forKey:@"midiClockSourceName"];
    [preferences setBool:self.sendMIDIClock forKey:@"sendMIDIClock"];

    // Remove old entries if we end up with loads for some reason
    while ([self.enabledMIDIOutputNames count] > 100 ) {
        [self.enabledMIDIOutputNames removeObjectAtIndex:0];
    }
    [preferences setObject:self.enabledMIDIOutputNames forKey:@"enabledMIDIOutputNames"];
    
    [preferences setBool:self.loopFromScrubArea forKey:@"loopFromScrubArea"];
    [preferences setObject:self.modeSwitchMethod forKey:@"modeSwitchMethod"];
    
    [preferences synchronize];
}

@end
