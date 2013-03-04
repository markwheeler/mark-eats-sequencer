//
//  Document.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Document.h"
#import "Sequencer+Create.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"
#import "SequencerPatternRef.h"

@implementation Document

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.

        Sequencer *sequencer = [Sequencer sequencerWithPages:8 withPatterns:16 withPitches:8 inManagedObjectContext:self.managedObjectContext];

        sequencer.bpm = [NSNumber numberWithInt:89];

        //SequencerPage *page = sequencer.pages[2];
        //NSLog(@"%@", [page.pitches[3] pitch]);
        
        // NOTE: Always use isEqual: to compare as this is more effecient that doing a == object.property with ManagedObjects
        
        // TODO: Implement a category method on Sequencer 'createWithPages:(int)' that sets everything up? Might also need category methods for when steps or pitches change so we can remove all the notes that fall outside of the new bounds. Or do with KVO
        
        
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

@end
