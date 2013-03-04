//
//  SequencerNote.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPattern;

@interface SequencerNote : NSManagedObject

@property (nonatomic, retain) NSNumber * lengthAsPercentage;
@property (nonatomic, retain) NSNumber * row;
@property (nonatomic, retain) NSNumber * step;
@property (nonatomic, retain) NSNumber * velocity;
@property (nonatomic, retain) SequencerPattern *inPattern;

@end
