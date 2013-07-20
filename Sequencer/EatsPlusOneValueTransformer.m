//
//  EatsPlusOneValueTransformer.m
//  Sequencer
//
//  Created by Mark Wheeler on 17/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsPlusOneValueTransformer.h"

@implementation EatsPlusOneValueTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (NSNumber *)transformedValue:(NSNumber *)value
{
    return (value == nil) ? nil : [NSNumber numberWithInt:value.intValue + 1];
}

- (NSNumber *)reverseTransformedValue:(NSNumber *)value
{
    return (value == nil) ? nil : [NSNumber numberWithInt:value.intValue - 1];
}

@end
