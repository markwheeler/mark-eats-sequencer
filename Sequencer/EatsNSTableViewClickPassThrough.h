//
//  EatsNSTableViewClickPassThrough.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol EatsNSTableViewClickPassThroughDelegateProtocol
@optional
- (void) keyDownFromTableView:(NSEvent *)keyEvent;
@end

@interface EatsNSTableViewClickPassThrough : NSTableView

@end
