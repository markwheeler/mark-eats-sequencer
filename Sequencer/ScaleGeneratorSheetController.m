//
//  ScaleGeneratorSheetController.m
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ScaleGeneratorSheetController.h"
#import "EatsScaleGenerator.h"

@interface ScaleGeneratorSheetController ()

@property (weak) IBOutlet NSPopUpButton *scaleTypePopup;
@property (weak) IBOutlet NSTextField *tonicNoteTextField;

@end

@implementation ScaleGeneratorSheetController

- (id)init {
    if (!(self = [super initWithWindowNibName:@"ScaleGeneratorSheet"])) {
        return nil; // Bail!
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.scaleTypePopup removeAllItems];
    [self.scaleTypePopup addItemWithTitle:@"Hello"];
    
}



#pragma Mark - Action methods

- (IBAction)generateButton:(NSButton *)sender {
    [self endSheetWithReturnCode:NSOKButton];
}

- (IBAction)cancelButton:(NSButton *)sender {
    [self endSheetWithReturnCode:NSCancelButton];
}


@end
