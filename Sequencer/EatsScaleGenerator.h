//
//  EatsScaleGenerator.h
//  Sequencer
//
//  Created by Mark Wheeler on 09/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Utility to return a scale of notes ascending from the given MIDI note tonic
//  Useful reference: http://docs.solfege.org/3.21/C/scales

#import <Foundation/Foundation.h>

typedef enum EatsScaleType{
    EatsScaleType_Ionian, // Major
    EatsScaleType_Dorian,
    EatsScaleType_Phrygian,
    EatsScaleType_Lydian,
    EatsScaleType_Mixolydian,
    EatsScaleType_Aeolian, // Natural minor
    EatsScaleType_Locrian,
    EatsScaleType_HarmonicMinor,
    EatsScaleType_MajorPentatonic,
    EatsScaleType_MinorPentatonic,
    EatsScaleType_WholeTone,
    EatsScaleType_Diminished,
    EatsScaleType_Octatonic,
    EatsScaleType_Chromatic,
    EatsScaleType_DrumMap
} EatsScaleType;

@interface EatsScaleGenerator : NSObject

+ (NSArray *) generateScaleType:(EatsScaleType)type tonicNote:(uint)tonic length:(uint)length;

@end
