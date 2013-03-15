//
//  SequencerPattern.h
//  Sequencer
//
//  Created by Mark Wheeler on 12/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerNote, SequencerPage;

@interface SequencerPattern : NSManagedObject

@property (nonatomic, retain) NSNumber * id;
@property (nonatomic, retain) SequencerPage *inPage;
@property (nonatomic, retain) NSSet *notes;
@end

@interface SequencerPattern (CoreDataGeneratedAccessors)

- (void)addNotesObject:(SequencerNote *)value;
- (void)removeNotesObject:(SequencerNote *)value;
- (void)addNotes:(NSSet *)values;
- (void)removeNotes:(NSSet *)values;

@end
