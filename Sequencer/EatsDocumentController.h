//
//  EatsDocumentController.h
//  Sequencer
//
//  Created by Mark Wheeler on 09/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Document.h"

@interface EatsDocumentController : NSDocumentController

@property (weak) Document *lastActiveDocument;

- (void)setActiveDocument:(Document *)document;

@end
