//
//  EatsMonome.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VVOSC/VVOSC.h>

@interface EatsMonome : NSObject

@property OSCOutPort    *oscOutPort;
@property NSString      *oscPrefix;

+ (void) connectToMonomeAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort withPrefix:(NSString *)prefix;
+ (void) disconnectFromMonomeAtPort:(OSCOutPort *)outPort;
+ (void) monomeTiltSensor:(BOOL)enable atPort:(OSCOutPort *)outPort withPrefix:(NSString *)prefix;

- (id) initWithOSCPort:(OSCOutPort *)port oscPrefix:(NSString *)prefix;
- (void) redrawGridController:(NSArray *)gridArray;
- (void) clearGridController;

@end