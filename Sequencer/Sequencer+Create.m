//
//  Sequencer+Create.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer+Create.h"
#import "SequencerPage.h"

@implementation Sequencer (Create)

+ (Sequencer *)sequencerWithPages:(uint)numberOfPages
                     withPatterns:(uint)numberOfPatterns
                      withPitches:(uint)numberOfPitches
           inManagedObjectContext:(NSManagedObjectContext *)context
{
    // Create an empty Sequencer
    Sequencer *sequencer = [NSEntityDescription insertNewObjectForEntityForName:@"Sequencer" inManagedObjectContext:context];
    
    // Create the empty SequencerPages
    NSMutableOrderedSet *setOfPages = [NSMutableOrderedSet orderedSetWithCapacity:numberOfPages];
    for( int i = 0; i < numberOfPages; i++) {
        
        // Create a page and setup the channels (make this a method on SequencerPage)
        SequencerPage *page = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerPage" inManagedObjectContext:context];
        uint channel = i;
        if (channel >= numberOfPages - 2 && numberOfPages < 10) // Make the last two channels drums (10 & 11) on small grids
            channel = i + (12 - numberOfPages);
        page.channel = [NSNumber numberWithUnsignedInt: channel];
        
        // Create the empty SequencerPatterns
        NSMutableOrderedSet *setOfPatterns = [NSMutableOrderedSet orderedSetWithCapacity:numberOfPatterns];;
        for( int j = 0; j < numberOfPatterns; j++) {
            [setOfPatterns addObject:[NSEntityDescription insertNewObjectForEntityForName:@"SequencerPattern" inManagedObjectContext:context]];
        }
        page.patterns = setOfPatterns;
        
        // Create the empty SequencerRowPitches
        NSMutableOrderedSet *setOfPitches = [NSMutableOrderedSet orderedSetWithCapacity:numberOfPitches];
        for( int k = 0; k < numberOfPitches; k++) {
            [setOfPitches addObject:[NSEntityDescription insertNewObjectForEntityForName:@"SequencerRowPitch" inManagedObjectContext:context]];
        }
        page.pitches = setOfPitches;
        
        [setOfPages addObject:page];
    }
    sequencer.pages = setOfPages;
    
    return sequencer;
}


@end
