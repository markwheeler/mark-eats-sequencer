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
    
    // Get the page state
    SequencerState *sharedSequencerState = [SequencerState sharedSequencerState];
    SequencerPageState *pageState = [sharedSequencerState.pageStates objectAtIndex:_currentPageId];
    
    // Get the notes
    
    __block NSArray *matches;
    
    [self.managedObjectContext performBlockAndWait:^(void) {
        NSError *requestError = nil;
        NSFetchRequest *noteRequest = [NSFetchRequest fetchRequestWithEntityName:@"SequencerNote"];
        
        noteRequest.predicate = [NSPredicate predicateWithFormat:@"(inPattern.id == %u) AND (inPattern.inPage.id == %@)", _currentPageId, pageState.currentPatternId];
        matches = [self.managedObjectContext executeFetchRequest:noteRequest error:&requestError];
        
        if( requestError )
            NSLog(@"Request error: %@", requestError);
    }];
    
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
            
            // Colours
            __block float fillBrightness;
            __block float strokeBrightness;
            
            [self.managedObjectContext performBlockAndWait:^(void) {
                
                // Notes
                if( NSNotFound != [matches indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
                    
                    if ( [[obj valueForKey:@"step"] isEqualTo:[NSNumber numberWithInt:c]] && [[obj valueForKey:@"row"] isEqualTo:[NSNumber numberWithInt:r]] ) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                    
                }] ) {
                    fillBrightness = 0;
                    strokeBrightness = 0;
                    
                // Play head
                } else if( c == pageState.currentStep.intValue ) {
                    fillBrightness = 0.6;
                    strokeBrightness = 0.5;
                    
                // Active area
                } else if( c < _gridWidth && r < _gridHeight ) {
                    fillBrightness = 0.85;
                    strokeBrightness = 0.7;
                    
                // Inactive area
                } else {
                    fillBrightness = 0.9;
                    strokeBrightness = 0.8;
                }
            }];
            
            
            // Fill
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:fillBrightness alpha:1] set];
            [roundedRect fill];
            
            
            // Stroke
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:strokeBrightness alpha:1] set];
            [roundedRect setLineWidth:2.0];
            [roundedRect stroke];
        }
    }
}

@end
