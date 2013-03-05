//
//  EatsGridNavigationController.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VVOSC/VVOSC.h>
#import <VVMIDI/VVMIDI.h>

@protocol EatsGridViewDelegateProtocol
- (void) updateGridWithArray:(NSArray *)gridArray;
@end


@interface EatsGridNavigationController : NSObject <EatsGridViewDelegateProtocol>

- (void) updateGridView;
- (void) updateGridWithArray:(NSArray *)gridArray;

@end
