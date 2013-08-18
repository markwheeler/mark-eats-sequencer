//
//  ScaleGeneratorSheetController.m
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ScaleGeneratorSheetController.h"
#import "WMPool+Utils.h"

#define DRUM_MAP @"Drum map"

@interface ScaleGeneratorSheetController ()

@property (weak) IBOutlet NSPopUpButton *scaleModePopup;
@property (weak) IBOutlet NSTextField   *tonicNoteTextField;

@property NSString                      *previousTonicNoteName;

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
    [self.scaleModePopup removeAllItems];
    [self.scaleModePopup addItemsWithTitles:[[[[WMPool pool] scaleDefinitions] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
    [self.scaleModePopup addItemWithTitle:DRUM_MAP];
    if( self.indexOfLastSelectedScaleMode )
        self.scaleMode = [self.scaleModePopup.itemTitles objectAtIndex:self.indexOfLastSelectedScaleMode];
    else
        self.scaleMode = WMScaleModeIonianMajor;
    if( !self.tonicNoteName )
        self.tonicNoteName = @"C3";
}



#pragma Mark - Action methods
- (IBAction)scaleModePopup:(NSPopUpButton *)sender {
    
    if( [sender indexOfSelectedItem] == [sender indexOfItemWithTitle:DRUM_MAP] ) {
        self.previousTonicNoteName = self.tonicNoteTextField.stringValue;
        self.tonicNoteName = @"B0";
        self.tonicNoteTextField.enabled = NO;

    } else {
        // Puts back the revious tonic if we're returning from a drum map
        if( self.previousTonicNoteName ) {
            self.tonicNoteName = self.previousTonicNoteName;
            self.previousTonicNoteName = nil;
        }
        self.tonicNoteTextField.enabled = YES;
    }
}

- (IBAction)generateButton:(NSButton *)sender {
    
    self.indexOfLastSelectedScaleMode = self.scaleModePopup.indexOfSelectedItem;
    
    // Check for drum map
    if( [self.scaleMode isEqualToString:DRUM_MAP] )
        self.scaleMode = WMScaleModeChromatic;
    
    self.tonicNoteName = self.tonicNoteTextField.stringValue;
    
    [self endSheetWithReturnCode:NSOKButton];
}

- (IBAction)cancelButton:(NSButton *)sender {
    [self endSheetWithReturnCode:NSCancelButton];
}


@end
