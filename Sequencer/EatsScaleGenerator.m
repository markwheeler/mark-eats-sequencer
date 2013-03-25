//
//  EatsScaleGenerator.m
//  Sequencer
//
//  Created by Mark Wheeler on 09/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsScaleGenerator.h"

@implementation EatsScaleGenerator

+ (NSArray *) scaleTypeNames
{
    // Order matches type def
    return [NSArray arrayWithObjects:@"Ionian (Major)",
                                     @"Dorian",
                                     @"Phrygian",
                                     @"Lydian",
                                     @"Mixolydian",
                                     @"Aeolian (Natural minor)",
                                     @"Locrian",
                                     @"Harmonic Minor",
                                     @"Major Pentatonic",
                                     @"Minor Pentatonic",
                                     @"Whole Tone",
                                     @"Diminished",
                                     @"Octatonic",
                                     @"Chromatic",
                                     @"Drum Map",
                                     nil];
}

+ (NSArray *) generateScaleType:(EatsScaleType)type tonicNote:(uint)tonic length:(uint)length
{
    NSArray *intervalsArray = nil;
    NSMutableArray *scaleArray = [NSMutableArray arrayWithCapacity:length];
    uint currentNote = tonic;
    
    switch (type)
    {
        case EatsScaleType_Ionian:
            // T-T-s-T-T-T-s
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        case EatsScaleType_Dorian:
            // T-s-T-T-T-s-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Phrygian:
            // s-T-T-T-s-T-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Lydian:
            // T-T-T-s-T-T-s
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        case EatsScaleType_Mixolydian:
            // T-T-s-T-T-s-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Aeolian:
            // T-s-T-T-s-T-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Locrian:
            // s-T-T-s-T-T-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_HarmonicMinor:
            // T-s-T-T-s-3-s
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:3],
                                                       [NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        case EatsScaleType_MajorPentatonic:
            // T-T-3-T-3
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:3],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:3],
                                                       nil];
            break;
            
        case EatsScaleType_MinorPentatonic:
            // 3-T-T-3-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:3],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:3],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_WholeTone:
            // T-T-T-T-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Diminished:
            // T-s-T-s-T-s-T-s
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:2],
                                                       [NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        case EatsScaleType_Octatonic:
            // s-T-s-T-s-T-s-T
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                                                       [NSNumber numberWithInt:2],
                                                       nil];
            break;
            
        case EatsScaleType_Chromatic:
            // s-s-s-s-s-s-s-s-s-s-s-s
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        case EatsScaleType_DrumMap:
            // http://upload.wikimedia.org/wikipedia/commons/c/c2/GM_Standard_Drum_Map_on_the_keyboard.svg
            currentNote = 35; // Acoustic BD
            intervalsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                                                       nil];
            break;
            
        default:
            break;
            
    }
    
    // Build the scale
    uint arrayPass = 0;
    for(int i = 0; i < length; i++ ){
        [scaleArray addObject:[NSNumber numberWithUnsignedInt:currentNote]];
        if([intervalsArray count] * (arrayPass +1) <= i)
            arrayPass++;
        uint nextNote = currentNote + [[intervalsArray objectAtIndex:i - ([intervalsArray count] * arrayPass)] intValue];
        if( nextNote < 128 )
            currentNote = nextNote;
    }
    
    return scaleArray;
}

@end
