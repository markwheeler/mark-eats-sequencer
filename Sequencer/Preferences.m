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

- (void) loadPreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    self.gridMIDINode = [preferences objectForKey:@"gridMIDINode"];
    
    self.gridAutoConnect = [preferences boolForKey:@"gridAutoConnect"];
    self.gridSupportsVariableBrightness = [preferences boolForKey:@"gridSupportsVariableBrightness"];
    
    self.midiClockSource = [preferences objectForKey:@"midiClockSource"];
    self.sendMIDIClock = [preferences boolForKey:@"sendMIDIClock"];
    
    self.emulateSP1200NoteVelocity = [preferences boolForKey:@"emulateSP1200NoteVelocity"];
}

- (void) savePreferences
{    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    [preferences setObject:self.gridMIDINode forKey:@"gridMIDINode"];
    
    [preferences setBool:self.gridAutoConnect forKey:@"gridAutoConnect"];
    [preferences setBool:self.gridSupportsVariableBrightness forKey:@"gridSupportsVariableBrightness"];
    
    [preferences setObject:self.midiClockSource forKey:@"midiClockSource"];
    [preferences setBool:self.sendMIDIClock forKey:@"sendMIDIClock"];
    
    [preferences setBool:self.emulateSP1200NoteVelocity forKey:@"emulateSP1200NoteVelocity"];
    
    [preferences synchronize];
}

@end
