//
//  WMPool+Utils.m
//  Sequencer
//
//  Created by Mark Wheeler on 14/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "WMPool+Utils.h"

@implementation WMPool (Utils)

+ (NSArray *)sequenceOfNotesWithRootShortName:(NSString *)name scaleMode:(WMScaleMode *)mode length:(uint)length
{
    NSMutableArray *noteSequence = [NSMutableArray arrayWithCapacity:length];
    NSString *lastNoteName = name;
    
    while( noteSequence.count < length ) {
        
        NSArray *notesToAdd = [[[WMPool pool] scaleWithRootShortName:lastNoteName scaleMode:mode] notes];
        
        for( int i = 0; i < notesToAdd.count; i ++ ) {
            if( i == notesToAdd.count - 1 ) {
                lastNoteName = [[[notesToAdd objectAtIndex:i] shortName] copy];
            } else
                [noteSequence addObject:[notesToAdd objectAtIndex:i]];
        }
    }
    
    // Trim it down and reverse it
    [noteSequence removeObjectsInRange:NSMakeRange(length, noteSequence.count - length)];

    //NSLog(@"%@", noteSequence );

    return [[noteSequence reverseObjectEnumerator] allObjects];
}

@end
