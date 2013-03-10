//
//  EatsDocumentController.m
//  Sequencer
//
//  Created by Mark Wheeler on 09/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsDocumentController.h"

@implementation EatsDocumentController

- (void) setActiveDocument:(Document *)activeDocument
{
    self.lastActiveDocument = activeDocument;
    for(Document *doc in [self documents]) {
        if(doc == activeDocument)
            doc.isActive = YES;
        else
            doc.isActive = NO;
    }
}

@end
