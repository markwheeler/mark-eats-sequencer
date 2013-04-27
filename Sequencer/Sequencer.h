//
//  Sequencer.h
//  Sequencer
//
//  Created by Mark Wheeler on 25/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPage;

@interface Sequencer : NSManagedObject

@property (nonatomic, retain) NSNumber * bpm;
@property (nonatomic, retain) NSNumber * patternQuantization;
@property (nonatomic, retain) NSNumber * stepQuantization;
@property (nonatomic, retain) NSOrderedSet *pages;
@end

@interface Sequencer (CoreDataGeneratedAccessors)

- (void)insertObject:(SequencerPage *)value inPagesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromPagesAtIndex:(NSUInteger)idx;
- (void)insertPages:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removePagesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInPagesAtIndex:(NSUInteger)idx withObject:(SequencerPage *)value;
- (void)replacePagesAtIndexes:(NSIndexSet *)indexes withPages:(NSArray *)values;
- (void)addPagesObject:(SequencerPage *)value;
- (void)removePagesObject:(SequencerPage *)value;
- (void)addPages:(NSOrderedSet *)values;
- (void)removePages:(NSOrderedSet *)values;
@end
