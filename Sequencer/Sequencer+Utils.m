//
//  Sequencer+Utils.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerPatternRef.h"
#import "SequencerNote.h"
#import "EatsScaleGenerator.h"

@implementation Sequencer (Utils)

+ (Sequencer *)sequencerWithPages:(uint)numberOfPages
           inManagedObjectContext:(NSManagedObjectContext *)context
{
    // Create an empty Sequencer
    Sequencer *sequencer = [NSEntityDescription insertNewObjectForEntityForName:@"Sequencer" inManagedObjectContext:context];
    
    // Create the empty SequencerPages
    NSMutableOrderedSet *setOfPages = [NSMutableOrderedSet orderedSetWithCapacity:numberOfPages];
    for( int i = 0; i < numberOfPages; i++) {
        
        // Create a page and setup the channels (TODO: make this a method on SequencerPage)
        
        SequencerPage *page = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerPage" inManagedObjectContext:context];
        uint channel = i;
        if (channel >= numberOfPages - 2 && numberOfPages < 10) // Make the last two channels drums (10 & 11) on small grids
            channel = i + (12 - numberOfPages);
        page.channel = [NSNumber numberWithUnsignedInt: channel];
        page.id = [NSNumber numberWithInt:i];
        if (channel == 10 || channel == 11)
            page.name = [NSString stringWithFormat:@"Drums %i", channel - 9];
        else
            page.name = [NSString stringWithFormat:@"Page %i", i + 1];
        page.loopEnd = [NSNumber numberWithUnsignedInt: 31];
        page.currentStep = [page.loopEnd copy];
        
        // Create the default pitches
        // TODO Make these line up better with the grid (tonic note on last row?)
        NSArray *pitches;
        if (channel == 10 || channel == 11)
            pitches = [EatsScaleGenerator generateScaleType:EatsScaleType_DrumMap tonicNote:35 length:32]; // Drum Map
        else
            pitches = [EatsScaleGenerator generateScaleType:EatsScaleType_Ionian tonicNote:60 length:32]; // C Major
        // Reverse the array
        pitches = [[pitches reverseObjectEnumerator] allObjects];
        
        NSMutableOrderedSet *setOfRowPitches = [NSMutableOrderedSet orderedSetWithCapacity:32];
        int r = 0;
        for( NSNumber *pitch in pitches ) {
            SequencerRowPitch *rowPitch = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerRowPitch" inManagedObjectContext:context];
            rowPitch.row = [NSNumber numberWithInt:r];
            rowPitch.pitch = pitch;
            [setOfRowPitches addObject:rowPitch];
            r++;
        }
        page.pitches = setOfRowPitches;
        

        // Create the empty SequencerPatterns
        NSMutableOrderedSet *setOfPatterns = [NSMutableOrderedSet orderedSetWithCapacity:32];
        for( int j = 0; j < 32; j++) {
            SequencerPattern *pattern = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerPattern" inManagedObjectContext:context];
            pattern.id = [NSNumber numberWithInt:j];
            [setOfPatterns addObject:pattern];
        }
        page.patterns = setOfPatterns;
        
        // Add everything
        [setOfPages addObject:page];
    }
    sequencer.pages = setOfPages;

    // TODO: Might need category methods for when steps or pitches change so we can remove all the notes that fall outside of the new bounds. Or do with KVO
    
    return sequencer;
}


+ (void) addDummyDataToSequencer:(Sequencer *)sequencer inManagedObjectContext:(NSManagedObjectContext *)context
{
    // Adds 16 randomly positioned notes to page 0, pattern 0
    NSMutableSet *notes = [NSMutableSet setWithCapacity:16];
    for(int i = 0; i < 16; i++) {
        
        SequencerNote *note = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:context];
        
        note.row = [NSNumber numberWithInt:31 - arc4random_uniform(8)];
        note.step = [NSNumber numberWithInt:i];
        
        [notes addObject:note];
    }
    SequencerPage *page = sequencer.pages[0];
    SequencerPattern *pattern = page.patterns[0];
    pattern.notes = notes;
}


+ (uint) randomStepForPage:(SequencerPage *)page ofWidth:(uint)width
{
    int loopEnd;
    if( page.loopEnd >= page.loopStart )
        loopEnd = page.loopEnd.intValue;
    else
        loopEnd = page.loopEnd.intValue + width;
    
    int range = loopEnd + 1 - page.loopStart.intValue;
    
    int result = floor(arc4random_uniform(range) + page.loopStart.intValue);
    if( result >= width )
        result -= width;
    
    return result;
}


@end
