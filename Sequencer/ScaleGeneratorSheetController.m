//
//  ScaleGeneratorSheetController.m
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ScaleGeneratorSheetController.h"
#import "SequencerRowPitch.h"

@interface ScaleGeneratorSheetController ()

@property (weak) IBOutlet NSPopUpButton *scaleTypePopup;
@property (weak) IBOutlet NSTextField *tonicNoteTextField;

@property NSNumber                  *previousTonicNote;

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
    
    // Populate UI
    [self.scaleTypePopup removeAllItems];
    [self.scaleTypePopup addItemsWithTitles:[EatsScaleGenerator scaleTypeNames]];
    self.tonicNote = 60;
}



#pragma Mark - Action methods

- (IBAction)scaleTypePopup:(NSPopUpButton *)sender {
    if( [sender indexOfSelectedItem] == EatsScaleType_DrumMap ) {
        self.previousTonicNote = [NSNumber numberWithInt:[self.tonicNoteTextField intValue]];
        self.tonicNote = 35;
        self.tonicNoteTextField.enabled = NO;
        
    } else {
        // Puts back the revious tonic if we're returning from a drum map
        if( self.previousTonicNote ) {
            self.tonicNote = [self.previousTonicNote unsignedIntValue];
            self.previousTonicNote = nil;
        }
        self.tonicNoteTextField.enabled = YES;
    }
}

- (IBAction)generateButton:(NSButton *)sender {
    [self endSheetWithReturnCode:NSOKButton];
}

- (IBAction)cancelButton:(NSButton *)sender {
    [self endSheetWithReturnCode:NSCancelButton];
}


@end
