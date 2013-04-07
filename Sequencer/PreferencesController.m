//
//  PreferencesController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "PreferencesController.h"

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

- (id) initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.preferencesToolbar setSelectedItemIdentifier:@"0"];
    
    self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
    self.sharedPreferences = [Preferences sharedPreferences];

    // Populate
    [self updateOSC];
    [self updateMIDI];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerNone:)
                                                 name:@"GridControllerNone"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnecting:)
                                                 name:@"GridControllerConnecting"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnectionError:)
                                                 name:@"GridControllerConnectionError"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnected:)
                                                 name:@"GridControllerConnected"
                                               object:nil];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Public methods

// TODO – Detect monome disconnects. MLRV seems able to do this!

- (void) updateOSC
{
    NSArray *oscPortLabelArray = [self.sharedCommunicationManager.oscManager outPortLabelArray];
    
    [self.gridControllerPopup removeAllItems];
    [self.gridControllerPopup addItemWithTitle:@"None"];
    [self.gridControllerStatus setStringValue:@""];
    
    for (NSString *s in oscPortLabelArray) {
        
        // Avoid listing the app's port
        if(![s isEqualToString:self.sharedCommunicationManager.oscOutputPortLabel])
            [self.gridControllerPopup addItemWithTitle:s];
        
        // Set popup to active controller
        if( [s isEqualToString:self.sharedPreferences.gridOSCLabel] ) {
            [self.gridControllerPopup selectItemAtIndex:[self.gridControllerPopup indexOfItemWithTitle:s] ];
            [self gridControllerConnected:nil];
        }
            
    }
}

- (void) updateMIDI
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

- (void) gridControllerNone:(NSNotification *)notification
{
    
    self.sharedPreferences.gridType = EatsGridType_None;
    self.sharedPreferences.gridWidth = 32;
    self.sharedPreferences.gridHeight = 32;
    
    [self.gridControllerPopup selectItemAtIndex:0];
    [self.gridControllerStatus setStringValue:@""];
}

- (void) gridControllerConnectionError:(NSNotification *)notification
{
    [self.gridControllerStatus setStringValue:@"❌ Error connecting to grid controller"];
}

- (void) gridControllerConnecting:(NSNotification *)notification
{
    [self.gridControllerStatus setStringValue:@"Trying to connect..."];
}

- (void) gridControllerConnected:(NSNotification *)notification
{
    NSString *gridName;
    if(self.sharedPreferences.gridType == EatsGridType_Monome)
        gridName = [NSString stringWithFormat:@"monome %u", self.sharedPreferences.gridWidth * self.sharedPreferences.gridHeight];
    else if(self.sharedPreferences.gridType == EatsGridType_Launchpad)
        gridName = @"Launchpad";
    
    [self.gridControllerStatus setStringValue:[NSString stringWithFormat:@"Connected OK to %@", gridName]];
}



#pragma mark - Interface actions

- (IBAction) preferencesToolbarAction:(NSToolbarItem *)sender {
    [self.preferencesTabView selectTabViewItemAtIndex:[sender tag]];
}

- (IBAction) gridControllerPopup:(NSPopUpButton *)sender {
    
    // Find the output port corresponding to the label of the selected item
	if ([sender indexOfSelectedItem] > 0) {
        [self.delegate performSelector:@selector(gridControllerConnectToDeviceType:withOSCLabelOrMIDINode:) withObject:[NSNumber numberWithInt:EatsGridType_Monome] withObject:[sender titleOfSelectedItem]];
    } else {
        self.sharedPreferences.gridOSCLabel = nil;
        self.sharedPreferences.gridMIDINode = nil;
        [self.delegate performSelector:@selector(gridControllerNone)];
    }
}


@end