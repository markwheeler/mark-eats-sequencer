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
#import "SequencerState.h"
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

- (id) initWithManagedObjectContext:(NSManagedObjectContext *)context andQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        
        _isActive = NO;
        _managedObjectContext = context;
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        _sharedPreferences = [Preferences sharedPreferences];
        
        _bigSerialQueue = queue;
        
        // Get the sequencer
        [self.managedObjectContext performBlockAndWait:^(void) {
            NSError *requestError = nil;
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
            
            NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);
            
            _sequencer = [matches lastObject];

        }];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerNone:)
                                                     name:@"GridControllerNone"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridControllerConnected:)
                                                     name:@"GridControllerConnected"
                                                   object:nil];
        
        if(_sharedPreferences.gridType != EatsGridType_None) {
            _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext andQueue:_bigSerialQueue width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
            _currentView = EatsGridViewType_Sequencer;
        }
        
        // Set the page and keep an eye on pattern changes
        [self setNewPageId:[NSNumber numberWithInt:0]];

    }
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
}



- (void) updateGridView
{
    if([_currentViewController respondsToSelector:@selector(updateView)] && _isActive)
        [_currentViewController performSelector:@selector(updateView)];
}

- (void) updateUI
{
    if( [_delegate respondsToSelector:@selector(updateUI)] )
       [_delegate performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void) showView:(NSNumber *)gridView
{    
    if([gridView intValue] == _currentView) return;
    
    if([gridView intValue] == EatsGridViewType_Intro) {
        _currentViewController = [[EatsGridIntroViewController alloc] initWithDelegate:self width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
    } else if([gridView intValue] == EatsGridViewType_Sequencer) {
        _currentViewController = [[EatsGridSequencerViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext andQueue:_bigSerialQueue width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
    } else if([gridView intValue] == EatsGridViewType_Play) {
        _currentViewController = [[EatsGridPlayViewController alloc] initWithDelegate:self managedObjectContext:_managedObjectContext andQueue:_bigSerialQueue width:_sharedPreferences.gridWidth height:_sharedPreferences.gridHeight];
        
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
        
    } else if(_sharedPreferences.gridType == EatsGridType_Launchpad && _sharedPreferences.gridMIDINodeName) {
        //if(![_deviceInterface isKindOfClass:[EatsLaunchpad class])
        //    _deviceInterface = [[EatsLaunchpad alloc] initWithMIDINode:_gridMIDINodeName];
        
    }
    
    if(_sharedPreferences.gridType != EatsGridType_None && [_deviceInterface respondsToSelector:@selector(redrawGridController:)])
        [_deviceInterface performSelector:@selector(redrawGridController:) withObject:gridArray];

}

- (void) setNewPageId:(NSNumber *)pageId
{
    [_currentSequencerPageState removeObserver:self forKeyPath:@"currentPatternId"];
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        SequencerPage *page = [_sequencer.pages objectAtIndex:pageId.unsignedIntegerValue];
        _currentSequencerPageState = [[[SequencerState sharedSequencerState] pageStates] objectAtIndex:pageId.unsignedIntegerValue];
        _currentPattern =  [page.patterns objectAtIndex:_currentSequencerPageState.currentPatternId.unsignedIntegerValue];
        
        [_currentSequencerPageState addObserver:self forKeyPath:@"currentPatternId" options:NSKeyValueObservingOptionNew context:NULL];
    }];
}

- (void) updatePattern
{
    [self.managedObjectContext performBlockAndWait:^(void) {
        SequencerPage *page = _currentPattern.inPage;
        _currentPattern =  [page.patterns objectAtIndex:_currentSequencerPageState.currentPatternId.unsignedIntegerValue];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    if ( object == _currentSequencerPageState && [keyPath isEqual:@"currentPatternId"] ) {
        [self updatePattern];
    }
}


@end