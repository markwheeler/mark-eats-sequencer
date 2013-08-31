//
//  Sequencer.h
//  Alt Data Test
//
//  Created by Mark Wheeler on 12/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  This is the brain – everything that edits anything in the model should pass through this
//  It lets us get and set things, as well as registering undos
//  Sequencer is thread safe. Notifications it sends are always on the default global queue


#import <Foundation/Foundation.h>
#import "SequencerSong.h"
#import "SequencerPage.h"
#import "SequencerNote.h"

#define SEQUENCER_SONG_VERSION 0

#define SEQUENCER_SIZE 16
#define SEQUENCER_MIDI_MIN 0
#define SEQUENCER_MIDI_MAX 127

#define MIN_QUANTIZATION 64
#define MAX_QUANTIZATION 1

@interface Sequencer : NSObject

@property NSUndoManager         *undoManager;

@property NSArray               *stepQuantizationArray;
@property NSArray               *patternQuantizationArray;
@property NSArray               *swingArray;

- (NSString *) debugInfo;

- (void) updatePatternQuantizationSettings;

// Song
- (NSData *) songKeyedArchiveData;
- (NSError *) setSongFromKeyedArchiveData:(NSData *)data;

- (void) addDummyData;

- (void) adjustToGridSize;

- (NSUInteger) checkForNotesOutsideOfGrid;
- (NSUInteger) removeNotesOutsideOfGrid;

- (float) bpm;
- (void) setBPM:(float)bpm;
- (void) setBPMWithoutRegisteringUndo:(float)bpm;
- (void) incrementBPM;
- (void) decrementBPM;

- (int) stepQuantization;
- (void) setStepQuantization:(int)stepQuantization;
- (void) incrementStepQuantization;
- (void) decrementStepQuantization;

- (int) patternQuantization;
- (void) setPatternQuantization:(int)patternQuantization;
- (void) incrementPatternQuantization;
- (void) decrementPatternQuantization;


// Page
- (int) channelForPage:(uint)pageId;
- (void) setChannel:(int)channel forPage:(uint)pageId;

- (NSString *) nameForPage:(uint)pageId;
- (void) setName:(NSString *)name forPage:(uint)pageId;

- (int) stepLengthForPage:(uint)pageId;
- (void) setStepLength:(int)stepLength forPage:(uint)pageId;
- (void) incrementStepLengthForPage:(uint)pageId;
- (void) decrementStepLengthForPage:(uint)pageId;

- (int) loopStartForPage:(uint)pageId;
- (void) setLoopStart:(int)loopStart forPage:(uint)pageId;
- (void) incrementLoopStartForPage:(uint)pageId;
- (void) decrementLoopStartForPage:(uint)pageId;
- (int) loopEndForPage:(uint)pageId;
- (void) setLoopEnd:(int)loopEnd forPage:(uint)pageId;
- (void) incrementLoopEndForPage:(uint)pageId;
- (void) decrementLoopEndForPage:(uint)pageId;
- (void) setLoopStart:(int)loopStart andLoopEnd:(int)loopEnd forPage:(uint)pageId;

- (int) swingTypeForPage:(uint)pageId;
- (void) setSwingType:(int)swingType forPage:(uint)pageId;
- (int) swingAmountForPage:(uint)pageId;
- (void) setSwingAmount:(int)swingAmount forPage:(uint)pageId;
- (void) setSwingType:(int)swingType andSwingAmount:(int)swingAmount forPage:(uint)pageId;

- (BOOL) velocityGrooveForPage:(uint)pageId;
- (void) setVelocityGroove:(BOOL)velocityGroove forPage:(uint)pageId;

- (int) transposeForPage:(uint)pageId;
- (void) setTranspose:(int)transpose forPage:(uint)pageId;
- (void) incrementTransposeForPage:(uint)pageId;
- (void) decrementTransposeForPage:(uint)pageId;

- (int) transposeZeroStepForPage:(uint)pageId;
- (void) setTransposeZeroStep:(int)transposeZeroStep forPage:(uint)pageId;

- (void) setTranspose:(int)transpose andTransposeZeroStep:(int)transposeZeroStep forPage:(uint)pageId;

- (NSArray *) pitchesForPage:(uint)pageId;
- (void) setPitches:(NSArray *)pitches forPage:(uint)pageId;
- (int) pitchAtRow:(uint)row forPage:(uint)pageId;
- (void) setPitch:(int)pitch atRow:(uint)row forPage:(uint)pageId;


// Pattern
- (void) startOrStopPattern:(uint)patternId inPage:(uint)pageId;

- (NSSet *) notesForPattern:(uint)patternId inPage:(uint)pageId;
- (uint) numberOfNotesForPattern:(uint)patternId inPage:(uint)pageId;
- (void) setNotes:(NSSet *)notes forPattern:(uint)patternId inPage:(uint)pageId;

- (void) clearNotesForPattern:(uint)patternId inPage:(uint)pageId;
- (void) copyNotesFromPattern:(uint)fromPatternId fromPage:(uint)fromPageId toPattern:(uint)toPatternId toPage:(uint)toPageId;

- (void) pasteboardCutNotesForPattern:(uint)patternId inPage:(uint)pageId;
- (void) pasteboardCopyNotesForPattern:(uint)patternId inPage:(uint)pageId;
- (void) pasteboardPasteNotesForPattern:(uint)patternId inPage:(uint)pageId;


// Note
- (SequencerNote *) noteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (SequencerNote *) noteThatIsSelectableAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;

- (NSSet *) notesAtStep:(uint)step inPattern:(uint)patternId inPage:(uint)pageId;
- (NSSet *) notesAtRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;

- (int) lengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) setLength:(int)length forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) incrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) decrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;

- (int) velocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) setVelocity:(int)velocity forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) incrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;
- (void) decrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;

- (void) addOrRemoveNoteThatIsSelectableAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId; // Will take into acount note lengths
- (void) addNoteAtStep:(uint)step atRow:(uint)row withLength:(uint)length withVelocity:(uint)velocity inPattern:(uint)patternId inPage:(uint)pageId;
- (void) addNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId; // Default length and velocity
- (void) removeNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId;

// State
- (int) currentPageId;
- (void) setCurrentPageId:(int)pageId;
- (void) incrementCurrentPageId;
- (void) decrementCurrentPageId;

- (int) currentPatternIdForPage:(uint)pageId;
- (void) setCurrentPatternId:(int)patternId forPage:(uint)pageId;

- (NSNumber *) nextPatternIdForPage:(uint)pageId;
- (void) setNextPatternId:(NSNumber *)patternId forPage:(uint)pageId;

- (void) setNextOrCurrentPatternId:(NSNumber *)patternId forPage:(uint)pageId; // These three methods are for when a user switches pattern (they take into acount patternQuantization)
- (void) setNextOrCurrentPatternIdForAllPages:(NSNumber *)patternId;
- (void) setNextOrCurrentPatternId:(NSNumber *)patternId forAllPagesExcept:(uint)pageId;

- (int) currentStepForPage:(uint)pageId;
- (void) setCurrentStep:(int)step forPage:(uint)pageId;

- (NSNumber *) nextStepForPage:(uint)pageId;
- (void) setNextStep:(NSNumber *)step forPage:(uint)pageId;
- (void) setNextStepForAllPages:(NSNumber *)step;
- (void) setNextStep:(NSNumber *)step forAllPagesExcept:(uint)pageId;

- (void) resetPlayPositionsForAllPlayingPages;

- (BOOL) inLoopForPage:(uint)pageId;
- (void) setInLoop:(BOOL)inLoop forPage:(uint)pageId;

- (int) playModeForPage:(uint)pageId;
- (void) setPlayMode:(int)playMode forPage:(uint)pageId;

// Utils
- (BOOL) isNotificationFromCurrentPage:(NSNotification *)notification;
- (BOOL) isNotificationFromCurrentPattern:(NSNotification *)notification;

@end