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
#import "SequencerNote.h"
#import "Sequencer+Utils.h"

@interface EatsDebugGridView ()

@property SequencerState        *sharedSequencerState;

@property NSNumber              *noteBrightness;
@property NSNumber              *lengthBrightness;
@property NSNumber              *playheadBrightness;
@property NSNumber              *nextStepBrightness;
@property NSNumber              *backgroundBrightness;

@property NSNumber              *noteBrightnessInactive;
@property NSNumber              *lengthBrightnessInactive;
@property NSNumber              *playheadBrightnessInactive;
@property NSNumber              *nextStepBrightnessInactive;
@property NSNumber              *backgroundBrightnessInactive;

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
        
        // Brightness settings
        self.noteBrightness = [NSNumber numberWithFloat:0.0];
        self.lengthBrightness = [NSNumber numberWithFloat:0.6];
        self.playheadBrightness = [NSNumber numberWithFloat:0.6];
        self.nextStepBrightness = [NSNumber numberWithFloat:0.7];
        self.backgroundBrightness = [NSNumber numberWithFloat:0.8];
        
        float stateModifier = 0.1;
        
        self.noteBrightnessInactive = [NSNumber numberWithFloat:self.noteBrightness.floatValue + 0.5];
        self.lengthBrightnessInactive = [NSNumber numberWithFloat:self.lengthBrightness.floatValue + stateModifier];
        self.playheadBrightnessInactive = [NSNumber numberWithFloat:self.playheadBrightness.floatValue + stateModifier];
        self.nextStepBrightnessInactive = [NSNumber numberWithFloat:self.nextStepBrightness.floatValue + stateModifier];
        self.backgroundBrightnessInactive = [NSNumber numberWithFloat:self.backgroundBrightness.floatValue + stateModifier];
    }
    
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL) becomeFirstResponder
{
    self.needsDisplay = YES;
    
    return [super becomeFirstResponder];
}

- (BOOL) resignFirstResponder
{
    self.needsDisplay = YES;
    
    return [super becomeFirstResponder];
}

- (void)cut:(id)sender {
    if( [self.delegate respondsToSelector:@selector(cutPattern:inPage:)] )
       [self.delegate performSelector:@selector(cutPattern:inPage:) withObject:[NSNumber numberWithUnsignedInt:[self getCurrentPatternId]] withObject:[NSNumber numberWithUnsignedInt:_currentPageId]];
}

- (void)copy:(id)sender {
    if( [self.delegate respondsToSelector:@selector(copyPattern:inPage:)] )
        [self.delegate performSelector:@selector(copyPattern:inPage:) withObject:[NSNumber numberWithUnsignedInt:[self getCurrentPatternId]] withObject:[NSNumber numberWithUnsignedInt:_currentPageId]];
}

- (void)paste:(id)sender {
    if( [self.delegate respondsToSelector:@selector(pastePattern:inPage:)] )
        [self.delegate performSelector:@selector(pastePattern:inPage:) withObject:[NSNumber numberWithUnsignedInt:[self getCurrentPatternId]] withObject:[NSNumber numberWithUnsignedInt:_currentPageId]];
}

- (uint) getCurrentPatternId
{
    // Get the page state
    SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:_currentPageId];
    
    uint patternId;
    
    // If pattern quantization is disabled
    if( !_patternQuantizationOn && pageState.nextPatternId )
        patternId = pageState.nextPatternId.unsignedIntValue;
    
    else
        patternId = pageState.currentPatternId.unsignedIntValue;
    
    return patternId;
}

- (BOOL) validateMenuItem:(id <NSValidatedUserInterfaceItem>)menuItem
{
    SEL menuAction = menuItem.action;
    
    if ( menuAction == @selector(cut:) || menuAction == @selector(copy:) )
    {
        if ( _currentPattern.notes.count ) {
            return YES;
        } else {
            return NO;
        }
    
    } else if ( menuAction == @selector(paste:) ) {
        
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        if( [[pasteboard.types lastObject] isEqual: self.pasteboardType] )
            return YES;
        else
            return NO;
        
    } else {
        return YES;
    }
}

- (void)keyDown:(NSEvent *)theEvent {
    
    if( self.window.firstResponder == self ) {
        if( [_delegate respondsToSelector:@selector(keyDownFromEatsDebugGridView:withModifierFlags:)] )
            [_delegate performSelector:@selector(keyDownFromEatsDebugGridView:withModifierFlags:)
                            withObject:[NSNumber numberWithUnsignedShort:theEvent.keyCode]
                            withObject:[NSNumber numberWithUnsignedInteger:theEvent.modifierFlags]];
        
    }
    
    [super keyDown:theEvent];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if( !self.currentPattern )
        return;
    
    // Get the page state
    SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:_currentPageId];
    
    // Generate the columns with playhead and nextStep
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:_columns];
    
    BOOL active;
    
    for(uint x = 0; x < _columns; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:_rows] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < _rows; y++) {
            
            // Active / inactive
            if( x < _gridWidth && y < _gridHeight )
                active = YES;
            else
                active = NO;
            
            if( x == pageState.currentStep.intValue ) {
                if( active )
                    [[viewArray objectAtIndex:x] insertObject:_playheadBrightness atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:_playheadBrightnessInactive atIndex:y];
                
            } else if( pageState.nextStep && x == pageState.nextStep.intValue ) {
                if( active )
                    [[viewArray objectAtIndex:x] insertObject:_nextStepBrightness atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:_nextStepBrightnessInactive atIndex:y];
                
            } else {
                if( active )
                    [[viewArray objectAtIndex:x] insertObject:_backgroundBrightness atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:_backgroundBrightnessInactive atIndex:y];
            }
            
        }
    }

    // Put all the notes in the viewArray    
//    NSLog(@"Drawing from pattern %@", _currentPattern);
    
    for(SequencerNote *note in _currentPattern.notes) {
        
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
            if( tailDraw < _gridWidth && note.row.intValue < _gridHeight ) {
                if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:note.row.intValue] floatValue] > _lengthBrightness.floatValue )
                    [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:note.row.intValue withObject:_lengthBrightness];
            } else {
                if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:note.row.intValue] floatValue] > _lengthBrightnessInactive.floatValue )
                    [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:note.row.intValue withObject:_lengthBrightnessInactive];
            }
            
            
        }
        
        // Active / inactive
        if( note.step.intValue < _gridWidth && note.row.intValue < _gridHeight )
            // Put the notes in
            [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:note.row.intValue withObject:_noteBrightness];
        else
            // Put the notes in
            [[viewArray objectAtIndex:note.step.intValue] replaceObjectAtIndex:note.row.intValue withObject:_noteBrightnessInactive];
        
    }
    
    
    // Draw the viewArray

    // Focus ring
    [NSGraphicsContext saveGraphicsState];
    
    if( self.window.firstResponder == self ) {
        NSSetFocusRingStyle(NSFocusRingBelow);
    }
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:NSInsetRect([self bounds], 4.0, 5.0)];
    [[NSColor windowBackgroundColor] set];
    [path stroke];
    [path fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    // Margin to allow focus ring to fit
    CGFloat margin = 10;
    
    // Set the square size and corner radius – use floor() around these two lines to make squares sit 'on pixel'
    CGFloat squareWidth = ((self.bounds.size.width - ( margin * 2 ) + _gutter) / _columns) - _gutter;
    CGFloat squareHeight = ((self.bounds.size.height - ( margin * 2 )  + _gutter) / _rows) - _gutter;
    
    CGFloat squareSize;
    if(squareWidth < squareHeight) squareSize = squareWidth;
    else squareSize = squareHeight;
    
    // Don't bother if we're too small
    if(squareSize < 3) return;
    
    CGFloat cornerRadius = squareSize * 0.1;
    
    for( int r = 0; r < _rows; r++ ){
        for( int c = 0; c < _columns; c++ ) {
            // Draw shape
            NSRect rect = NSMakeRect(margin + ((squareSize + _gutter) * c), margin + ((squareSize + _gutter) * r), squareSize, squareSize);
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
