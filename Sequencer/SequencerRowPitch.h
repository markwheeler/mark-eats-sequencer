//
//  SequencerRowPitch.h
//  Sequencer
//
//  Created by Mark Wheeler on 01/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPage;

@interface SequencerRowPitch : NSManagedObject

@property (nonatomic, retain) NSNumber * pitch;
@property (nonatomic, retain) NSNumber * row;
@property (nonatomic, retain) SequencerPage *inPage;

@end
