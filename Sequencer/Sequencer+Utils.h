//
//  Sequencer+Utils.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer.h"

typedef enum EatsSequencerPlayMode {
    EatsSequencerPlayMode_Pause,
    EatsSequencerPlayMode_Forward,
    EatsSequencerPlayMode_Reverse,
    EatsSequencerPlayMode_Random
} EatsSequencerPlayMode;

@interface Sequencer (Utils)

+ (Sequencer *) sequencerWithPages:(uint)numberOfPages
                             width:(uint)width
                            height:(uint)height
            inManagedObjectContext:(NSManagedObjectContext *)context;

+ (void) addDummyDataToSequencer:(Sequencer *)sequencer
          inManagedObjectContext:(NSManagedObjectContext *)context;

+ (uint) randomStepForPage:(SequencerPage *)page ofWidth:(uint)width;

@end
