//
//  Sequencer.m
//  Alt Data Test
//
//  Created by Mark Wheeler on 12/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Sequencer.h"
#import "SequencerState.h"
#import "SequencerPageState.h"
#import "Preferences.h"
#import "WMPool+Utils.h"

@interface Sequencer()

@property SequencerSong         *song;
@property SequencerState        *state;
@property Preferences           *sharedPreferences;

@end

@implementation Sequencer


#pragma mark - Public methods


- (id) init
{
    self = [super init];
    if( !self )
        return nil;
    
    self.sharedPreferences = [Preferences sharedPreferences];
    
    self.song = [[SequencerSong alloc] init];
    self.state = [[SequencerState alloc] init];
    
    // Create the default song
    self.song.songVersion = SEQUENCER_SONG_VERSION;
    
    self.song.bpm = 100;
    self.song.stepQuantization = 16;
    self.song.patternQuantization = 2;
    
    NSMutableOrderedSet *pages = [NSMutableOrderedSet orderedSetWithCapacity:kSequencerNumberOfPages];
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        
        // Create a page and setup the channels
        
        SequencerPage *page = [[SequencerPage alloc] init];
        int channel = i;
        if (channel >= kSequencerNumberOfPages - 2 && kSequencerNumberOfPages < 10) // Make the last two channels drums (10 & 11) on small grids
            channel = i + (12 - kSequencerNumberOfPages);
        page.channel = channel;
        if (channel == 10 || channel == 11)
            page.name = [NSString stringWithFormat:@"Drums %i", channel - 9];
        else
            page.name = [NSString stringWithFormat:@"Page %i", i + 1];
        
        page.stepLength = 16;
        page.loopEnd = SEQUENCER_SIZE - 1;
        
        page.swingType = 16;
        page.swingAmount = 50;
        page.velocityGroove = YES;
        page.transposeZeroStep = 7;
        
        // Create the default pitches
        NSArray *sequenceOfNotes;
        if (channel == 10 || channel == 11)
            sequenceOfNotes = [WMPool sequenceOfNotesWithRootShortName:@"B0" scaleMode:WMScaleModeChromatic length:SEQUENCER_SIZE];  // Drum map
        else
            sequenceOfNotes = [WMPool sequenceOfNotesWithRootShortName:@"C3" scaleMode:WMScaleModeIonianMajor length:SEQUENCER_SIZE]; // C major
        
        // Put them in to the sequencer page
        page.pitches = [NSMutableOrderedSet orderedSetWithCapacity:SEQUENCER_SIZE];
        for( int r = 0; r < SEQUENCER_SIZE; r ++ ) {
            [page.pitches addObject:[NSNumber numberWithInt:[[sequenceOfNotes objectAtIndex:r] midiNoteNumber]]];
        }
        
        // Create the empty patterns
        NSMutableOrderedSet *patterns = [NSMutableOrderedSet orderedSetWithCapacity:SEQUENCER_SIZE];
        for( int j = 0; j < SEQUENCER_SIZE; j++) {
            NSMutableSet *pattern = [NSMutableSet setWithCapacity:16]; // Just a guess as to an average amount of notes there might be in each pattern
            [patterns addObject:pattern];
        }
        page.patterns = patterns;
        
        // Add
        [pages addObject:page];
    }
    
    self.song.pages = pages;
    
    return self;
}



#pragma mark - Song


- (NSData *) songKeyedArchiveData
{
    return [NSKeyedArchiver archivedDataWithRootObject:self.song];
}

- (NSError *) setSongFromKeyedArchiveData:(NSData *)data
{
    NSError *outError;
    SequencerSong *newSong = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    if( !newSong ) {
        outError = [NSError errorWithDomain:kSequencerErrorDomain code:SequencerErrorCode_UnarchiveFailed userInfo:nil];
        
    } else if( newSong.songVersion <= SEQUENCER_SONG_VERSION ) {
        // In future we'll need to deal with data migration here
        self.song = newSong;
        
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"It was created with a newer version of Mark Eats Sequencer." forKey:NSLocalizedFailureReasonErrorKey];
        outError = [NSError errorWithDomain:kSequencerErrorDomain code:SequencerErrorCode_UnarchiveFailed userInfo:userInfo];
        
    }
    return outError;
}


- (void) addDummyData
{
    // Adds 16 randomly positioned notes to pattern 0, page 0
    for( int i = 0; i < SEQUENCER_SIZE; i ++ ) {
        [self addNoteAtStep:i atRow:(int)arc4random_uniform(8) inPattern:0 inPage:0];
    }
}


- (int) checkForNotesOutsideOfGrid
{
    NSLog(@"TODO: %s", __func__);
    return 0;
}

- (int) removeNotesOutsideOfGrid
{
    NSLog(@"TODO: %s", __func__);
    return 0;
}


- (float) bpm
{
    return self.song.bpm;
}

- (void) setBPM:(float)bpm
{
    // TODO rounding etc
    [[self.undoManager prepareWithInvocationTarget:self] setBpm:self.song.bpm];
    [self.undoManager setActionName:@"BPM Change"];
    
    [self setBPMWithoutRegisteringUndo:bpm];
}

- (void) setBPMWithoutRegisteringUndo:(float)bpm
{
    if( bpm < SEQUENCER_SONG_BPM_MIN )
        bpm = SEQUENCER_SONG_BPM_MIN;
    else if( bpm > SEQUENCER_SONG_BPM_MAX )
        bpm = SEQUENCER_SONG_BPM_MAX;
    
    self.song.bpm = bpm;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerSongBPMDidChangeNotification object:self];
}

- (void) incrementBPM
{
    NSLog(@"TODO: %s", __func__);
}

- (void) decrementBPM
{
    NSLog(@"TODO: %s", __func__);
}


- (int) stepQuantization
{
    return self.song.stepQuantization;
}

- (void) setStepQuantization:(int)stepQuantization
{
    NSLog(@"TODO: %s", __func__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerSongStepQuantizationDidChangeNotification object:self];
}

- (void) incrementStepQuantization
{
    [self setStepQuantization:[self stepQuantization] * 2]; //TODO check this works
}

- (void) decrementStepQuantization
{
    [self setStepQuantization:[self stepQuantization] / 2]; //TODO check this works
}


- (int) patternQuantization
{
    return self.song.patternQuantization;
}

- (void) setPatternQuantization:(int)patternQuantization
{
    NSLog(@"TODO: %s", __func__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerSongPatternQuantizationDidChangeNotification object:self];
}

- (void) incrementPatternQuantization
{
    [self setPatternQuantization:[self patternQuantization] * 2]; //TODO check this works
}

- (void) decrementPatternQuantization
{
    [self setPatternQuantization:[self patternQuantization] / 2]; //TODO check this works
}



#pragma mark - Page


- (int) channelForPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return page.channel;
}

- (void) setChannel:(int)channel forPage:(uint)pageId
{
    if( channel >= SEQUENCER_MIDI_MIN && channel <= SEQUENCER_MIDI_MAX ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setChannel:page.channel forPage:pageId];
        [self.undoManager setActionName:@"Channel Change"];
        
        page.channel = channel;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageChannelDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}


- (NSString *) nameForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] name];
}

- (void) setName:(NSString *)name forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setName:page.name forPage:pageId];
    [self.undoManager setActionName:@"Page name Change"];
    
    page.name = name;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageNameDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
}


- (int) stepLengthForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] stepLength];
}

- (void) setStepLength:(int)stepLength forPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) incrementStepLengthForPage:(uint)pageId
{
    [self setStepLength:[self stepLengthForPage:pageId] * 2 forPage:pageId]; //TODO check this works
}

- (void) decrementStepLengthForPage:(uint)pageId
{
    [self setStepLength:[self stepLengthForPage:pageId] / 2 forPage:pageId]; //TODO check this works
}


- (int) loopStartForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] loopStart];
}

- (void) setLoopStart:(int)loopStart forPage:(uint)pageId
{
    if( loopStart > 0 && loopStart < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopStart:page.loopStart forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopStart = loopStart;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageLoopDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
        
    }
}

- (void) incrementLoopStartForPage:(uint)pageId
{
    [self setLoopStart:[self loopStartForPage:pageId] + 1 forPage:pageId];
}

- (void) decrementLoopStartForPage:(uint)pageId
{
    [self setLoopStart:[self loopStartForPage:pageId] - 1 forPage:pageId];
}

- (int) loopEndForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] loopEnd];
}

- (void) setLoopEnd:(int)loopEnd forPage:(uint)pageId
{
    if( loopEnd > 0 && loopEnd < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopEnd:page.loopEnd forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopEnd = loopEnd;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageLoopDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    
    }
}

- (void) incrementLoopEndForPage:(uint)pageId
{
    [self setLoopEnd:[self loopEndForPage:pageId] + 1 forPage:pageId];
}

- (void) decrementLoopEndForPage:(uint)pageId
{
    [self setLoopEnd:[self loopEndForPage:pageId] - 1 forPage:pageId];
}

- (void) setLoopStart:(int)loopStart andLoopEnd:(int)loopEnd forPage:(uint)pageId
{
    if( loopStart > 0 && loopStart < self.sharedPreferences.gridWidth && loopEnd > 0 && loopEnd < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopStart:page.loopStart andLoopEnd:page.loopEnd forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopStart = loopStart;
        page.loopEnd = loopEnd;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageLoopDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    
    }
}


- (int) swingTypeForPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return page.swingType;
}

- (void) setSwingType:(int)swingType forPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) incrementSwingTypeForPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) decrementSwingTypeForPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (int) swingAmountForPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return page.swingAmount;
}

- (void) setSwingAmount:(int)swingAmount forPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) incrementSwingAmountForPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) decrementSwingAmountForPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) setSwingType:(int)swingType andSwingAmount:(int)swingAmount forPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}


- (BOOL) velocityGrooveForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] velocityGroove];
}

- (void) setVelocityGroove:(BOOL)velocityGroove forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setVelocityGroove:page.velocityGroove forPage:pageId];
    [self.undoManager setActionName:@"Velocity Groove Change"];
    
    page.velocityGroove = velocityGroove;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageVelocityGrooveDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
}


- (int) transposeForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] transpose];
}

- (void) setTranspose:(int)transpose forPage:(uint)pageId
{
    if( transpose >= SEQUENCER_MIDI_MIN && transpose <= SEQUENCER_MIDI_MAX ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setTranspose:page.transpose forPage:pageId];
        [self.undoManager setActionName:@"Transpose Change"];
        
        page.transpose = transpose;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageTransposeDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
        
    }
}

- (void) incrementTransposeForPage:(uint)pageId
{
    [self setTranspose:[self transposeForPage:pageId] + 1 forPage:pageId];
}

- (void) decrementTransposeForPage:(uint)pageId
{
    [self setTranspose:[self transposeForPage:pageId] - 1 forPage:pageId];
}


- (int) transposeZeroStepForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] transposeZeroStep];
}

- (void) setTransposeZeroStep:(int)transposeZeroStep forPage:(uint)pageId
{
    if( transposeZeroStep >= 0 && transposeZeroStep < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        // Skipping undo registration for this one
        page.transposeZeroStep = transposeZeroStep;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageTransposeZeroStepDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
        
    }
}


- (NSOrderedSet *) pitchesForPage:(uint)pageId
{
    return [[[self.song.pages objectAtIndex:pageId] pitches] copy];
}

- (void) setPitches:(NSMutableOrderedSet *)pitches forPage:(uint)pageId
{
    if( pitches.count == SEQUENCER_SIZE ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setPitches:page.pitches forPage:pageId];
        [self.undoManager setActionName:@"Pitches Change"];
        
        page.pitches = pitches;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPagePitchesDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}

- (int) pitchAtRow:(uint)row forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return [[page.pitches objectAtIndex:row] intValue];
}

- (void) setPitch:(int)pitch atRow:(uint)row forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setPitch:[[page.pitches objectAtIndex:row] intValue] atRow:row forPage:pageId];
    [self.undoManager setActionName:@"Pitch Change"];
    
    [page.pitches replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:pitch]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPagePitchesDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
}



#pragma mark - Pattern


- (NSSet *) notesForPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return [[page.patterns objectAtIndex:patternId] copy];
}

- (void) setNotes:(NSMutableSet *)notes forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setNotes:[page.patterns objectAtIndex:patternId] forPattern:patternId inPage:pageId];
    [self.undoManager setActionName:@"Pattern Change"];
    
    [page.patterns replaceObjectAtIndex:patternId withObject:notes];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPatternDidChangeNotification object:self userInfo:[self userInfoForPattern:patternId inPage:pageId]];
}


- (void) clearNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setNotes:[page.patterns objectAtIndex:patternId] forPattern:patternId inPage:pageId];
    [self.undoManager setActionName:@"Pattern Clear"];
    
    [[page.patterns objectAtIndex:patternId] removeAllItems];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPatternDidChangeNotification object:self userInfo:[self userInfoForPattern:patternId inPage:pageId]];
}

- (void) copyNotesFromPattern:(uint)fromPatternId fromPage:(uint)fromPageId toPattern:(uint)toPatternId toPage:(uint)toPageId
{
    SequencerPage *fromPage = [self.song.pages objectAtIndex:fromPageId];
    SequencerPage *toPage = [self.song.pages objectAtIndex:toPageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setNotes:[toPage.patterns objectAtIndex:toPatternId] forPattern:toPatternId inPage:toPageId];
    [self.undoManager setActionName:@"Pattern Copy"];
    
    [self setNotes:[[fromPage.patterns objectAtIndex:fromPatternId] copy] forPattern:toPatternId inPage:toPageId];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPatternDidChangeNotification object:self userInfo:[self userInfoForPattern:toPatternId inPage:toPageId]];
}


- (void) pasteboardCutNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) pasteboardCopyNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) pasteboardPasteNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}



#pragma mark - Note


- (SequencerNote *) noteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    NSSet *notes = [[page.patterns objectAtIndex:patternId] copy];
    
    for( SequencerNote *note in notes ) {
        if( note.row == row && note.step == step ) {
            return note;
        }
    }
    
    return nil;
}

- (NSSet *) notesAtStep:(uint)step inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    NSSet *notes = [[page.patterns objectAtIndex:patternId] copy];
    
    NSSet *notesMatchingStep = [notes objectsPassingTest:^(id obj, BOOL *stop) {
        SequencerNote *note = (SequencerNote *)obj;
        BOOL testResult = ( note.step == step );
        return testResult;
    }];
    
    return notesMatchingStep;
}

- (NSSet *) notesAtRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    NSSet *notes = [[page.patterns objectAtIndex:patternId] copy];
    
    NSSet *notesMatchingRow = [notes objectsPassingTest:^(id obj, BOOL *stop) {
        SequencerNote *note = (SequencerNote *)obj;
        BOOL testResult = ( note.row == row );
        return testResult;
    }];
    
    return notesMatchingRow;
}


- (int) lengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
    return 0;
}

- (void) setLength:(int)length forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) incrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) decrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}


- (int) velocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
    return 0;
}

- (void) setVelocity:(int)velocity forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) incrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) decrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
}

- (void) addOrRemoveNoteThatIsSelectableAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    NSLog(@"TODO: %s", __func__);
    // This method needs to check note lengths and play state etc
}

- (void) addNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    // TODO Get default velocity from user defaults
    [self addNoteAtStep:step atRow:row withLength:1 withVelocity:64 inPattern:patternId inPage:pageId];
}

- (void) addNoteAtStep:(uint)step atRow:(uint)row withLength:(uint)length withVelocity:(uint)velocity inPattern:(uint)patternId inPage:(uint)pageId
{
    [[self.undoManager prepareWithInvocationTarget:self] removeNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    [self.undoManager setActionName:@"Add Note"];
    
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    NSMutableSet *pattern = [page.patterns objectAtIndex:patternId];
    
    SequencerNote *note = [[SequencerNote alloc] init];
    note.step = step;
    note.row = row;
    note.length = length;
    note.velocity = velocity;
    
    [pattern addObject:note];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPatternDidChangeNotification object:self userInfo:[self userInfoForPattern:patternId inPage:pageId]];
}

- (void) removeNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerNote *noteToRemove = [self noteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] addNoteAtStep:step atRow:row withLength:noteToRemove.length withVelocity:noteToRemove.velocity inPattern:patternId inPage:pageId];
    [self.undoManager setActionName:@"Remove Note"];
    
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    NSMutableSet *pattern = [page.patterns objectAtIndex:patternId];
    
    [pattern addObject:noteToRemove];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPatternDidChangeNotification object:self userInfo:[self userInfoForPattern:patternId inPage:pageId]];
}



#pragma mark - State


- (int) currentPageId
{
    return self.state.currentPageId;
}

- (void) setCurrentPageId:(int)pageId
{
    if( pageId >= 0 && pageId < kSequencerNumberOfPages )
        self.state.currentPageId = pageId;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerStateCurrentPageDidChangeNotification object:self userInfo:nil];
}


- (int) currentPatternIdForPage:(uint)pageId{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.currentPatternId;
}

- (void) setCurrentPatternId:(int)patternId forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    if( patternId >= 0 && patternId < page.patterns.count ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.currentPatternId = patternId;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStateCurrentPatternIdDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}


- (NSNumber *) nextPatternIdForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.nextPatternId;
}

- (void) setNextPatternId:(NSNumber *)patternId forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    if( patternId.intValue >= 0 && patternId.intValue < page.patterns.count ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.nextPatternId = patternId;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStateNextPatternIdDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}

- (void) setNextPatternIdForAllPages:(NSNumber *)patternId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
            [self setNextPatternId:patternId forPage:i];
    }
}

- (void) setNextPatternId:(NSNumber *)patternId forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId )
            [self setNextPatternId:patternId forPage:i];
    }
}


- (int) currentlyDisplayingPatternIdForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    
    // If pattern quantization is disabled
    if( [self patternQuantization] && pageState.nextPatternId ) {
        return pageState.nextPatternId.intValue;
        
    } else {
        return pageState.currentPatternId;
    }
}


- (int) currentStepForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.currentStep;
}

- (void) setCurrentStep:(int)step forPage:(uint)pageId
{
    if( step >= 0 && step < self.sharedPreferences.gridWidth ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.currentStep = step;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStateCurrentStepDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}


- (NSNumber *) nextStepForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.nextStep;
}

- (void) setNextStep:(NSNumber *)step forPage:(uint)pageId
{
    if( step.intValue >= 0 && step.intValue < self.sharedPreferences.gridWidth ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.nextStep = step;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStateNextStepDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}

- (void) setNextStepForAllPages:(NSNumber *)step
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self setNextStep:step forPage:i];
    }
}

- (void) setNextStep:(NSNumber *)step forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId )
            [self setNextStep:step forPage:i];
    }
}


- (void) resetPlayPositionsForAllPlayingPages
{
    // use code from old resetPlayPositions method in Document.m
    NSLog(@"TODO: %s", __func__);
}


- (BOOL) inLoopForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.inLoop;
}

- (void) setInLoop:(BOOL)inLoop forPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    pageState.inLoop = inLoop;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStateInLoopDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
}


- (int) playModeForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.playMode;
}

- (void) setPlayMode:(int)playMode forPage:(uint)pageId
{
    if( playMode >= 0 && playMode <= 3 ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.playMode = playMode;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSequencerPageStatePlayModeDidChangeNotification object:self userInfo:[self userInfoForPage:pageId]];
    }
}



#pragma mark - Private methods

- (NSDictionary *) userInfoForPattern:(uint)patternId inPage:(uint)pageId
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:patternId], @"patternId",
                                                      [NSNumber numberWithInt:pageId], @"pageId",
                                                      nil];
}

- (NSDictionary *) userInfoForPage:(uint)pageId
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pageId], @"pageId", nil];
}


@end
