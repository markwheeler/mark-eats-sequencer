
//  EatsGridNavigationController.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.


#import "EatsGridNavigationController.h"
#import "EatsDocumentController.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "SequencerState.h"
#import "EatsMonome.h"
#import "EatsGridIntroViewController.h"
#import "EatsGridSequencerViewController.h"
#import "EatsGridPlayViewController.h"

@interface EatsGridNavigationController ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsGridViewType              currentView;
@property EatsGridView                  *currentViewController;
@property id                            deviceInterface;

@end

@implementation EatsGridNavigationController

@synthesize isActive = _isActive;

#pragma mark - Setters and getters

- (void)setIsActive:(BOOL)isActive
{
    @synchronized( self ) {
        _isActive = isActive;
    }
    
    if(self.currentView)
       [self.currentViewController updateView];
}

- (BOOL)isActive
{
    BOOL result;
    @synchronized( self ) {
        result = _isActive;
    }
    return result;
}

#pragma mark - public methods

- (id) initWithSequencer:(Sequencer *)sequencer
{
    self = [super init];
    if (self) {
        
        _isActive = NO;
        _sequencer = sequencer;
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
                
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerNone:) name:@"GridControllerNone" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerConnected:) name:@"GridControllerConnected" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesThatRequiresGridRedrawDidChange:) name:kPreferencesThatRequiresGridRedrawDidChangeNotification object:nil];
        
        if(self.sharedPreferences.gridType != EatsGridType_None) {
            _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
            _currentView = EatsGridViewType_Sequencer;
        }

    }
    return self;
}

- (void) dealloc {
//    NSLog(@"%s", __func__);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) showView:(NSNumber *)gridView
{    
    if( [gridView intValue] == _currentView ) return;
    
    if( [_currentViewController respondsToSelector:@selector(stopAnimation)] )
        [_currentViewController performSelector:@selector(stopAnimation)];
    
    if( [gridView intValue] == EatsGridViewType_Intro ) {
        _currentViewController = [[EatsGridIntroViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else if( [gridView intValue] == EatsGridViewType_Sequencer ) {
        _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else if( [gridView intValue] == EatsGridViewType_Play ) {
// TODO        _currentViewController = [[EatsGridPlayViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext andQueue:_bigSerialQueue width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else {
        _currentViewController = nil;
        if( [_deviceInterface respondsToSelector:@selector(clearGridController)] )
            [_deviceInterface performSelector:@selector(clearGridController)];
    }
    
    _currentView = [gridView intValue];
}



#pragma mark - Notifications

- (void) gridControllerNone:(NSNotification *)notification
{
    [self showView:[NSNumber numberWithInt:EatsGridViewType_None]];
}

- (void) gridControllerConnected:(NSNotification *)notification
{
    [self showView:[NSNumber numberWithInt:EatsGridViewType_Intro]];
}

- (void) preferencesThatRequiresGridRedrawDidChange:(NSNotification *)notification
{
    if(self.currentView)
        [self.currentViewController updateView];
}



#pragma mark - GridView delegate methods

- (void) updateGridWithArray:(NSArray *)gridArray
{        
    // Only send msgs to the grid controller if we're the active document
    if( !_isActive ) return;
    
    if(self.sharedPreferences.gridType == EatsGridType_Monome && _sharedCommunicationManager.oscOutPort) {
        if(![_deviceInterface isKindOfClass:[EatsMonome class]])
            _deviceInterface = [[EatsMonome alloc] initWithOSCPort:_sharedCommunicationManager.oscOutPort oscPrefix:_sharedCommunicationManager.oscPrefix];
        
    } else if(self.sharedPreferences.gridType == EatsGridType_Launchpad && self.sharedPreferences.gridMIDINodeName) {
        //if(![_deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    _deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:self.sharedPreferences.gridMIDINodeName];
        
    }
    
    if(self.sharedPreferences.gridType != EatsGridType_None && [_deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [_deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];

}


@end