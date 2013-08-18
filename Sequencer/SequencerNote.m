//
//  SequencerNote.m
//  Alt Data Test
//
//  Created by Mark Wheeler on 12/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerNote.h"

@implementation SequencerNote

- (id) initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if( !self )
        return nil;
    
    self.step = [decoder decodeInt32ForKey:@"step"];
    self.row = [decoder decodeInt32ForKey:@"row"];
    self.length = [decoder decodeInt32ForKey:@"length"];
    self.velocity = [decoder decodeInt32ForKey:@"velocity"];
    
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt32:self.step forKey:@"step"];
    [encoder encodeInt32:self.row forKey:@"row"];
    [encoder encodeInt32:self.length forKey:@"length"];
    [encoder encodeInt32:self.velocity forKey:@"velocity"];
}

@end
