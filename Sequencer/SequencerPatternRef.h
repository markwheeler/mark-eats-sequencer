//
//  SequencerPatternRef.h
//  Sequencer
//
//  Created by Mark Wheeler on 23/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPage;

@interface SequencerPatternRef : NSManagedObject

@property (nonatomic, retain) NSNumber * pattern;
@property (nonatomic, retain) SequencerPage *inPlaylist;

@end
