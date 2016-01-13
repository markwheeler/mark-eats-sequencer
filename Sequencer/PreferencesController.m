//
//  PreferencesController.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "PreferencesController.h"
#import "InputMappingOutlineViewController.h"

@interface PreferencesController ()

@property EatsCommunicationManager                     *sharedCommunicationManager;
@property Preferences                                  *sharedPreferences;

@property (nonatomic, weak) IBOutlet NSToolbar         *preferencesToolbar;
@property (nonatomic, weak) IBOutlet NSTabView         *preferencesTabView;

@property (nonatomic, weak) IBOutlet NSPopUpButton     *gridControllerPopup;
@property (nonatomic, weak) IBOutlet NSTextField       *gridControllerStatus;
@property (nonatomic, weak) IBOutlet NSSlider          *gridControllerRotation;

@property (nonatomic, weak) IBOutlet NSOutlineView     *inputMappingOutlineView;

@property (nonatomic, weak) IBOutlet NSTableColumn     *midiDestinationsEnableColumn;
@property (nonatomic, weak) IBOutlet NSTableColumn     *midiDestinationsNameColumn;
@property (nonatomic, weak) IBOutlet NSArrayController *midiDestinationsArrayController;

@property (nonatomic, weak) IBOutlet NSPopUpButton     *tiltMIDIOutputChannelPopup;

@property (nonatomic, weak) IBOutlet NSPopUpButton     *clockSourcePopup;

@property (nonatomic) InputMappingOutlineViewController *inputMappingOutlineViewController;

@end

@implementation PreferencesController

- (id) initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
    }
    
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.preferencesToolbar setSelectedItemIdentifier:@"0"];

    // Populate
    [self updateAvailableGridDevices];
    [self updateMIDI];
    
    // Tilt output
    [self.tiltMIDIOutputChannelPopup removeAllItems];
    [self.tiltMIDIOutputChannelPopup addItemWithTitle:[NSString stringWithFormat:@"None"]];
    for( int i = 1; i <= NUMBER_OF_MIDI_CHANNELS; i ++ ) {
        [self.tiltMIDIOutputChannelPopup addItemWithTitle:[NSString stringWithFormat:@"%i", i]];
    }
    if( self.sharedPreferences.tiltMIDIOutputChannel )
        [self.tiltMIDIOutputChannelPopup selectItemAtIndex:self.sharedPreferences.tiltMIDIOutputChannel.integerValue + 1];
    else
        [self.tiltMIDIOutputChannelPopup selectItemAtIndex:0];
    
    [self populateInputMapping];
    
    
    // Notifications
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerNone:)
                                                 name:kGridControllerNoneNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnecting:)
                                                 name:kGridControllerConnectingNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerConnectionError:)
                                                 name:kGridControllerConnectionErrorNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerCalibrating:)
                                                 name:kGridControllerCalibratingNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gridControllerDoneCalibrating:)
                                                 name:kGridControllerDoneCalibratingNotification
                                               object:nil];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Public methods

- (void) updateAvailableGridDevices
{
    [self.gridControllerPopup removeAllItems];
    [self.gridControllerPopup addItemWithTitle:@"None"];
    
    for( EatsGridDevice *gridDevice in self.sharedCommunicationManager.availableGridDevices ) {
        
        [self.gridControllerPopup addItemWithTitle:gridDevice.displayName];
        
        // Set popup to active controller
        if( gridDevice.type == EatsGridType_Monome && [gridDevice.label isEqualToString:self.sharedPreferences.gridMonomeId] ) {
            [self.gridControllerPopup selectItemAtIndex:[self.gridControllerPopup indexOfItemWithTitle:gridDevice.displayName]];
            
            // And set the status correctly
            if( self.sharedPreferences.gridType != EatsGridType_None ) {
                if( self.sharedPreferences.gridTiltSensorIsCalibrating )
                    [self gridControllerCalibrating:nil];
                else
                    [self gridControllerDoneCalibrating:nil];
            }
        }
        
    }
}

- (void) updateMIDI
{
    [self.clockSourcePopup removeAllItems];
    
	// Populate the clock source popup
    [self.clockSourcePopup addItemWithTitle:@"Internal"];
    [self.clockSourcePopup addItemWithTitle:self.sharedCommunicationManager.midiManager.virtualSource.name];
    for (NSString *s in self.sharedCommunicationManager.midiManager.sourceNodeNameArray) {
        [self.clockSourcePopup addItemWithTitle:s];
    }
    // Select the clock source and if we can't find it then reset to 'internal'
    if( self.sharedPreferences.midiClockSourceName ) {
        NSMenuItem *menuItem = [self.clockSourcePopup itemWithTitle:self.sharedPreferences.midiClockSourceName];
        if( menuItem )
            [self.clockSourcePopup selectItem:menuItem];
    }
    
    
    // Clear the destinations table view
    NSRange range = NSMakeRange(0, [self.midiDestinationsArrayController.arrangedObjects count]);
    [self.midiDestinationsArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    
    // Update the table's ArrayController with the list of devices and states
    for (int i = 0; i < [self.sharedCommunicationManager.midiManager.destNodeNameArray count]; i++) {
        NSMutableDictionary *value = [[NSMutableDictionary alloc] init];
        
        [value setObject:self.sharedCommunicationManager.midiManager.destNodeNameArray[i]
                  forKey:@"deviceName"];
        [value setObject:[NSNumber numberWithBool:[[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:i] enabled]]
                  forKey:@"enabled"];
        
        [self.midiDestinationsArrayController addObject:value];
    }
}



#pragma mark - Private methods

- (NSArray *) sequencerFunctionPaths
{
    NSMutableArray *functionPaths = [NSMutableArray arrayWithCapacity:64];
    
    // Sequencer
    NSMutableArray *sequencerChildren = [NSMutableArray array];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"BPM" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"IncrementBPM" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"DecrementBPM" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"StepQuantization" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"IncrementStepQuantization" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"DecrementStepQuantization" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"PatternQuantization" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"IncrementPatternQuantization" forKey:@"path"]];
    [sequencerChildren addObject:[NSDictionary dictionaryWithObject:@"DecrementPatternQuantization" forKey:@"path"]];
    [functionPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Sequencer", @"path", sequencerChildren, @"children", nil]];
    
    // Pages
    for( int i = 0; i < kSequencerNumberOfPages + 3; i ++ ) {
        
        NSMutableArray *pageChildren = [NSMutableArray array];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"LoopStart" forKey:@"path"]];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"IncrementLoopStart" forKey:@"path"]];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"DecrementLoopStart" forKey:@"path"]];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"LoopEnd" forKey:@"path"]];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"IncrementLoopEnd" forKey:@"path"]];
        [pageChildren addObject:[NSDictionary dictionaryWithObject:@"DecrementLoopEnd" forKey:@"path"]];
        
        NSString *pageName;
        if( i == 0 )
            pageName = [NSString stringWithFormat:@"CurrentPage"];
        else if( i == 1 )
            pageName = [NSString stringWithFormat:@"AllPages"];
        else if( i == 2 )
            pageName = [NSString stringWithFormat:@"AllPagesExceptCurrentPage"];
        else
            pageName = [NSString stringWithFormat:@"Page%i", i - 2];
        [functionPaths addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageName, @"path", pageChildren, @"children", nil]];
    }
    
    // TODO: Lots more here
    
    return functionPaths;
}

- (void) populateInputMapping
{
    // Sets up the input tab
    
    self.inputMappingOutlineViewController = [[InputMappingOutlineViewController alloc] init];
    //    self.inputMappingOutlineView.dataSource = self.inputMappingViewController;
    self.inputMappingOutlineView.delegate = self.inputMappingOutlineViewController;
    
    // Move this to outline view controller?
    NSMutableArray *inputMapping = [NSMutableArray array];
    
    NSMutableArray *channels = [NSMutableArray arrayWithCapacity:NUMBER_OF_MIDI_CHANNELS];
    for( int i = 1; i <= NUMBER_OF_MIDI_CHANNELS; i ++ ) {
        [channels addObject:[NSNumber numberWithInt:i]];
    }
    
    NSArray *functionPaths = [self sequencerFunctionPaths]; // TODO
    
    for( NSDictionary *elem in functionPaths ) {
    
        // If it has children (everything should)
        if( [elem objectForKey:@"children"] ) {
            
            NSMutableDictionary *parent = [NSMutableDictionary dictionaryWithObjectsAndKeys:[elem objectForKey:@"path"], @"path", nil];
            
            // This is a branch
            [parent setObject:[NSNumber numberWithBool:NO] forKey:@"isLeaf"];
            
            NSArray *elemChildren = [elem objectForKey:@"children"];
            NSMutableArray *parentChildren = [NSMutableArray arrayWithCapacity:elemChildren.count];
            
            // Go through all the children
            for( NSDictionary *elemChild in elemChildren ) {
                NSDictionary *parentChild = [NSDictionary dictionaryWithObjectsAndKeys:[elemChild objectForKey:@"path"], @"path",
                                                                                       [NSString stringWithFormat:@"Hi"], @"a",
                                                                                       [NSArray arrayWithObjects:@"None", @"MIDI Device 1", @"MIDI Device 2", nil], @"device",
                                                                                       [NSArray arrayWithObjects:@"C3", @"G2", nil], @"noteOrCC",
                                                                                       [NSArray arrayWithObjects:[NSNumber numberWithInt:1], [NSNumber numberWithInt:2], [NSNumber numberWithInt:3], nil], @"channel",
                                                                                       [NSNumber numberWithInt:12], @"min",
                                                                                       [NSNumber numberWithInt:111], @"max",
                                                                                       [NSNumber numberWithBool:YES], @"isLeaf",
                                                                                       nil];
                
                [parentChildren addObject:parentChild];
                
                // TODO: Set the node according to preferences
                // Prefs format idea: basically the same as above but instead of the lists of things it has to have the selected item (device string, channel int, etc)
                //[self.sharedPreferences.inputMappings objectAtIndex:0];
            }
            
            // Add the children to the parent
            [parent setObject:parentChildren forKey:@"children"];
            
            // Add the node
            [inputMapping addObject:parent];
        }
        
        
    }
    
    self.inputMappingData = [inputMapping mutableCopy];

    
}

- (void) gridControllerNone:(NSNotification *)notification
{    
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

- (void) gridControllerCalibrating:(NSNotification *)notification
{
    [self.gridControllerStatus setStringValue:[NSString stringWithFormat:@"Calibrating tilt sensor..."]];
}

- (void) gridControllerDoneCalibrating:(NSNotification *)notification
{
    [self.gridControllerStatus setStringValue:[NSString stringWithFormat:@"Connected OK"]];
}



#pragma mark - Interface actions

- (IBAction) preferencesToolbarAction:(NSToolbarItem *)sender {
    [self.preferencesTabView selectTabViewItemAtIndex:[sender tag]];
}

- (IBAction) gridControllerPopup:(NSPopUpButton *)sender {
    
    // Find the output port corresponding to the label of the selected item
    NSInteger selectedItem = [sender indexOfSelectedItem];
    
    // A device
	if ( selectedItem > 0 ) {
        
        // First set to none to clear the grid
        [self.delegate performSelector:@selector(gridControllerNone)];
        // Then reset the menu
        [sender selectItemAtIndex:selectedItem];
        
        // Then connect
        EatsGridDevice *gridDevice = [self.sharedCommunicationManager.availableGridDevices objectAtIndex:selectedItem - 1];
        [self.delegate performSelector:@selector(gridControllerConnectToDevice:) withObject:gridDevice];
        
        // Make an educated guess about varibright support
        self.sharedPreferences.gridSupportsVariableBrightness = gridDevice.probablySupportsVariableBrightness;
        
    // None
    } else {
        self.sharedPreferences.gridMonomeId = nil;
        self.sharedPreferences.gridMIDINodeName = nil;
        [self.delegate performSelector:@selector(gridControllerNone)];
    }
}

- (IBAction)supportsVariableBrightnessCheckbox:(NSButton *)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesThatRequiresGridRedrawDidChangeNotification object:self];
}

- (IBAction)gridControllerRotationSlider:(NSSlider *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kGridControllerSetRotationNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesThatRequiresGridRedrawDidChangeNotification object:self];
}

- (IBAction) midiOutputCheckbox:(id)sender {
    // Get the name and search for it in the array of saved names
    NSString *nodeName = [[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:[sender clickedRow]] name];
    NSUInteger nameIndex = [self.sharedPreferences.enabledMIDIOutputNames indexOfObject:nodeName];
    
    // Disable
    if([[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:[sender clickedRow]] enabled]) {
        [[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:[sender clickedRow]] setEnabled:NO];
        
        // Remove the name if it's in the saved array
        if( nameIndex != NSNotFound )
            [self.sharedPreferences.enabledMIDIOutputNames removeObjectAtIndex:nameIndex];
        
    // Enable
    } else {
        [[self.sharedCommunicationManager.midiManager.destArray lockObjectAtIndex:[sender clickedRow]] setEnabled:YES];
        
        // Add the name if it's not in the saved array
        if( nameIndex == NSNotFound )
            [self.sharedPreferences.enabledMIDIOutputNames addObject:nodeName];
    }
    
}

- (IBAction)tiltMIDIOutputChannelPopup:(NSPopUpButton *)sender
{
    if( sender.indexOfSelectedItem > 0 && sender.indexOfSelectedItem <= NUMBER_OF_MIDI_CHANNELS ) {
        self.sharedPreferences.tiltMIDIOutputChannel = [NSNumber numberWithInteger:sender.indexOfSelectedItem - 1];
        
    } else {
        self.sharedPreferences.tiltMIDIOutputChannel = nil;
    }
}

- (IBAction)clockSourcePopup:(NSPopUpButton *)sender
{
    // Internal clock
	if (sender.indexOfSelectedItem <= 0) {
        self.sharedPreferences.midiClockSourceName = nil;
        
    // Our own virtual node
    } else if (sender.indexOfSelectedItem == 1) {
        self.sharedPreferences.midiClockSourceName = self.sharedCommunicationManager.midiManager.virtualSource.name;
        
    // An external node
    } else {
        self.sharedPreferences.midiClockSourceName = [[self.sharedCommunicationManager.midiManager findSourceNodeNamed:[sender titleOfSelectedItem]] name];
    }
}
- (IBAction)showNoteLengthOnGridCheckbox:(NSButton *)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesThatRequiresGridRedrawDidChangeNotification object:self];
}

@end