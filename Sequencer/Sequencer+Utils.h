//
//  Sequencer+Utils.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer.h"

@interface Sequencer (Utils)

+ (Sequencer *) sequencerWithPages:(uint)numberOfPages
            inManagedObjectContext:(NSManagedObjectContext *)context;

+ (void) addDummyDataToSequencer:(Sequencer *)sequencer
          inManagedObjectContext:(NSManagedObjectContext *)context;

+ (uint) randomStepForPage:(SequencerPage *)page ofWidth:(uint)width;

@end
