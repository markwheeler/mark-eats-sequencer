//
//  EatsGridNavigationController.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridNavigationController.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "EatsMonome.h"
#import "EatsGridIntroView.h"
#import "EatsGridSequencerView.h"
#import "EatsGridPlayView.h"

@interface EatsGridNavigationController ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsGridView                  currentView;
@property NSObject                      *currentViewObject;
@property id                            deviceInterface;

@end

@implementation EatsGridNavigationController

#pragma mark - public methods

- (id) init
{
    self = [super init];
    if (self) {
        
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerNone:)
                                                     name:@"GridControllerNone" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerConnected:)
                                                     name:@"GridControllerConnected" object:nil];

    }
    return self;
}

- (void) updateGridView
{
    if([self.currentViewObject respondsToSelector:@selector(updateView)]) {
        [self.currentViewObject performSelector:@selector(updateView)];
    }
}

- (void) showView:(EatsGridView)gridView
{
    if(gridView == self.currentView) return;
    
    if(gridView == EatsGridView_Intro) {
        self.currentViewObject = [[EatsGridIntroView alloc] initWithDelegate:self width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
    } else if(gridView == EatsGridView_Sequencer) {
        self.currentViewObject = [[EatsGridSequencerView alloc] initWithDelegate:self width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
    } else if(gridView == EatsGridView_Play) {
        self.currentViewObject = [[EatsGridPlayView alloc] initWithDelegate:self width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
    } else {
        self.currentViewObject = nil;
        if([self.deviceInterface respondsToSelector:@selector(clearGridController)])
            [self.deviceInterface performSelector:@selector(clearGridController)];
    }
    
    self.currentView = gridView;
}


#pragma mark - notifications

- (void)gridControllerNone:(NSNotification *)notification
{
    [self showView:EatsGridView_None];
}

- (void)gridControllerConnected:(NSNotification *)notification
{
    [self showView:EatsGridView_Intro];
}


#pragma mark - GridView delegate methods

- (void) updateGridWithArray:(NSArray *)gridArray
{
    if(self.sharedPreferences.gridType == EatsGridType_Monome && self.sharedCommunicationManager.oscOutPort) {
        if(![self.deviceInterface isKindOfClass:[EatsMonome class]])
            self.deviceInterface = [[EatsMonome alloc] initWithOSCPort:self.sharedCommunicationManager.oscOutPort oscPrefix:self.sharedCommunicationManager.oscPrefix];
        
    } else if(self.sharedPreferences.gridType == EatsGridType_Launchpad && self.sharedPreferences.gridMIDINode) {
        //if(![self.deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    self.deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:self.gridMIDINode];
        
    }
    
    if(self.sharedPreferences.gridType != EatsGridType_None && [self.deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [self.deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];
}

@end
