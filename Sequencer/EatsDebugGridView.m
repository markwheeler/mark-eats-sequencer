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

@property (nonatomic) BOOL                  gridHasChanged;

@property (nonatomic) float                 noteBrightness;
@property (nonatomic) float                 lengthBrightness;
@property (nonatomic) NSNumber              *playheadBrightness;
@property (nonatomic) NSNumber              *nextStepBrightness;
@property (nonatomic) NSNumber              *backgroundBrightness;

@property (nonatomic) NSNumber              *emptyBrightness;
@property (nonatomic) NSNumber              *noteBrightnessInactive;
@property (nonatomic) NSNumber              *lengthBrightnessInactive;
@property (nonatomic) NSNumber              *playheadBrightnessInactive;
@property (nonatomic) NSNumber              *nextStepBrightnessInactive;
@property (nonatomic) NSNumber              *backgroundBrightnessInactive;

@property (nonatomic) NSImage               *backgroundGridImage;
@property (nonatomic) NSImage               *completeGridImage;
@property (nonatomic) NSBezierPath          *backgroundBezierPath;
@property (nonatomic) NSArray               *bezierPathsForFills;
@property (nonatomic) NSArray               *bezierPathsForStrokes;

@end

@implementation EatsDebugGridView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.gridHasChanged = NO;
        
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
        
        self.emptyBrightness = [NSNumber numberWithInt:-1];
        self.noteBrightnessInactive = [NSNumber numberWithFloat:self.noteBrightness + 0.5];
        self.lengthBrightnessInactive = [NSNumber numberWithFloat:self.lengthBrightness + stateModifier];
        self.playheadBrightnessInactive = [NSNumber numberWithFloat:self.playheadBrightness.floatValue + stateModifier];
        self.nextStepBrightnessInactive = [NSNumber numberWithFloat:self.nextStepBrightness.floatValue + stateModifier];
        self.backgroundBrightnessInactive = [NSNumber numberWithFloat:self.backgroundBrightness.floatValue + stateModifier];
        
        [self generateBezierPaths];
        [self generateBackgroundGridImage];
        
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

- (void) keyDown:(NSEvent *)keyEvent
{
    BOOL responded = NO;
    
    if( self.window.firstResponder == self ) {
        
        uint keyCode = keyEvent.keyCode;
        NSEventModifierFlags modifierFlags = keyEvent.modifierFlags;
        
        // Here we have to check if it's something we're going to respond to. If not, pass it up. This list duplicates what's in the delegate responder but includes everything for both eatsDebugGridView and keyboardInputView.
        if( ( keyCode == 49 && modifierFlags == 256 )
            || keyCode == 27
            || keyCode == 24
            || keyCode == 122
            || keyCode == 120
            || keyCode == 99
            || keyCode == 118
            || keyCode == 96
            || keyCode == 97
            || keyCode == 98
            || keyCode == 100
            || keyCode == 123
            || keyCode == 124
            || keyCode == 18
            || keyCode == 19
            || keyCode == 20
            || keyCode == 21
            || keyCode == 23
            || keyCode == 22
            || keyCode == 26
            || keyCode == 28
            || keyCode == 25
            || keyCode == 29
            || ( keyCode == 0 && modifierFlags == 256 )
            || ( keyCode == 0 && modifierFlags & NSShiftKeyMask )
            || ( keyCode == 35 && modifierFlags == 256 )
            || keyCode == 47
            || keyCode == 43
            || ( keyCode == 44 && modifierFlags == 256 )
            || ( keyCode == 1 && modifierFlags == 256 )
            || keyCode == 33
            || keyCode == 30
            || ( keyCode == 2 && modifierFlags == 256 )
            || keyCode == 123
            || keyCode == 124
            || keyCode == 126
            || keyCode == 125 ) {
            
            // Send it to delegate
            if( [_delegate respondsToSelector:@selector(keyDownFromEatsDebugGridView:)] )
                [_delegate performSelector:@selector(keyDownFromEatsDebugGridView:) withObject:keyEvent];
            
            responded = YES;
            
        }
    }
    
    // Pass it up
    if( !responded )
        [super keyDown:keyEvent];
    
}

- (void) viewDidResize:(NSNotification *)notification
{
    [self generateBezierPaths];
    [self generateBackgroundGridImage];
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
            [roundedRectForStroke setLineWidth:1.0];
            [rowForStrokes addObject:roundedRectForStroke];
        }
    }
    
    _backgroundBezierPath = [NSBezierPath bezierPathWithRect:NSInsetRect( self.bounds, 4.0, 5.0 )];
    _bezierPathsForFills = pathsForFills;
    _bezierPathsForStrokes = pathsForStrokes;
}

- (void) generateBackgroundGridImage
{
    self.backgroundGridImage = [[NSImage alloc] initWithSize:self.bounds.size];
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:_columns];
    
    // Generate the columns
    for(uint x = 0; x < _columns; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:_rows] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < _rows; y++) {
            
            // If it's active
            if( x < _gridWidth && y < _gridHeight )
                [viewArray[x] insertObject:_backgroundBrightness atIndex:y];
            else
                [viewArray[x] insertObject:_backgroundBrightnessInactive atIndex:y];
        }
    }
    
    // Draw
    [NSGraphicsContext saveGraphicsState];
    
    [self.backgroundGridImage lockFocus];
    
    for( int r = 0; r < _rows; r ++ ){
        for( int c = 0; c < _columns; c ++ ) {

            float brightness = [viewArray[c][r] floatValue];

            // Fill
            NSBezierPath *roundedRectForFill = _bezierPathsForFills[r][c];
            [[NSColor colorWithCalibratedWhite:brightness alpha:1.0] set];
            [roundedRectForFill fill];

            brightness -= 0.1;

            // Stroke
            NSBezierPath *roundedRectForStroke = _bezierPathsForStrokes[r][c];
            [[NSColor colorWithCalibratedWhite:brightness alpha:1.0] set];
            [roundedRectForStroke stroke];

        }
    }
    
    [self.backgroundGridImage unlockFocus];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void) generateCompleteGridImage
{
    if( !self.notes )
        return;
    
    // Re-generate the background grid if need be
    if( _gridSizeHasChanged ) {
        [self generateBackgroundGridImage];
        _gridSizeHasChanged = NO;
    }
    
    self.completeGridImage = [[NSImage alloc] initWithSize:self.bounds.size];
    
    // Generate the columns with playhead and nextStep
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:_columns];
    
    BOOL active;
    
    for( uint x = 0; x < _columns; x ++ ) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:_rows] atIndex:x];
        // Generate the rows
        for( uint y = 0; y < _rows; y ++ ) {
            
            // Active / inactive
            if( x < _gridWidth && y < _gridHeight )
                active = YES;
            else
                active = NO;
            
            if( x == self.currentStep ) {
                if( active )
                    [viewArray[x] insertObject:_playheadBrightness atIndex:y];
                else
                    [viewArray[x] insertObject:_playheadBrightnessInactive atIndex:y];
                
            } else if( self.nextStep && x == self.nextStep.intValue ) {
                if( active )
                    [viewArray[x] insertObject:_nextStepBrightness atIndex:y];
                else
                    [viewArray[x] insertObject:_nextStepBrightnessInactive atIndex:y];
                
            } else {
                [viewArray[x] insertObject:_emptyBrightness atIndex:y];
            }
            
        }
    }
    
    // Put all the note lengths in the viewArray
    
    for( SequencerNote *note in self.notes ) {
        
        // Used for calculating brightness based on note velocity
        float velocityPercentage = (float)note.velocity / SEQUENCER_MIDI_MAX;
        
        float velocityTailBrightness = 0.1 * ( 1.0 - velocityPercentage );
        NSNumber *lengthBrightnessWithVelocity = [NSNumber numberWithFloat:_lengthBrightness + velocityTailBrightness];
        
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
                if( [viewArray[tailDraw][note.row] floatValue] < lengthBrightnessWithVelocity.floatValue )
                    [viewArray[tailDraw] replaceObjectAtIndex:note.row withObject:lengthBrightnessWithVelocity];
            } else {
                if( [viewArray[tailDraw][note.row] floatValue] < _lengthBrightnessInactive.floatValue )
                    [viewArray[tailDraw] replaceObjectAtIndex:note.row withObject:_lengthBrightnessInactive];
            }
            
            
        }
    }
    
    // And now the notes
    
    for( SequencerNote *note in self.notes ) {
        
        // Used for calculating brightness based on note velocity
        float velocityPercentage = (float)note.velocity / SEQUENCER_MIDI_MAX;
        
        // Active / inactive
        if( note.step < _gridWidth && note.row < _gridHeight ) {
            // Put the note in
            float velocityNoteBrightness = 0.4 * ( 1.0 - velocityPercentage );
            NSNumber *noteBrightnessWithVelocity = [NSNumber numberWithFloat:_noteBrightness + velocityNoteBrightness];
            [viewArray[note.step] replaceObjectAtIndex:note.row withObject:noteBrightnessWithVelocity];
        } else
            // Put the note in
            [viewArray[note.step] replaceObjectAtIndex:note.row withObject:_noteBrightnessInactive];
        
    }
    
    
    // Draw
    
    [NSGraphicsContext saveGraphicsState];
    
    [self.completeGridImage lockFocus];
    
    // Background grid image
    [self.backgroundGridImage drawInRect:self.bounds];
    
    // Playhead and notes
    for( int r = 0; r < _rows; r ++ ){
        for( int c = 0; c < _columns; c ++ ) {
            
            float brightness = [viewArray[c][r] floatValue];
            if( brightness >= 0.0 ) {
                
                // Fill
                [[NSColor colorWithCalibratedWhite:brightness alpha:1.0] set];
                [_bezierPathsForFills[r][c] fill];
                
                brightness -= 0.1;
                
                // Stroke
                [[NSColor colorWithCalibratedWhite:brightness alpha:1.0] set];
                [_bezierPathsForStrokes[r][c] stroke];
            }
        }
    }
    
    [self.completeGridImage unlockFocus];
    
    [NSGraphicsContext restoreGraphicsState];
    
    _gridHasChanged = NO;
}

- (void) updateGridImage
{
    _gridHasChanged = YES;
    self.needsDisplay = YES;
}

- (void) drawRect:(NSRect)dirtyRect
{
    // Update cached image if need be
    if( _gridHasChanged )
        [self generateCompleteGridImage];
    
    // Focus ring and background
    [NSGraphicsContext saveGraphicsState];
    
    if( self.window.firstResponder == self )
        NSSetFocusRingStyle( NSFocusRingBelow );
    
    [[NSColor windowBackgroundColor] set];
    [_backgroundBezierPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    // Complete grid image
    [NSGraphicsContext saveGraphicsState];
    [self.completeGridImage drawInRect:self.bounds];
    [NSGraphicsContext restoreGraphicsState];

}

@end
