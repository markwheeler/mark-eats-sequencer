//
//  SequencerNote.m
//  Sequencer
//
//  Created by Mark Wheeler on 12/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerNote.h"

@implementation SequencerNote

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Step: %i, Row: %i, Length: %i, Velocity: %i, ModulationValues: %@>", NSStringFromClass([self class]), self, self.step, self.row, self.length, self.velocity, self.modulationValues];
}

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    self.step = [decoder decodeInt32ForKey:@"step"];
    self.row = [decoder decodeInt32ForKey:@"row"];
    self.length = [decoder decodeInt32ForKey:@"length"];
    self.velocity = [decoder decodeInt32ForKey:@"velocity"];
    self.modulationValues = [decoder decodeObjectForKey:@"modulationValues"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.step forKey:@"step"];
    [encoder encodeInt32:self.row forKey:@"row"];
    [encoder encodeInt32:self.length forKey:@"length"];
    [encoder encodeInt32:self.velocity forKey:@"velocity"];
    [encoder encodeObject:self.modulationValues forKey:@"modulationValues"];
}

- (id) copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] alloc] init];
    
    if( copy ) {
        [copy setStep:self.step];
        [copy setRow:self.row];
        [(SequencerNote *)copy setLength:self.length];
        [copy setVelocity:self.velocity];
        [copy setModulationValues:self.modulationValues];
    }
    
    return copy;
}

@end
