//
//  Sequencer+Create.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer+Create.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerPatternRef.h"
#import "SequencerNote.h"
#import "EatsScaleGenerator.h"

@implementation Sequencer (Create)

+ (Sequencer *)sequencerWithPages:(uint)numberOfPages
                            width:(uint)width
                           height:(uint)height
           inManagedObjectContext:(NSManagedObjectContext *)context
{
    // Create an empty Sequencer
    Sequencer *sequencer = [NSEntityDescription insertNewObjectForEntityForName:@"Sequencer" inManagedObjectContext:context];
    
    // Generate pitches (Default C Major)
    NSArray *pitches = [EatsScaleGenerator generateScaleType:EatsScaleType_Ionian tonicNote:36 - ( 12 * (height / 8) ) length:32];
    // Reverse the array
    pitches = [[pitches reverseObjectEnumerator] allObjects];
    
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
            page.name = [NSString stringWithFormat:@"Drums page %i", channel - 9];
        else
            page.name = [NSString stringWithFormat:@"Sequencer page %i", i];
        page.loopEnd = [NSNumber numberWithUnsignedInt: width - 1];
       
        
        // Create the default pitches
        
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

    
    //SequencerPage *page = sequencer.pages[2];
    //NSLog(@"%@", [page.pitches[3] pitch]);
    
    // NOTE: Always use isEqual: to compare as this is more effecient that doing a == object.property with ManagedObjects
    
    // TODO: Might need category methods for when steps or pitches change so we can remove all the notes that fall outside of the new bounds. Or do with KVO
    
    return sequencer;
}


+ (void) addDummyDataToSequencer:(Sequencer *)sequencer inManagedObjectContext:(NSManagedObjectContext *)context
{
    // Adds 16 randomly positioned notes to page 0, pattern 0
    NSMutableSet *notes = [NSMutableSet setWithCapacity:16];
    for(int i = 0; i < 16; i++) {
        
        SequencerNote *note = [NSEntityDescription insertNewObjectForEntityForName:@"SequencerNote" inManagedObjectContext:context];
        
        note.lengthAsPercentage = [NSNumber numberWithFloat:6.25];
        note.row = [NSNumber numberWithInt:arc4random_uniform(8)];
        note.step = [NSNumber numberWithInt:i];
        
        [notes addObject:note];
    }
    SequencerPage *page = sequencer.pages[0];
    SequencerPattern *pattern = page.patterns[0];
    pattern.notes = notes;
}


@end
