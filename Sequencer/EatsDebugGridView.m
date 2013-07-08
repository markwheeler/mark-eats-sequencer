//
//  EatsDebugGridView.m
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsDebugGridView.h"
#import "SequencerState.h"
#import "SequencerPageState.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"

@interface EatsDebugGridView ()

@property SequencerState        *sharedSequencerState;

@end

@implementation EatsDebugGridView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.columns = 16;
        self.rows = 16;
        
        self.gutter = 6;
        
        self.gridWidth = self.columns;
        self.gridHeight = self.rows;
        
        self.currentPageId = 0;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if( !self.managedObjectContext )
        return;

    // Brightness settings
    float noteBrightness = 0.0;
    float lengthBrightness = 0.6;
    float playheadBrightness = 0.6;
    float nextStepBrightness = 0.7;
    float backgroundBrightness = 0.8;
    
    // Get the page state
    SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:_currentPageId];
    
    // Generate the columns with playhead and nextStep
    __block NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:_columns];
    
    __block float stateModifier;
    
    for(uint x = 0; x < _columns; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:_rows] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < _rows; y++) {
            
            // Active / inactive
            if( x < _gridWidth && y < _gridHeight )
                stateModifier = 0;
            else
                stateModifier = 0.1;
            
            if( x == pageState.currentStep.intValue )
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:playheadBrightness + stateModifier] atIndex:y];
            else if( pageState.nextStep && x == pageState.nextStep.intValue )
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:nextStepBrightness + stateModifier] atIndex:y];
            else
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithFloat:backgroundBrightness + stateModifier] atIndex:y];
            
        }
    }
    
    // Put all the notes in the viewArray
    [self.managedObjectContext performBlockAndWait:^(void) {
        
        NSArray *matches;
        
        NSError *requestError = nil;
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerPattern"];
        
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(id == %@) AND (inPage.id == %u)", pageState.currentPatternId, _currentPageId];
        matches = [self.managedObjectContext executeFetchRequest:noteRequest error:&requestError];
        
        SequencerPattern *pattern = [matches lastObject];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
        
        for(SequencerNote *note in pattern.notes) {
            
            // Put the length tails in
            int tailDraw = note.step.intValue;
            int length =  note.length.intValue - 1;
            if( length > _columns - 1)
                length = _columns - 1;
            
            for( int i = 0; i < length; i++ ) {
                if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse )
                    tailDraw --;
                else
                    tailDraw ++;
                
                if( tailDraw < 0 )
                    tailDraw += _columns;
                else if( tailDraw >= _columns )
                    tailDraw -= _columns;
                
                // Active / inactive
                if( tailDraw < _gridWidth && note.row.intValue < _gridHeight )
                    stateModifier = 0;
                else
                    stateModifier = 0.1;
                
                if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:note.row.intValue] floatValue] > lengthBrightness + stateModifier )
                    [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:note.row.intValue withObject:[NSNumber numberWithFloat:lengthBrightness + stateModifier]];
                
            }
            
            // Active / inactive
            if( note.step.intValue < _gridWidth && note.row.intValue < _gridHeight )
                stateModifier = 0;
            else
                stateModifier = 0.5;
            
            // Put the notes in
            [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:note.row.intValue withObject:[NSNumber numberWithFloat:noteBrightness + stateModifier]];

        }

    }];
    
    
    
    // Draw the viewArray
    
    // Background color for testing
    //[[NSColor colorWithCalibratedHue:0.5 saturation:0.7 brightness:1.0 alpha:1] set];
    //NSRectFill(dirtyRect);
    
    // Set the square size and corner radius – use floor() around these two lines to make squares sit 'on pixel'
    CGFloat squareWidth = ((self.bounds.size.width + _gutter) / _columns) - _gutter;
    CGFloat squareHeight = ((self.bounds.size.height + _gutter) / _rows) - _gutter;
    
    CGFloat squareSize;
    if(squareWidth < squareHeight) squareSize = squareWidth;
    else squareSize = squareHeight;
    
    // Don't bother if we're too small
    if(squareSize < 3) return;
    
    CGFloat cornerRadius = squareSize * 0.1;
    
    for( int r = 0; r < _rows; r++ ){
        for( int c = 0; c < _columns; c++ ) {
            // Draw shape
            NSRect rect = NSMakeRect((squareSize + _gutter) * c, (squareSize + _gutter) * r, squareSize, squareSize);
            NSBezierPath *roundedRect = [NSBezierPath bezierPathWithRoundedRect: rect xRadius:cornerRadius yRadius:cornerRadius];
            
            // Set clip so we can do an 'inner' stroke
            [roundedRect setClip];
            
            // Fill
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:[[[viewArray objectAtIndex:c] objectAtIndex:r] floatValue] alpha:1] set];
            [roundedRect fill];
            
            
            // Stroke
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:[[[viewArray objectAtIndex:c] objectAtIndex:r] floatValue] - 0.1 alpha:1] set];
            [roundedRect setLineWidth:2.0];
            [roundedRect stroke];
            
        }
    }
}

@end
