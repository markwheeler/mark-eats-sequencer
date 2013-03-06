//
//  PreferencesController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "PreferencesController.h"
#import "EatsMonome.h"

@interface PreferencesController ()

@property EatsCommunicationManager          *sharedCommunicationManager;
@property Preferences                       *sharedPreferences;

@property (weak) IBOutlet NSToolbar         *preferencesToolbar;
@property (weak) IBOutlet NSTabView         *preferencesTabView;

@property (weak) IBOutlet NSPopUpButton     *gridControllerPopup;
@property (weak) IBOutlet NSTextField       *gridControllerStatus;

@property (weak) IBOutlet NSTableColumn     *midiDestinationsEnableColumn;
@property (weak) IBOutlet NSTableColumn     *midiDestinationsNameColumn;
@property (weak) IBOutlet NSArrayController *midiDestinationsArrayController;

@property (weak) IBOutlet NSPopUpButton     *clockSourcePopup;

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
    self.sharedPreferences = [Preferences sharedPreferences];

    // Populate
    [self updateGridControllers];
    [self updateMIDI];
}



#pragma mark - Public methods

- (void)updateGridControllers
{
    // Should try and reconnect here but for now we're just going to 'none' state
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerNone" object:self];
    self.sharedPreferences.gridType = EatsGridType_None;
    
    NSArray *monomePortLabelArray = [self.sharedCommunicationManager.oscManager outPortLabelArray];
    
    [self.gridControllerPopup removeAllItems];
    [self.gridControllerPopup addItemWithTitle:@"None"];
    [self.gridControllerStatus setStringValue:@""];
    
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

- (void)gridControllerConnected:(EatsGridType)gridType width:(uint)w height:(uint)h
{
   
    // Set the prefs, making sure the width is divisible by 8
    self.sharedPreferences.gridType = EatsGridType_Monome;
    self.sharedPreferences.gridWidth = w - (w % 8);
    self.sharedPreferences.gridHeight = h - (h % 8);
    
    // Let everyone know
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerConnected" object:self];
    
    // Update the UI
    NSString *gridName;
    if(gridType == EatsGridType_Monome) gridName = [NSString stringWithFormat:@"monome %u", w*h];
    if(gridType == EatsGridType_Launchpad) gridName = @"Launchpad";
    
    [self.gridControllerStatus setStringValue:[NSString stringWithFormat:@"Connected to %@", gridName]];
}



#pragma mark - Interface actions

- (IBAction)preferencesToolbarAction:(NSToolbarItem *)sender {
    [self.preferencesTabView selectTabViewItemAtIndex:[sender tag]];
}

- (IBAction)gridControllerPopup:(NSPopUpButton *)sender {
    
    // Set none
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GridControllerNone" object:self];
    self.sharedPreferences.gridType = EatsGridType_None;
    
    [self.gridControllerStatus setStringValue:@""];
    OSCOutPort *selectedPort = nil;
    
    // Figure out the index of the selected item
	if ([sender indexOfSelectedItem] <= -1)
		return;
    // Find the output port corresponding to the label of the selected item
    selectedPort = [self.sharedCommunicationManager.oscManager findOutputWithLabel:[sender titleOfSelectedItem]];
	if (selectedPort == nil)
		return;
    
    // Set the OSC Out Port
    //NSLog(@"Selected OSC out address %@", [selectedPort addressString]);
    //NSLog(@"Selected OSC out port %@", [NSString stringWithFormat:@"%d",[selectedPort port]]);
    [self.sharedCommunicationManager.oscOutPort setAddressString:[selectedPort addressString] andPort:[selectedPort port]];
    
    [self.gridControllerStatus setStringValue:@"Trying to connect..."];
    [EatsMonome connectToMonomeAtPort:self.sharedCommunicationManager.oscOutPort
                             fromPort:self.sharedCommunicationManager.oscInPort
                           withPrefix:self.sharedCommunicationManager.oscPrefix];
}


@end