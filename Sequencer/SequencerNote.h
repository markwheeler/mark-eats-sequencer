//
//  SequencerNote.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPattern;

@interface SequencerNote : NSManagedObject

@property (nonatomic, retain) NSNumber * length;
@property (nonatomic, retain) NSNumber * row;
@property (nonatomic, retain) NSNumber * step;
@property (nonatomic, retain) NSNumber * velocityAsPercentage;
@property (nonatomic, retain) SequencerPattern *inPattern;

@end
