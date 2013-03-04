//
//  Document.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Sequencer+Create.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"
#import "SequencerPatternRef.h"
#import "EatsClock.h"

@interface Document : NSPersistentDocument <EatsClockDelegateProtocol>

@property Sequencer *sequencer;

@end
