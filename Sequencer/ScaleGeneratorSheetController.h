//
//  ScaleGeneratorSheetController.h
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JCSSheetController.h"
#import "SequencerPage.h"
#import "WMPool+Utils.h"

@interface ScaleGeneratorSheetController : JCSSheetController

@property NSString                   *scaleMode;
@property NSString                   *tonicNoteName;

@end
