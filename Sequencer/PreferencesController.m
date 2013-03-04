//
//  PreferencesController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "PreferencesController.h"

@interface PreferencesController ()
@property (weak) IBOutlet NSToolbar *preferencesToolbar;
@property (weak) IBOutlet NSTabView *preferencesTabView;

@property (weak) IBOutlet NSPopUpButton *gridControllerPopup;
@property (weak) IBOutlet NSPopUpButton *clockSourcePopup;

@end

@implementation PreferencesController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.preferencesToolbar setSelectedItemIdentifier:@"0"];
    
    // Populate
    
}
- (IBAction)preferencesToolbarAction:(NSToolbarItem *)sender {
    [self.preferencesTabView selectTabViewItemAtIndex:[sender tag]];
}


@end
