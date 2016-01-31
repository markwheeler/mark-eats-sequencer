//
//  Preferences.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Preferences.h"
#import "EatsModulationUtils.h"

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
        self.gridWidth = 16;
        self.gridHeight = 16;
        
        self.modulationDestinationsArray = [EatsModulationUtils modulationDestinationsArray];
    }
    return self;
}

- (NSDictionary *) defaultPreferences
{
    NSMutableArray *tiltMIDIOutputDestinations = [NSMutableArray arrayWithCapacity:4];
    for( int i = 0; i < 4; i ++ )
        [tiltMIDIOutputDestinations addObject:[NSNumber numberWithInt:i + 4]];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"gridAutoConnect",
                                                      [NSNumber numberWithBool:YES], @"showNoteLengthOnGrid",
                                                      [NSNumber numberWithInteger:64], @"defaultMIDINoteVelocity",
                                                      [tiltMIDIOutputDestinations copy], @"tiltMIDIOutputDestinations",
                                                      nil];
}

- (void) loadPreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    // Default values
    [preferences registerDefaults:[self defaultPreferences]];
    
    // Load user settings
    self.gridMonomeId = [preferences objectForKey:@"gridMonomeId"];
    self.gridMIDINodeName = [preferences objectForKey:@"gridMIDINodeName"];
    
    self.gridAutoConnect = [preferences boolForKey:@"gridAutoConnect"];
    self.gridSupportsVariableBrightness = [preferences boolForKey:@"gridSupportsVariableBrightness"];
    
    self.inputMappings = [preferences objectForKey:@"inputMappings"];
    
    self.midiClockSourceName = [preferences objectForKey:@"midiClockSourceName"];
    self.sendMIDIClock = [preferences boolForKey:@"sendMIDIClock"];
    
    if( [preferences arrayForKey:@"enabledMIDIOutputNames"] )
        self.enabledMIDIOutputNames = [[preferences arrayForKey:@"enabledMIDIOutputNames"] mutableCopy];
    else
        self.enabledMIDIOutputNames = [NSMutableArray arrayWithCapacity:16];
    
    self.tiltMIDIOutputChannel = [preferences objectForKey:@"tiltMIDIOutputChannel"];
    self.tiltMIDIOutputDestinations = [preferences objectForKey:@"tiltMIDIOutputDestinations"];
    
    self.showNoteLengthOnGrid = [preferences boolForKey:@"showNoteLengthOnGrid"];
    self.loopFromScrubArea = [preferences boolForKey:@"loopFromScrubArea"];
    self.defaultMIDINoteVelocity = [preferences objectForKey:@"defaultMIDINoteVelocity"];
}

- (void) savePreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    NSString *monomeId = nil;
    NSString *midiNodeName = nil;
    if( self.gridAutoConnect ) {
        monomeId = self.gridMonomeId;
        midiNodeName = self.gridMIDINodeName;
    }
    [preferences setObject:monomeId forKey:@"gridMonomeId"];
    [preferences setObject:midiNodeName forKey:@"gridMIDINodeName"];
    
    [preferences setBool:self.gridAutoConnect forKey:@"gridAutoConnect"];
    [preferences setBool:self.gridSupportsVariableBrightness forKey:@"gridSupportsVariableBrightness"];
    
    [preferences setObject:self.inputMappings forKey:@"inputMappings"];
    
    [preferences setObject:self.midiClockSourceName forKey:@"midiClockSourceName"];
    [preferences setBool:self.sendMIDIClock forKey:@"sendMIDIClock"];

    // Remove old entries if we end up with loads for some reason
    while ([self.enabledMIDIOutputNames count] > 100 ) {
        [self.enabledMIDIOutputNames removeObjectAtIndex:0];
    }
    [preferences setObject:self.enabledMIDIOutputNames forKey:@"enabledMIDIOutputNames"];
    
    [preferences setObject:self.tiltMIDIOutputChannel forKey:@"tiltMIDIOutputChannel"];
    [preferences setObject:self.tiltMIDIOutputDestinations forKey:@"tiltMIDIOutputDestinations"];
    
    [preferences setBool:self.showNoteLengthOnGrid forKey:@"showNoteLengthOnGrid"];
    [preferences setBool:self.loopFromScrubArea forKey:@"loopFromScrubArea"];
    [preferences setObject:self.defaultMIDINoteVelocity forKey:@"defaultMIDINoteVelocity"];
    
    [preferences synchronize];
}

@end
