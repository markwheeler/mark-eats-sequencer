//
//  EatsDebugGridView.m
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsDebugGridView.h"
#import "Sequencer.h"
#import "SequencerNote.h"

@interface EatsDebugGridView ()

@property (nonatomic) float                 noteBrightness;
@property (nonatomic) float                 lengthBrightness;
@property (nonatomic) NSNumber              *playheadBrightness;
@property (nonatomic) NSNumber              *nextStepBrightness;
@property (nonatomic) NSNumber              *backgroundBrightness;

@property (nonatomic) NSNumber              *noteBrightnessInactive;
@property (nonatomic) NSNumber              *lengthBrightnessInactive;
@property (nonatomic) NSNumber              *playheadBrightnessInactive;
@property (nonatomic) NSNumber              *nextStepBrightnessInactive;
@property (nonatomic) NSNumber              *backgroundBrightnessInactive;

@property (nonatomic) NSArray               *bezierPathsForFills;
@property (nonatomic) NSArray               *bezierPathsForStrokes;

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
        
        // Brightness settings
        self.noteBrightness = 0.0;
        self.lengthBrightness = 0.55;
        self.playheadBrightness = [NSNumber numberWithFloat:0.6];
        self.nextStepBrightness = [NSNumber numberWithFloat:0.7];
        self.backgroundBrightness = [NSNumber numberWithFloat:0.8];
        
        float stateModifier = 0.1;
        
        self.noteBrightnessInactive = [NSNumber numberWithFloat:self.noteBrightness + 0.5];
        self.lengthBrightnessInactive = [NSNumber numberWithFloat:self.lengthBrightness + stateModifier];
        self.playheadBrightnessInactive = [NSNumber numberWithFloat:self.playheadBrightness.floatValue + stateModifier];
        self.nextStepBrightnessInactive = [NSNumber numberWithFloat:self.nextStepBrightness.floatValue + stateModifier];
        self.backgroundBrightnessInactive = [NSNumber numberWithFloat:self.backgroundBrightness.floatValue + stateModifier];
        
        [self generateBezierPaths];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidResize:) name:NSViewFrameDidChangeNotification object:self];
    }
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (void) cut:(id)sender
{
    if( [self.delegate respondsToSelector:@selector(cutCurrentPattern)] )
       [self.delegate performSelector:@selector(cutCurrentPattern)];
}

- (void) copy:(id)sender
{
    if( [self.delegate respondsToSelector:@selector(copyCurrentPattern)] )
        [self.delegate performSelector:@selector(copyCurrentPattern)];
}

- (void) paste:(id)sender
{
    if( [self.delegate respondsToSelector:@selector(pasteToCurrentPattern)] )
        [self.delegate performSelector:@selector(pasteToCurrentPattern)];
}

- (void) delete:(id)sender
{
    if( [self.delegate respondsToSelector:@selector(clearPatternStartAlert)] )
        [self.delegate performSelector:@selector(clearPatternStartAlert)];
}

- (BOOL) validateMenuItem:(id <NSValidatedUserInterfaceItem>)menuItem
{
    SEL menuAction = menuItem.action;
    
    if ( menuAction == @selector(cut:) || menuAction == @selector(copy:) )
    {
        if ( self.notes.count ) {
            return YES;
        } else {
            return NO;
        }
    
    } else if ( menuAction == @selector(paste:) ) {
        
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        if( [[pasteboard.types lastObject] isEqual: kSequencerNotesDataPasteboardType] )
            return YES;
        else
            return NO;
        
    } else if ( menuAction == @selector(delete:) )
        {
            if ( self.notes.count ) {
                return YES;
            } else {
                return NO;
            }
        
    } else {
        return YES;
    }
}

-(void) mouseEntered:(NSEvent *)theEvent
{
    if( [_delegate respondsToSelector:@selector(debugGridViewMouseEntered)] )
        [_delegate performSelector:@selector(debugGridViewMouseEntered)];
}

-(void) mouseExited:(NSEvent *)theEvent
{
    if( [_delegate respondsToSelector:@selector(debugGridViewMouseExited)] )
        [_delegate performSelector:@selector(debugGridViewMouseExited)];
}

-(void) updateTrackingAreas
{
    if( self.trackingAreas != nil ) {
        [self removeTrackingArea:[self.trackingAreas lastObject]];
    }
    
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    NSTrackingArea *trackingArea = [ [NSTrackingArea alloc] initWithRect:[self bounds]
                                                 options:opts
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void) keyDown:(NSEvent *)theEvent
{
    
    if( self.window.firstResponder == self ) {
        if( [_delegate respondsToSelector:@selector(keyDownFromEatsDebugGridView:withModifierFlags:)] )
            [_delegate performSelector:@selector(keyDownFromEatsDebugGridView:withModifierFlags:)
                            withObject:[NSNumber numberWithUnsignedShort:theEvent.keyCode]
                            withObject:[NSNumber numberWithUnsignedInteger:theEvent.modifierFlags]];
        
    }
    
    [super keyDown:theEvent];
}

- (void) viewDidResize:(NSNotification *)notification
{
    [self generateBezierPaths];
}

- (void) generateBezierPaths
{
    // Generate all the bezier paths only when needed rather than every draw cycle
    // This will need to be called if the view resizes
    
    // Margin to allow focus ring to fit
    CGFloat margin = 10;
    
    // Set the square size and corner radius – use floor() around these two lines to make squares sit 'on pixel'
    CGFloat squareWidth = ((self.bounds.size.width - ( margin * 2 ) + _gutter) / _columns) - _gutter;
    CGFloat squareHeight = ((self.bounds.size.height - ( margin * 2 )  + _gutter) / _rows) - _gutter;
    
    CGFloat squareSize;
    if( squareWidth < squareHeight )
        squareSize = squareWidth;
    else
        squareSize = squareHeight;
    
    // Don't bother if we're too small
    //if(squareSize < 3)
    //    return;
    
    CGFloat cornerRadius = squareSize * 0.1;
    
    NSMutableArray *pathsForFills = [NSMutableArray arrayWithCapacity:_rows];
    NSMutableArray *pathsForStrokes = [NSMutableArray arrayWithCapacity:_rows];
    
    for( int r = 0; r < _rows; r++ ){
        
        NSMutableArray *rowForFills = [NSMutableArray arrayWithCapacity:_columns];
        [pathsForFills addObject:rowForFills];
        NSMutableArray *rowForStrokes = [NSMutableArray arrayWithCapacity:_columns];
        [pathsForStrokes addObject:rowForStrokes];
        
        for( int c = 0; c < _columns; c++ ) {
            // Draw shape
            NSRect rectForFill = NSMakeRect(margin + ((squareSize + _gutter) * c), margin + ((squareSize + _gutter) * r), squareSize, squareSize);
            NSBezierPath *roundedRectForFill = [NSBezierPath bezierPathWithRoundedRect:rectForFill xRadius:cornerRadius yRadius:cornerRadius];
            [rowForFills addObject:roundedRectForFill];
            
            NSRect rectForStroke = NSMakeRect(rectForFill.origin.x + 0.5, rectForFill.origin.y + 0.5, rectForFill.size.width - 1, rectForFill.size.height - 1);
            NSBezierPath *roundedRectForStroke = [NSBezierPath bezierPathWithRoundedRect:rectForStroke xRadius:cornerRadius yRadius:cornerRadius];
            [rowForStrokes
             addObject:roundedRectForStroke];
        }
    }
    
    _bezierPathsForFills = pathsForFills;
    _bezierPathsForStrokes = pathsForStrokes;
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( !self.notes )
        return;
    
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
            
            if( x == self.currentStep ) {
                if( active )
                    [[viewArray objectAtIndex:x] insertObject:_playheadBrightness atIndex:y];
                else
                    [[viewArray objectAtIndex:x] insertObject:_playheadBrightnessInactive atIndex:y];
                
            } else if( self.nextStep && x == self.nextStep.intValue ) {
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
    
    for(SequencerNote *note in self.notes) {
        
        // Used for calculating brightness based on note velocity
        float velocityPercentage = (float)note.velocity / SEQUENCER_MIDI_MAX;
        
        // Put the length tails in
        int tailDraw = note.step;
        int length;
        
        // Don't draw trails for notes outside of grid
        if( note.step > self.gridWidth - 1 )
            length = 0;
        else
            length = note.length - 1;
        
        if( length > _gridWidth - 1 )
            length = _gridWidth - 1;
        
        for( int i = 0; i < length; i++ ) {
            if( self.drawNotesForReverse )
                tailDraw --;
            else
                tailDraw ++;
            
            if( tailDraw < 0 )
                tailDraw += _gridWidth;
            else if( tailDraw >= _gridWidth )
                tailDraw -= _gridWidth;
            
            // Active / inactive
            if( tailDraw < _gridWidth && note.row < _gridHeight ) {
                float velocityTailBrightness = 0.1 * ( 1.0 - velocityPercentage );
                NSNumber *lengthBrightnessWithVelocity = [NSNumber numberWithFloat:_lengthBrightness + velocityTailBrightness];
                if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:note.row] floatValue] > lengthBrightnessWithVelocity.floatValue )
                    [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:note.row withObject:lengthBrightnessWithVelocity];
            } else {
                if( [[[viewArray objectAtIndex:tailDraw] objectAtIndex:note.row] floatValue] > _lengthBrightnessInactive.floatValue )
                    [[viewArray objectAtIndex:tailDraw] replaceObjectAtIndex:note.row withObject:_lengthBrightnessInactive];
            }
            
            
        }
        
        // Active / inactive
        if( note.step < _gridWidth && note.row < _gridHeight ) {
            // Put the notes in
            float velocityNoteBrightness = 0.4 * ( 1.0 - velocityPercentage );
            NSNumber *noteBrightnessWithVelocity = [NSNumber numberWithFloat:_noteBrightness + velocityNoteBrightness];
            [[viewArray objectAtIndex:note.step] replaceObjectAtIndex:note.row withObject:noteBrightnessWithVelocity];
        } else
            // Put the notes in
            [[viewArray objectAtIndex:note.step] replaceObjectAtIndex:note.row withObject:_noteBrightnessInactive];
        
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
    
    for( int r = 0; r < _rows; r++ ){
        for( int c = 0; c < _columns; c++ ) {
            
            [NSGraphicsContext saveGraphicsState];
            
            // Fill
            NSBezierPath *roundedRectForFill = [[_bezierPathsForFills objectAtIndex:r] objectAtIndex:c];
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:[[[viewArray objectAtIndex:c] objectAtIndex:r] floatValue] alpha:1] set];
            [roundedRectForFill fill];
            
            // Stroke
            NSBezierPath *roundedRectForStroke = [[_bezierPathsForStrokes objectAtIndex:r] objectAtIndex:c];
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:[[[viewArray objectAtIndex:c] objectAtIndex:r] floatValue] - 0.1 alpha:1] set];
            [roundedRectForStroke setLineWidth:1.0];
            [roundedRectForStroke stroke];
            
            [NSGraphicsContext restoreGraphicsState];
            
        }
    }
}

@end
