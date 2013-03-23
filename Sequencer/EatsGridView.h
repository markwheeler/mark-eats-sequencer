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
@property NSSet                     *subViews;

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context width:(uint)w height:(uint)h;
- (void) showView:(NSNumber *)gridView;
- (void) setupView;
- (void) updateView;

@end
