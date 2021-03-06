//
//  SequencerSong.m
//  Sequencer
//
//  Created by Mark Wheeler on 10/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerSong.h"

@implementation SequencerSong

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, SongVersion: %i, BPM: %f, StepQuantization: %i, PatternQuantization: %i, Pages: %@, Automation: %@>", NSStringFromClass([self class]), self, self.songVersion, self.bpm, self.stepQuantization, self.patternQuantization, self.pages, self.automation];
}

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    self.songVersion = [decoder decodeInt32ForKey:@"songVersion"];
    
    self.bpm = [decoder decodeFloatForKey:@"bpm"];
    self.stepQuantization = [decoder decodeInt32ForKey:@"stepQuantization"];
    self.patternQuantization = [decoder decodeInt32ForKey:@"patternQuantization"];
    
    self.pages = [decoder decodeObjectForKey:@"pages"];
    
    self.automation = [decoder decodeObjectForKey:@"automation"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.songVersion forKey:@"songVersion"];
    
    [encoder encodeFloat:self.bpm forKey:@"bpm"];
    [encoder encodeInt32:self.stepQuantization forKey:@"stepQuantization"];
    [encoder encodeInt32:self.patternQuantization forKey:@"patternQuantization"];
    
    [encoder encodeObject:self.pages forKey:@"pages"];
    
    [encoder encodeObject:self.automation forKey:@"automation"];
}

@end
