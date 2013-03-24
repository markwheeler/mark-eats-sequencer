//
//  EatsGridPatternView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPatternView.h"
#import "SequencerNote.h"
#import "EatsGridNavigationController.h"


#define EDIT_MODE_PLAYHEAD_BRIGHTNESS 8
#define EDIT_MODE_NOTE_BRIGHTNESS 15
#define EDIT_MODE_NOTE_LENGTH_BRIGHTNESS 10

#define EDIT_NOTE_MODE_PLAYHEAD_BRIGHTNESS 10
#define EDIT_NOTE_MODE_NOTE_BRIGHTNESS 8 // TODO: Set to 7 once done debugging
#define EDIT_NOTE_MODE_NOTE_LENGTH_BRIGHTNESS 2

@interface EatsGridPatternView ()

@property NSDictionary          *lastPressedKey;
@property uint                  playheadBrightness;
@property uint                  noteBrightness;
@property uint                  noteLengthBrightness;

@end

@implementation EatsGridPatternView

@synthesize mode = _mode;

- (EatsPatternViewMode ) mode
{
    return _mode;
}

- (void) setMode:(EatsPatternViewMode)mode
{
    _mode = mode;
    
    if( mode == EatsPatternViewMode_NoteEdit ) {
        self.playheadBrightness = EDIT_NOTE_MODE_PLAYHEAD_BRIGHTNESS;
        self.noteBrightness = EDIT_NOTE_MODE_NOTE_BRIGHTNESS;
        self.noteLengthBrightness = EDIT_NOTE_MODE_NOTE_LENGTH_BRIGHTNESS;
    } else {
        self.playheadBrightness = EDIT_MODE_PLAYHEAD_BRIGHTNESS;
        self.noteBrightness = EDIT_MODE_NOTE_BRIGHTNESS;
        self.noteLengthBrightness = EDIT_MODE_NOTE_LENGTH_BRIGHTNESS;
    }
}



- (id) init
{
    self = [super init];
    if (self) {
        self.playheadBrightness = EDIT_MODE_PLAYHEAD_BRIGHTNESS;
        self.noteBrightness = EDIT_MODE_NOTE_BRIGHTNESS;
        self.noteLengthBrightness = EDIT_MODE_NOTE_LENGTH_BRIGHTNESS;
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            if(x == self.currentStep)
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:self.playheadBrightness * self.opacity] atIndex:y];
            else
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    // Work out how much we need to fold
    int scaleDifference = self.patternHeight - self.height;
    if( scaleDifference < 0 ) scaleDifference = 0;
    
    for(SequencerNote *note in self.pattern.notes) {
        if( [note.step intValue] < self.width && [note.row intValue] < self.patternHeight ) {
                        
            uint row = [note.row unsignedIntValue];

            // Fold from top
            if( self.foldFrom == EatsPatternViewFoldFrom_Top ) {
                if( row < scaleDifference * 2 )
                   row = row / 2;
               else
                   row -= scaleDifference;
               
            // Fold from bottom
            } else if( self.foldFrom == EatsPatternViewFoldFrom_Bottom ) {
                if( row >= self.patternHeight - (scaleDifference * 2) )
                    row = row / 2 + scaleDifference;
            }

            // Put in the active note while editing
            if( note == self.activeEditNote && self.mode == EatsPatternViewMode_NoteEdit )
                [[viewArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:15 * self.opacity]];
            
            // Put the rest in (unless there's something brighter there)
            else if( [[[viewArray objectAtIndex:[note.step intValue]] objectAtIndex:row] intValue] < self.noteBrightness * self.opacity )
                [[viewArray objectAtIndex:[note.step intValue]] replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:self.noteBrightness * self.opacity]];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Send the press to delegate
    NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                      [NSNumber numberWithUnsignedInt:y], @"y",
                                                                      [NSNumber numberWithBool:down], @"down",
                                                                      nil];
    if([self.delegate respondsToSelector:@selector(eatsGridPatternViewPressAt: sender:)])
        [self.delegate performSelector:@selector(eatsGridPatternViewPressAt: sender:) withObject:xyDown withObject:self];

    
    // Check for double presses on release, in edit mode
    if( self.mode == EatsPatternViewMode_Edit && !down ) {
           
        // Check for double presses
        if(self.lastPressedKey
           && [[self.lastPressedKey valueForKey:@"time"] timeIntervalSinceNow] > -0.4
           && [[self.lastPressedKey valueForKey:@"x"] intValue] == x
           && [[self.lastPressedKey valueForKey:@"y"] intValue] == y) {
            
            // Send the double press to delegate
            NSDictionary *xy = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                          [NSNumber numberWithUnsignedInt:y], @"y",
                                                                          nil];
            if([self.delegate respondsToSelector:@selector(eatsGridPatternViewDoublePressAt: sender:)])
                [self.delegate performSelector:@selector(eatsGridPatternViewDoublePressAt: sender:) withObject:xy withObject:self];

        } else {
            // Log the last press
            self.lastPressedKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                             [NSNumber numberWithUnsignedInt:y], @"y",
                                                                             [NSDate date], @"time",
                                                                             nil];
        }
    
    }
}


@end
