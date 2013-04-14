//
//  EatsWMNoteValueTransformer.m
//  Sequencer
//
//  Created by Mark Wheeler on 14/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsWMNoteValueTransformer.h"
#import "WMPool+Utils.h"

@implementation EatsWMNoteValueTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    return (value == nil) ? nil : [[[WMPool pool] noteWithMidiNoteNumber:[(NSNumber *)value intValue]] shortName];
}

- (id)reverseTransformedValue:(id)value
{
    NSNumber *number;
    NSNumber *defaultValue = [NSNumber numberWithInt:60];
    
    if (value == nil)
        return defaultValue;
    
    // If the user entered a MIDI note number
    else if( [[NSScanner scannerWithString:value] scanInt:nil] ) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        formatter.roundingMode = NSNumberFormatterRoundFloor;
        number = [formatter numberFromString:(NSString *)value];
        return ( number.intValue >= 0 && number.intValue < 128 ) ? number : defaultValue;

    // Otherwise try to treat it as a short name
    } else {
        WMNote *note = [[WMPool pool] noteWithShortName:(NSString *)value];
        return (note) ? [NSNumber numberWithInt:note.midiNoteNumber] : defaultValue;
    }
}

@end
