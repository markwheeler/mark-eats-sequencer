//
//  SequencerPage.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Sequencer, SequencerPattern, SequencerPatternRef, SequencerRowPitch;

@interface SequencerPage : NSManagedObject

@property (nonatomic, retain) NSNumber * channel;
@property (nonatomic, retain) NSNumber * currentPattern;
@property (nonatomic, retain) NSNumber * currentStep;
@property (nonatomic, retain) NSNumber * id;
@property (nonatomic, retain) NSNumber * loopEnd;
@property (nonatomic, retain) NSNumber * loopStart;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * nextPattern;
@property (nonatomic, retain) NSNumber * nextStep;
@property (nonatomic, retain) NSNumber * playMode;
@property (nonatomic, retain) NSNumber * stepLength;
@property (nonatomic, retain) NSNumber * swing;
@property (nonatomic, retain) Sequencer *inSequencer;
@property (nonatomic, retain) NSOrderedSet *patterns;
@property (nonatomic, retain) NSOrderedSet *pitches;
@property (nonatomic, retain) NSOrderedSet *playlist;
@end

@interface SequencerPage (CoreDataGeneratedAccessors)

- (void)insertObject:(SequencerPattern *)value inPatternsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromPatternsAtIndex:(NSUInteger)idx;
- (void)insertPatterns:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removePatternsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInPatternsAtIndex:(NSUInteger)idx withObject:(SequencerPattern *)value;
- (void)replacePatternsAtIndexes:(NSIndexSet *)indexes withPatterns:(NSArray *)values;
- (void)addPatternsObject:(SequencerPattern *)value;
- (void)removePatternsObject:(SequencerPattern *)value;
- (void)addPatterns:(NSOrderedSet *)values;
- (void)removePatterns:(NSOrderedSet *)values;
- (void)insertObject:(SequencerRowPitch *)value inPitchesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromPitchesAtIndex:(NSUInteger)idx;
- (void)insertPitches:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removePitchesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInPitchesAtIndex:(NSUInteger)idx withObject:(SequencerRowPitch *)value;
- (void)replacePitchesAtIndexes:(NSIndexSet *)indexes withPitches:(NSArray *)values;
- (void)addPitchesObject:(SequencerRowPitch *)value;
- (void)removePitchesObject:(SequencerRowPitch *)value;
- (void)addPitches:(NSOrderedSet *)values;
- (void)removePitches:(NSOrderedSet *)values;
- (void)insertObject:(SequencerPatternRef *)value inPlaylistAtIndex:(NSUInteger)idx;
- (void)removeObjectFromPlaylistAtIndex:(NSUInteger)idx;
- (void)insertPlaylist:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removePlaylistAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInPlaylistAtIndex:(NSUInteger)idx withObject:(SequencerPatternRef *)value;
- (void)replacePlaylistAtIndexes:(NSIndexSet *)indexes withPlaylist:(NSArray *)values;
- (void)addPlaylistObject:(SequencerPatternRef *)value;
- (void)removePlaylistObject:(SequencerPatternRef *)value;
- (void)addPlaylist:(NSOrderedSet *)values;
- (void)removePlaylist:(NSOrderedSet *)values;
@end
