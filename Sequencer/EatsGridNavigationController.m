//
//  EatsGridNavigationController.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridNavigationController.h"
#import "EatsDocumentController.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "EatsMonome.h"
#import "EatsGridIntroViewController.h"
#import "EatsGridSequencerViewController.h"
#import "EatsGridPlayViewController.h"

@interface EatsGridNavigationController ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property EatsGridViewType              currentView;
@property NSObject                      *currentViewController;
@property id                            deviceInterface;

@end

@implementation EatsGridNavigationController

#pragma mark - public methods

- (id) initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super init];
    if (self) {
        
        _isActive = NO;
        _managedObjectContext = context;
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        _sharedPreferences = [Preferences sharedPreferences];
        
        // Get the pattern
        NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
        patternRequest.predicate = [NSPredicate predicateWithFormat:@"(inPage.id == 0) AND (id == inPage.currentPatternId)"];
        
        NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
        _pattern = [patternMatches lastObject];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerNone:)
                                                     name:@"GridControllerNone"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerConnected:)
                                                     name:@"GridControllerConnected"
                                                   object:nil];
        
        if(_sharedPreferences.gridType != EatsGridType_None) {
            _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
            _currentView = EatsGridViewType_Sequencer;
        }

    }
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void) updateGridView
{
    if([_currentViewController respondsToSelector:@selector(updateView)] && _isActive) {
        [_currentViewController performSelector:@selector(updateView)];
    }
}

- (void) showView:(NSNumber *)gridView
{    
    if([gridView intValue] == _currentView) return;
    
    if([gridView intValue] == EatsGridViewType_Intro) {
        _currentViewController = [[EatsGridIntroViewController alloc] initWithDelegate:self width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
    } else if([gridView intValue] == EatsGridViewType_Sequencer) {
        _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
    } else if([gridView intValue] == EatsGridViewType_Play) {
        _currentViewController = [[EatsGridPlayViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
    } else {
        _currentViewController = nil;
        if([_deviceInterface respondsToSelector:@selector(clearGridController)])
            [_deviceInterface performSelector:@selector(clearGridController)];
    }
    
    _currentView = [gridView intValue];
}



#pragma mark - notifications

- (void) gridControllerNone:(NSNotification *)notification
{
    [self showView:[NSNumber numberWithInt:EatsGridViewType_None]];
}

- (void) gridControllerConnected:(NSNotification *)notification
{
    [self showView:[NSNumber numberWithInt:EatsGridViewType_Intro]];
}



#pragma mark - GridView delegate methods

- (void) updateGridWithArray:(NSArray *)gridArray
{        
    // Only send msgs to the grid controller if we're the active document
    if( !_isActive ) return;
    
    if(_sharedPreferences.gridType == EatsGridType_Monome && _sharedCommunicationManager.oscOutPort) {
        if(![_deviceInterface isKindOfClass:[EatsMonome class]])
            _deviceInterface = [[EatsMonome alloc] initWithOSCPort:_sharedCommunicationManager.oscOutPort oscPrefix:_sharedCommunicationManager.oscPrefix];
        
    } else if(_sharedPreferences.gridType == EatsGridType_Launchpad && _sharedPreferences.gridMIDINode) {
        //if(![_deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    _deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:_gridMIDINode];
        
    }
    
    if(_sharedPreferences.gridType != EatsGridType_None && [_deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [_deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];

}

- (void) setNewPageId:(NSNumber *)id
{
    // Get the page
    NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
    pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == %@", id];
    
    NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
    SequencerPage *page = [pageMatches lastObject];
    
    // Get the pattern for it
    _pattern = [page.patterns objectAtIndex:page.currentPatternId.intValue];

}

- (void) setNewPatternId:(NSNumber *)id
{
    // Get the pattern
    NSFetchRequest *patternRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
    patternRequest.predicate = [NSPredicate predicateWithFormat:@"(inPage == %@) AND (id == %@)", _pattern.inPage, id];

    NSArray *patternMatches = [self.managedObjectContext executeFetchRequest:patternRequest error:nil];
    _pattern = [patternMatches lastObject];
    
    _pattern.inPage.currentPatternId = id;
}



@end