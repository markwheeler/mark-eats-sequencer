//
//  EatsGridDevice.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/11/2014.
//  Copyright (c) 2014 Mark Eats. All rights reserved.
//

#import "EatsGridDevice.h"
#import "EatsMonome.h"

@implementation EatsGridDevice

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Type: %i, Label: %@, DisplayName: %@, ProbablySupportsVariableBrightness: %hhd, Port: %i>", NSStringFromClass([self class]), self, self.type, self.label, self.displayName, self.probablySupportsVariableBrightness, self.port];
}

@end
