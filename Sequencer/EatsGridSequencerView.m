//
//  EatsGridSequencerView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerView.h"
#import "SequencerNote.h"

@implementation EatsGridSequencerView

#pragma mark - Public methods

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        self.managedObjectContext = context;
        self.width = w;
        self.height = h;
        

        [self updateView];
        
    }
    return self;
}

- (void) updateView
{
    
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
    //request.predicate = [NSPredicate predicateWithFormat:@"inPattern IS 0"];
    
    NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:nil];
    for(SequencerNote *note in matches) {
        [[gridArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:[note.row intValue] withObject:[NSNumber numberWithInt:15]];
    }
    
    // Send msg to delegate
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

@end
