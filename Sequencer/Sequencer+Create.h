//
//  Sequencer+Create.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer.h"

@interface Sequencer (Create)

+ (Sequencer *)sequencerWithPages:(uint)numberOfPages
                     withPatterns:(uint)numberOfPatterns
                      withPitches:(uint)numberOfPitches
           inManagedObjectContext:(NSManagedObjectContext *)context;

@end
