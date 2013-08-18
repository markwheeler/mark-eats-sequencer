//
//  SequencerPage.h
//  Alt Data Test
//
//  Created by Mark Wheeler on 10/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SequencerPage : NSObject <NSCoding>

@property int                   channel;
@property NSString              *name;

@property int                   stepLength;
@property int                   loopStart;
@property int                   loopEnd;

@property int                   swingType;
@property int                   swingAmount;
@property BOOL                  velocityGroove;
@property int                   transpose;
@property int                   transposeZeroStep;

@property NSMutableOrderedSet   *patterns; // Each pattern is just an NSMutableSet of notes. Position in this set denotes id
@property NSMutableOrderedSet   *pitches; // Just contains NSNumbers. Position in set denotes row

@end
