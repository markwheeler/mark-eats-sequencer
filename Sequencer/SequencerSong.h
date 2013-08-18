//
//  SequencerSong.h
//  Alt Data Test
//
//  Created by Mark Wheeler on 10/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SEQUENCER_SONG_BPM_MIN 20
#define SEQUENCER_SONG_BPM_MAX 300

@interface SequencerSong : NSObject <NSCoding>

@property int                   songVersion;

@property float                 bpm;
@property int                   stepQuantization;
@property int                   patternQuantization;

@property NSOrderedSet          *pages; // Position in set denotes id

@end
