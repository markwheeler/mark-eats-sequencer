
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

- (void) setIsActive:(BOOL)isActive
{
    @synchronized( self ) {
        _isActive = isActive;
    }
    
    if(self.currentView) {
        dispatch_async(self.currentViewController.gridQueue, ^(void) {
            [self.currentViewController updateView];
        });
    }
}

- (BOOL) isActive
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
        self.sequencer = sequencer;
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
                
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerNone:) name:kGridControllerNoneNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerConnected:) name:kGridControllerConnectedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridControllerSizeChanged:) name:kGridControllerSizeChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesThatRequiresGridRedrawDidChange:) name:kPreferencesThatRequiresGridRedrawDidChangeNotification object:nil];
        
        if(self.sharedPreferences.gridType != EatsGridType_None) {
            self.currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
            self.currentView = EatsGridViewType_Sequencer;
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
    if( [self.currentViewController respondsToSelector:@selector(stopAnimation)] )
        [self.currentViewController performSelector:@selector(stopAnimation)];
    
    if( [gridView intValue] == self.currentView )
        self.currentViewController = nil;
    
    if( [gridView intValue] == EatsGridViewType_Intro ) {
        self.currentViewController = [[EatsGridIntroViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else if( [gridView intValue] == EatsGridViewType_Sequencer ) {
        self.currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else if( [gridView intValue] == EatsGridViewType_Play ) {
        self.currentViewController = [[EatsGridPlayViewController alloc] initWithDelegate:self andSequencer:self.sequencer width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    } else {
        self.currentViewController = nil;
        if( [self.deviceInterface respondsToSelector:@selector(clearGridController)] )
            [self.deviceInterface performSelector:@selector(clearGridController)];
    }
    
    self.currentView = [gridView intValue];
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

- (void) gridControllerSizeChanged:(NSNotification *)notification
{
    if(self.currentViewController) {
    
        // Only IntroView supports resizing
        
        if( self.currentView != EatsGridViewType_Intro )
            [self showView:[NSNumber numberWithInt:EatsGridViewType_Intro]];
        
        else {
            dispatch_async(self.currentViewController.gridQueue, ^(void) {
                
                self.currentViewController.width = self.sharedPreferences.gridWidth;
                self.currentViewController.height = self.sharedPreferences.gridHeight;
                
                [self.currentViewController updateView];
            });
        }
    }
}

- (void) preferencesThatRequiresGridRedrawDidChange:(NSNotification *)notification
{
    if(self.currentView) {
        dispatch_async(self.currentViewController.gridQueue, ^(void) {
            [self.currentViewController updateView];
        });
    }
}



#pragma mark - GridView delegate methods

- (void) updateGridWithArray:(NSArray *)gridArray
{        
    // Only send msgs to the grid controller if we're the active document
    if( !self.isActive ) return;
    
    if(self.sharedPreferences.gridType == EatsGridType_Monome && self.sharedCommunicationManager.oscOutPort) {
        if(![self.deviceInterface isKindOfClass:[EatsMonome class]])
            self.deviceInterface = [[EatsMonome alloc] initWithOSCPort:self.sharedCommunicationManager.oscOutPort oscPrefix:self.sharedCommunicationManager.oscPrefix];
        
    } else if(self.sharedPreferences.gridType == EatsGridType_Launchpad && self.sharedPreferences.gridMIDINodeName) {
        //if(![self.deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    self.deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:self.sharedPreferences.gridMIDINodeName];
        
    }
    
    if(self.sharedPreferences.gridType != EatsGridType_None && [self.deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [self.deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];

}


@end