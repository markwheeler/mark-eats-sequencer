//
//  EatsMIDIManager.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVMIDI/VVMIDI.h>

@interface EatsMIDIManager : VVMIDIManager

- (NSString *) receivingNodeName;
- (NSString *) sendingNodeName;

@end
