//
//  SequencerNote.h
//  Alt Data Test
//
//  Created by Mark Wheeler on 12/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SequencerNote : NSObject <NSCoding, NSCopying>

@property int                   step;
@property int                   row;
@property int                   length;
@property int                   velocity;

@end
