//
//  EatsGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol EatsGridSubViewDelegateProtocol
- (void) showView:(NSNumber *)gridView;
@end

@interface EatsGridView : NSObject <EatsGridSubViewDelegateProtocol>

@property (weak) id                 delegate;

@property uint                      width;
@property uint                      height;

@property NSManagedObjectContext    *managedObjectContext;
@property NSMutableSet              *subViews;

@property dispatch_queue_t          bigSerialQueue;

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context andQueue:(dispatch_queue_t)queue width:(uint)w height:(uint)h;
- (void) showView:(NSNumber *)gridView;
- (void) setupView;
- (void) updateView;

@end
