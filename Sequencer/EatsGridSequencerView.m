//
//  EatsGridSequencerView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSequencerView.h"
#import "SequencerPage.h"
#import "EatsGridUtils.h"
#import "EatsGridPatternView.h"
#import "EatsGridHorizontalSliderView.h"

@interface EatsGridSequencerView ()

@property SequencerPage                 *page;
@property EatsGridPatternView           *patternView;
@property EatsGridHorizontalSliderView  *velocityView;
@property EatsGridHorizontalSliderView  *lengthView;

@end

@implementation EatsGridSequencerView

- (void) setupView
{
    NSLog(@"%s", __func__);
    
    // Get the page
    NSFetchRequest *pageRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPage"];
    pageRequest.predicate = [NSPredicate predicateWithFormat:@"id == 0"];
    
    NSArray *pageMatches = [self.managedObjectContext executeFetchRequest:pageRequest error:nil];
    self.page = [pageMatches lastObject];
    
    // Create the sub views
    self.patternView = [[EatsGridPatternView alloc] init];
    self.patternView.delegate = self;
    self.patternView.managedObjectContext = self.managedObjectContext;
    self.patternView.x = 0;
    self.patternView.y = 0;
    self.patternView.width = self.width;
    self.patternView.height = self.height;
    self.patternView.mode = EatsPatternViewMode_Edit;
    self.patternView.pattern = [self.page.patterns objectAtIndex:0];     // TODO
    
    self.velocityView = [[EatsGridHorizontalSliderView alloc] init];
    self.velocityView.delegate = self;
    self.velocityView.managedObjectContext = self.managedObjectContext;
    self.velocityView.x = 0;
    self.velocityView.y = 0;
    self.velocityView.width = self.width;
    self.velocityView.height = 1;
    self.velocityView.visible = NO;
    
    self.lengthView = [[EatsGridHorizontalSliderView alloc] init];
    self.lengthView.delegate = self;
    self.lengthView.managedObjectContext = self.managedObjectContext;
    self.lengthView.x = 0;
    self.lengthView.y = 1;
    self.lengthView.width = self.width;
    self.lengthView.height = 1;
    self.lengthView.visible = NO;
    
    self.subViews = [[NSMutableSet alloc] initWithObjects:self.patternView,
                                                          self.velocityView,
                                                          self.lengthView,
                                                          nil];
}

- (void) enterNoteEditMode
{
    self.velocityView.visible = YES;
    self.lengthView.visible = YES;
    self.patternView.y = 2;
    self.patternView.height = self.height - 2;
    self.patternView.mode = EatsPatternViewMode_NoteEdit;
    [self updateView];
}

- (void) exitNoteEditMode
{
    self.velocityView.visible = NO;
    self.lengthView.visible = NO;
    self.patternView.y = 0;
    self.patternView.height = self.height;
    self.patternView.mode = EatsPatternViewMode_Edit;
    [self updateView];
}

- (void) updateView
{
    NSMutableSet *views = [[NSMutableSet alloc] initWithCapacity:3];
    
    // PatternView sub view
    self.patternView.currentStep = [self.page.currentStep unsignedIntValue];
    NSArray *patternViewArray = [self.patternView viewArray];
    [views addObject:[NSDictionary dictionaryWithObjectsAndKeys:patternViewArray, @"viewArray",
                                                                [NSNumber numberWithUnsignedInt:self.patternView.x], @"x",
                                                                [NSNumber numberWithUnsignedInt:self.patternView.y], @"y",
                                                                [NSNumber numberWithUnsignedInt:self.patternView.width], @"width",
                                                                [NSNumber numberWithUnsignedInt:self.patternView.height], @"height",
                                                                nil]];
    // VelocityView sub view
    NSArray *velocityViewArray = [self.velocityView viewArray];
    [views addObject:[NSDictionary dictionaryWithObjectsAndKeys:velocityViewArray, @"viewArray",
                                                               [NSNumber numberWithUnsignedInt:self.velocityView.x], @"x",
                                                               [NSNumber numberWithUnsignedInt:self.velocityView.y], @"y",
                                                               [NSNumber numberWithUnsignedInt:self.velocityView.width], @"width",
                                                               [NSNumber numberWithUnsignedInt:self.velocityView.height], @"height",
                                                               nil]];
    // LengthView sub view
    NSArray *lengthViewArray = [self.lengthView viewArray];
    [views addObject:[NSDictionary dictionaryWithObjectsAndKeys:lengthViewArray, @"viewArray",
                                                               [NSNumber numberWithUnsignedInt:self.lengthView.x], @"x",
                                                               [NSNumber numberWithUnsignedInt:self.lengthView.y], @"y",
                                                               [NSNumber numberWithUnsignedInt:self.lengthView.width], @"width",
                                                               [NSNumber numberWithUnsignedInt:self.lengthView.height], @"height",
                                                               nil]];

    
    // Combine all the sub views
    NSArray *gridArray = [EatsGridUtils combineSubViews:views gridWidth:self.width gridHeight:self.height];
    
    // Send msg to delegate
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

@end