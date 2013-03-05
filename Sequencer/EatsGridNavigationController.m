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

@interface EatsGridNavigationController ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property NSObject                      *currentView;
@property id                            deviceInterface;

@end

@implementation EatsGridNavigationController

- (id)init
{
    self = [super init];
    if (self) {
        
        self.sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        self.sharedPreferences = [Preferences sharedPreferences];
        
        self.currentView = [[EatsGridIntroView alloc] initWithDelegate:self width:self.sharedPreferences.gridWidth height:self.sharedPreferences.gridHeight];
        
    }
    return self;
}

- (void)updateGridView
{
    if([self.currentView respondsToSelector:@selector(updateView)])
        [self.currentView performSelector:@selector(updateView)];
}

- (void)updateGridWithArray:(NSArray *)gridArray
{

    if(self.sharedPreferences.gridType == EatsGridType_Monome && self.sharedCommunicationManager.oscOutPort) {
        if(![self.deviceInterface isKindOfClass:[EatsMonome class]])
            self.deviceInterface = [[EatsMonome alloc] initWithOSCPort:self.sharedCommunicationManager.oscOutPort oscPrefix:self.sharedCommunicationManager.oscPrefix];
        
    } else if(self.sharedPreferences.gridType == EatsGridType_Launchpad && self.sharedPreferences.gridMIDINode) {
        //if(![self.deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    self.deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:self.gridMIDINode];
        
    }
    
    if([self.deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [self.deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];
}

@end
