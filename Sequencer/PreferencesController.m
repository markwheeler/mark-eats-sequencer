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

@property (weak) IBOutlet NSTableColumn *midiDestinationsEnableColumn;
@property (weak) IBOutlet NSTableColumn *midiDestinationsNameColumn;
@property (weak) IBOutlet NSArrayController *midiDestinationsArrayController;

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
    
    self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];

    // Populate
    [self updateGridControllers];
    [self updateMIDI];
}



#pragma mark - Public methods

- (void)updateGridControllers
{
    NSArray *monomePortLabelArray = [self.sharedCommunicationManager.oscManager outPortLabelArray];
    
    [self.gridControllerPopup removeAllItems];
    [self.gridControllerPopup addItemWithTitle:@"None"];
    
    for (NSString *s in monomePortLabelArray) {
        // Avoid listing the app's port
        if(![s isEqualToString:self.sharedCommunicationManager.oscOutputPortLabel])
            [self.gridControllerPopup addItemWithTitle:s];
    }
}

- (void)updateMIDI
{
    [self.clockSourcePopup removeAllItems];
    
	// Push the labels to the pop-up button of destinations
    [self.clockSourcePopup addItemWithTitle:@"Internal"];
    [self.clockSourcePopup addItemWithTitle:self.sharedCommunicationManager.midiManager.virtualSource.name];
    for (NSString *s in self.sharedCommunicationManager.midiManager.sourceNodeNameArray) {
        [self.clockSourcePopup addItemWithTitle:s];
    }
    
    //[self clockSourcePopup:nil]; Call Action
    
    
    // Clear the destinations table view
    NSRange range = NSMakeRange(0, [self.midiDestinationsArrayController.arrangedObjects count]);
    [self.midiDestinationsArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    
    // Update the table's ArrayController with the list of devices and states
    for (int i = 0; i < [self.sharedCommunicationManager.midiManager.destNodeNameArray count]; i++) {
        NSMutableDictionary *value = [[NSMutableDictionary alloc] init];
        
        [value setObject:(NSString *)self.sharedCommunicationManager.midiManager.destNodeNameArray[i]
                  forKey:@"deviceName"];
        [value setObject:[NSNumber numberWithBool:[[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:i] enabled]]
                  forKey:@"enabled"];
        
        [self.midiDestinationsArrayController addObject:value];
    }
}


- (IBAction)preferencesToolbarAction:(NSToolbarItem *)sender {
    [self.preferencesTabView selectTabViewItemAtIndex:[sender tag]];
}


@end
