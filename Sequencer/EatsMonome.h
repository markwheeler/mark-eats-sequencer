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

+ (void) lookForMonomesAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort;
+ (void) beNotifiedOfMonomeChangesAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort;
+ (void) connectToMonomeAtPort:(OSCOutPort *)outPort fromPort:(OSCInPort *)inPort withPrefix:(NSString *)prefix;
+ (void) disconnectFromMonomeAtPort:(OSCOutPort *)outPort withPrefix:(NSString *)prefix;

+ (BOOL) doesMonomeSupportVariableBrightness:(NSString *)serial;

- (id) initWithOSCPort:(OSCOutPort *)port oscPrefix:(NSString *)prefix;
- (void) redrawGridController:(NSArray *)gridArray;
- (void) clearGridController;

@end