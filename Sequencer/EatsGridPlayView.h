//
//  EatsGridPlayView.h
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsGridPlayView : NSObject

@property (weak) id delegate;

@property uint width;
@property uint height;

- (id) initWithDelegate:(id)delegate width:(uint)w height:(uint)h;
- (void) updateView;

@end
