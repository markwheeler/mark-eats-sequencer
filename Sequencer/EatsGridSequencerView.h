//
//  EatsGridSequencerView.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EatsGridView.h"
#import "EatsGridNavigationController.h"

@interface EatsGridSequencerView : EatsGridView <EatsGridSubViewDelegateProtocol>

- (void) enterNoteEditMode;
- (void) exitNoteEditMode;

@end
