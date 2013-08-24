//
//  SequencerPage.m
//  Alt Data Test
//
//  Created by Mark Wheeler on 10/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerPage.h"

@implementation SequencerPage

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Channel: %i, Name: %@, StepLength: %i, LoopStart: %i, LoopEnd: %i, SwingType: %i, SwingAmount: %i, VelocityGroove: %i, Transpose: %i, TransposeZeroStep: %i, Patterns: %@, Pitches: %@,>", NSStringFromClass([self class]), self, self.channel, self.name, self.stepLength, self.loopStart, self.loopEnd, self.swingType, self.swingAmount, self.velocityGroove, self.transpose, self.transposeZeroStep, self.patterns, self.pitches];
}

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    self.channel = [decoder decodeInt32ForKey:@"channel"];
    self.name = [decoder decodeObjectForKey:@"name"];
    
    self.stepLength = [decoder decodeInt32ForKey:@"stepLength"];
    self.loopStart = [decoder decodeInt32ForKey:@"loopStart"];
    self.loopEnd = [decoder decodeInt32ForKey:@"loopEnd"];
    
    self.swingType = [decoder decodeInt32ForKey:@"swingType"];
    self.swingAmount = [decoder decodeInt32ForKey:@"swingAmount"];
    self.velocityGroove = [decoder decodeBoolForKey:@"velocityGroove"];
    self.transpose = [decoder decodeInt32ForKey:@"transpose"];
    self.transposeZeroStep = [decoder decodeInt32ForKey:@"transposeZeroStep"];
    
    self.patterns = [decoder decodeObjectForKey:@"patterns"];
    self.pitches = [decoder decodeObjectForKey:@"pitches"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.channel forKey:@"channel"];
    [encoder encodeObject:self.name forKey:@"name"];
    
    [encoder encodeInt32:self.stepLength forKey:@"stepLength"];
    [encoder encodeInt32:self.loopStart forKey:@"loopStart"];
    [encoder encodeInt32:self.loopEnd forKey:@"loopEnd"];
    
    [encoder encodeInt32:self.swingType forKey:@"swingType"];
    [encoder encodeInt32:self.swingAmount forKey:@"swingAmount"];
    [encoder encodeBool:self.velocityGroove forKey:@"velocityGroove"];
    [encoder encodeInt32:self.transpose forKey:@"transpose"];
    [encoder encodeInt32:self.transposeZeroStep forKey:@"transposeZeroStep"];
    
    [encoder encodeObject:self.patterns forKey:@"patterns"];
    [encoder encodeObject:self.pitches forKey:@"pitches"];
}

@end
