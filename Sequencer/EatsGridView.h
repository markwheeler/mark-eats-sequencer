//
//  EatsGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Sequencer.h"


@protocol EatsGridSubViewDelegateProtocol
- (void) showView:(NSNumber *)gridView;
@optional
- (void) stopAnimation;
@end

@interface EatsGridView : NSObject <EatsGridSubViewDelegateProtocol>

@property (weak) id                 delegate;

@property uint                      width;
@property uint                      height;

@property Sequencer                 *sequencer;
@property NSMutableSet              *subViews;

@property dispatch_queue_t          gridQueue;

- (id) initWithDelegate:(id)delegate andSequencer:(Sequencer *)sequencer width:(uint)w height:(uint)h;
- (void) showView:(NSNumber *)gridView;
- (void) setupView;
- (void) updateView;

@end
