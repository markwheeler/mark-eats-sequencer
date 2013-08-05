//
//  SequencerPatternIdInPlaylist.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SequencerPage;

@interface SequencerPatternIdInPlaylist : NSManagedObject

@property (nonatomic, retain) NSNumber * patternId;
@property (nonatomic, retain) SequencerPage *inPlaylist;

@end
