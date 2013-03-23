//
//  EatsGridPlayViewController.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsGridPlayViewController : NSObject

@property (weak) id delegate;
@property NSManagedObjectContext *managedObjectContext;

@property uint width;
@property uint height;

- (id) initWithDelegate:(id)delegate managedObjectContext:(NSManagedObjectContext *)context width:(uint)w height:(uint)h;
- (void) showView:(NSNumber *)gridView;
- (void) updateView;

@end
