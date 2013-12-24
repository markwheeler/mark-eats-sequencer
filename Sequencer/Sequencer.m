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
#import "EatsQuantizationUtils.h"
#import "EatsSwingUtils.h"
#import "WMPool+Utils.h"

@interface Sequencer()

@property SequencerSong         *song;
@property SequencerState        *state;
@property Preferences           *sharedPreferences;

@property dispatch_queue_t      sequencerQueue;

@end

@implementation Sequencer


#pragma mark - Public methods


- (id) init
{
    self = [super init];
    if( !self )
        return nil;
    
    // Create the serial queue and make it high priority
    self.sequencerQueue = dispatch_queue_create("com.MarkEatsSequencer.SequencerQueue", NULL);
    dispatch_queue_t globalHigh = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_set_target_queue(self.sequencerQueue, globalHigh);
    
    self.sharedPreferences = [Preferences sharedPreferences];
    
    self.song = [[SequencerSong alloc] init];
    self.state = [[SequencerState alloc] init];
    
    self.stepQuantizationArray = [EatsQuantizationUtils stepQuantizationArray];
    self.patternQuantizationArray = [EatsQuantizationUtils patternQuantizationArrayForGridWidth:self.sharedPreferences.gridWidth];
    self.swingArray = [EatsSwingUtils swingArray];
    
    // Create the default song
    self.song.songVersion = SEQUENCER_SONG_VERSION;
    
    self.song.bpm = 100;
    self.song.stepQuantization = 16;
    self.song.patternQuantization = 2;
    
    NSMutableArray *pages = [NSMutableArray arrayWithCapacity:kSequencerNumberOfPages];
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
        page.pitches = [NSMutableArray arrayWithCapacity:SEQUENCER_SIZE];
        for( int r = 0; r < SEQUENCER_SIZE; r ++ ) {
            [page.pitches addObject:[NSNumber numberWithInt:[[sequenceOfNotes objectAtIndex:r] midiNoteNumber]]];
        }
        
        // Create the empty patterns
        NSMutableArray *patterns = [NSMutableArray arrayWithCapacity:SEQUENCER_SIZE];
        for( int j = 0; j < SEQUENCER_SIZE; j++) {
            NSMutableSet *pattern = [NSMutableSet setWithCapacity:16]; // Just a guess as to an average amount of notes there might be in each pattern
            [patterns addObject:pattern];
        }
        
        page.patterns = patterns;
        
        // Add
        [pages addObject:page];
        
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:i];
        pageState.currentStep = page.loopEnd;
    }
    
    self.song.pages = pages;
    
    return self;
}

- (NSString *) debugInfo
{
    return [NSString stringWithFormat:@"%@\r%@", self.song, self.state ];
}

- (void) updatePatternQuantizationSettings
{
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        self.patternQuantizationArray = [EatsQuantizationUtils patternQuantizationArrayForGridWidth:self.sharedPreferences.gridWidth];
        
    });
    
    if( [self patternQuantization] > self.sharedPreferences.gridWidth )
        [self setPatternQuantizationWithoutRegisteringUndo:self.sharedPreferences.gridWidth];
}



#pragma mark - Song


- (NSData *) songKeyedArchiveData
{
    return [NSKeyedArchiver archivedDataWithRootObject:self.song];
}

- (NSError *) setSongFromKeyedArchiveData:(NSData *)data
{
    SequencerSong *newSong;
    
    NSError *outError;
    @try {
        newSong = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException* exception) {
        outError = [NSError errorWithDomain:kSequencerErrorDomain code:SequencerErrorCode_UnarchiveFailed userInfo:nil];
        return outError;
    }
    
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



- (void) adjustToGridSize
{
    // Make sure all the loops etc fit within the connected grid size
    for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        
        if( page.loopStart >= self.sharedPreferences.gridWidth || page.loopEnd >= self.sharedPreferences.gridWidth ) {
            page.loopStart = 0;
            page.loopEnd = self.sharedPreferences.gridWidth - 1;
        }
        if( page.transposeZeroStep >= self.sharedPreferences.gridWidth )
            page.transposeZeroStep = (self.sharedPreferences.gridWidth) / 2 - 1;
        
        if( pageState.currentStep >= self.sharedPreferences.gridWidth )
            pageState.currentStep = page.loopEnd;
        if( pageState.nextStep.intValue >= self.sharedPreferences.gridWidth )
            pageState.nextStep = nil;
        if( pageState.currentPatternId >= self.sharedPreferences.gridWidth )
            pageState.currentPatternId = 0;
        if( pageState.nextPatternId.intValue >= self.sharedPreferences.gridWidth )
            pageState.nextPatternId = nil;
    }
}



- (NSUInteger) checkForNotesOutsideOfGrid
{
    __block NSMutableSet *notesOutsideOfGrid = [NSMutableSet set];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
            SequencerPage *page = [self.song.pages objectAtIndex:pageId];
            
            for( NSSet *pattern in page.patterns ) {
                
                NSArray *matches = [[pattern objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                    SequencerNote *note = obj;
                    BOOL result = ( note.row >= self.sharedPreferences.gridHeight || note.step >= self.sharedPreferences.gridWidth );
                    return result;
                }] allObjects];
                
                [notesOutsideOfGrid addObjectsFromArray:matches];
            }
        }
        
    });
    
    return notesOutsideOfGrid.count;
}

- (NSUInteger) removeNotesOutsideOfGrid
{
    __block NSMutableSet *removedNoteDictionaries = [NSMutableSet set];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        for( int pageId = 0; pageId < kSequencerNumberOfPages; pageId ++ ) {
            SequencerPage *page = [self.song.pages objectAtIndex:pageId];
            
            int patternId = 0;
            for( NSMutableSet *pattern in page.patterns ) {
                
                NSArray *matches = [[pattern objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                    SequencerNote *note = obj;
                    BOOL result = ( note.row >= self.sharedPreferences.gridHeight || note.step >= self.sharedPreferences.gridWidth );
                    return result;
                }] allObjects];
                
                for( SequencerNote *noteToRemove in matches ) {
                    // Keep track of it so undo can be used
                    NSDictionary *noteDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:noteToRemove.step], @"step",
                                                                                              [NSNumber numberWithInt:noteToRemove.row], @"row",
                                                                                              [NSNumber numberWithInt:noteToRemove.length], @"length",
                                                                                              [NSNumber numberWithInt:noteToRemove.velocity], @"velocity",
                                                                                              [NSNumber numberWithInt:patternId], @"patternId",
                                                                                              [NSNumber numberWithInt:pageId], @"pageId",
                                                                                              nil];
                    [removedNoteDictionaries addObject:noteDictionary];
                    [pattern removeObject:noteToRemove];
                }
                
                if( matches.count ) {
                    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
                }
                patternId ++;
            }
        }
        
    });
    
    [[self.undoManager prepareWithInvocationTarget:self] addBackNotesPreviouslyRemoved:removedNoteDictionaries];
    [self.undoManager setActionName:@"Remove Notes"];
    
    return removedNoteDictionaries.count;
}

- (void) addBackNotesPreviouslyRemoved:(NSSet *)noteDictionaries
{
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        for( NSDictionary *noteDictionary in noteDictionaries ) {
            
            int pageId = [[noteDictionary valueForKey:@"pageId"] intValue];
            int patternId = [[noteDictionary valueForKey:@"patternId"] intValue];
            SequencerPage *page = [self.song.pages objectAtIndex:pageId];
            NSMutableSet *pattern = [page.patterns objectAtIndex:patternId];
            
            SequencerNote *note = [[SequencerNote alloc] init];
            note.step = [[noteDictionary valueForKey:@"step"] intValue];
            note.row = [[noteDictionary valueForKey:@"row"] intValue];
            note.length = [[noteDictionary valueForKey:@"length"] intValue];
            note.velocity = [[noteDictionary valueForKey:@"velocity"] intValue];
            
            [pattern addObject:note];
            
            [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
        }
        
    });
    
    [[self.undoManager prepareWithInvocationTarget:self] removeNotesOutsideOfGrid];
}


- (float) bpm
{
    return self.song.bpm;
}

- (void) setBPM:(float)bpm
{
    if( bpm >= SEQUENCER_SONG_BPM_MIN && bpm <= SEQUENCER_SONG_BPM_MAX ) {
        [[self.undoManager prepareWithInvocationTarget:self] setBPM:self.song.bpm];
        [self.undoManager setActionName:@"BPM Change"];
    }
    
    [self setBPMWithoutRegisteringUndo:bpm];
}

- (void) setBPMWithoutRegisteringUndo:(float)bpm
{
    if( bpm >= SEQUENCER_SONG_BPM_MIN && bpm <= SEQUENCER_SONG_BPM_MAX ) {
        
        self.song.bpm = bpm;
    }
    
    [self postNotification:kSequencerSongBPMDidChangeNotification];
}

- (void) incrementBPM
{
    float newBPM = roundf( self.bpm ) + 1;
    if( newBPM > SEQUENCER_SONG_BPM_MAX )
        newBPM = SEQUENCER_SONG_BPM_MAX;
    [self setBPM:newBPM];
}

- (void) decrementBPM
{
    float newBPM = roundf( self.bpm ) - 1;
    if( newBPM < SEQUENCER_SONG_BPM_MIN )
        newBPM = SEQUENCER_SONG_BPM_MIN;
    [self setBPM:newBPM];
}


- (int) stepQuantization
{
    return self.song.stepQuantization;
}

- (void) setStepQuantization:(int)stepQuantization
{
    NSUInteger index = [self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == stepQuantization );
        return result;
    }];
    
    if( index != NSNotFound ) {
        [[self.undoManager prepareWithInvocationTarget:self] setStepQuantization:self.song.stepQuantization];
        [self.undoManager setActionName:@"Step Quantization Change"];
        
        self.song.stepQuantization = stepQuantization;
    }
    
    [self postNotification:kSequencerSongStepQuantizationDidChangeNotification];
}

- (void) incrementStepQuantization
{
    [self setStepQuantization:[self stepQuantization] * 2];
}

- (void) decrementStepQuantization
{
    [self setStepQuantization:[self stepQuantization] / 2];
}


- (int) patternQuantization
{
    return self.song.patternQuantization;
}

- (void) setPatternQuantization:(int)patternQuantization
{
    NSUInteger index = [self.patternQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == patternQuantization );
        return result;
    }];
    
    if( index != NSNotFound ) {
        [[self.undoManager prepareWithInvocationTarget:self] setPatternQuantization:self.song.patternQuantization];
        [self.undoManager setActionName:@"Pattern Quantization Change"];
        
        [self setPatternQuantizationWithoutRegisteringUndo:patternQuantization];
    }
}

- (void) setPatternQuantizationWithoutRegisteringUndo:(int)patternQuantization
{
    self.song.patternQuantization = patternQuantization;
    
    [self postNotification:kSequencerSongPatternQuantizationDidChangeNotification];
}

- (void) incrementPatternQuantization
{
    [self setPatternQuantization:[self patternQuantization] * 2];
}

- (void) decrementPatternQuantization
{
    [self setPatternQuantization:[self patternQuantization] / 2];
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
    }
    
    [self postNotification:kSequencerPageChannelDidChangeNotification forPage:pageId];
}


- (NSString *) nameForPage:(uint)pageId
{
    // Return a copy so it can't be used to change the model
    return [[[self.song.pages objectAtIndex:pageId] name] copy];
}

- (void) setName:(NSString *)name forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [[self.undoManager prepareWithInvocationTarget:self] setName:page.name forPage:pageId];
    [self.undoManager setActionName:@"Page name Change"];
    
    page.name = name;
    
    [self postNotification:kSequencerPageNameDidChangeNotification forPage:pageId];
}


- (int) stepLengthForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] stepLength];
}

- (void) setStepLength:(int)stepLength forPage:(uint)pageId
{
    NSUInteger index = [self.stepQuantizationArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"quantization"] intValue] == stepLength );
        return result;
    }];
    
    if( index != NSNotFound ) {
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setStepLength:page.stepLength forPage:pageId];
        [self.undoManager setActionName:@"Step Length Change"];
        
        page.stepLength = stepLength;
    }
    
    [self postNotification:kSequencerPageStepLengthDidChangeNotification forPage:pageId];
}

- (void) incrementStepLengthForPage:(uint)pageId
{
    [self setStepLength:[self stepLengthForPage:pageId] * 2 forPage:pageId];
}

- (void) decrementStepLengthForPage:(uint)pageId
{
    [self setStepLength:[self stepLengthForPage:pageId] / 2 forPage:pageId];
}


- (int) loopStartForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] loopStart];
}

- (void) setLoopStart:(int)loopStart forPage:(uint)pageId
{
    if( loopStart >= 0 && loopStart < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopStart:page.loopStart forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopStart = loopStart;
    }
    
    [self postNotification:kSequencerPageLoopDidChangeNotification forPage:pageId];
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
    if( loopEnd >= 0 && loopEnd < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopEnd:page.loopEnd forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopEnd = loopEnd;
    }
    
    [self postNotification:kSequencerPageLoopDidChangeNotification forPage:pageId];
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
    if( loopStart >= 0 && loopStart < self.sharedPreferences.gridWidth && loopEnd >= 0 && loopEnd < self.sharedPreferences.gridWidth ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setLoopStart:page.loopStart andLoopEnd:page.loopEnd forPage:pageId];
        [self.undoManager setActionName:@"Loop Change"];
        
        page.loopStart = loopStart;
        page.loopEnd = loopEnd;
    }
    
    [self postNotification:kSequencerPageLoopDidChangeNotification forPage:pageId];
}


- (void) setLoopStartForAllPages:(int)loopStart
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self setLoopStart:loopStart forPage:i];
    }
}

- (void) setLoopEndForAllPages:(int)loopEnd
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self setLoopEnd:loopEnd forPage:i];
    }
}

- (void) incrementLoopStartForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self incrementLoopStartForPage:i];
    }
}

- (void) decrementLoopStartForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self decrementLoopStartForPage:i];
    }
}

- (void) incrementLoopEndForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self incrementLoopEndForPage:i];
    }
}

- (void) decrementLoopEndForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self decrementLoopEndForPage:i];
    }
}

- (void) setLoopStartForAllPages:(int)loopStart andLoopEnd:(int)loopEnd
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self setLoopStart:loopStart andLoopEnd:loopEnd forPage:i];
    }
}


- (void) setLoopStart:(int)loopStart forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self setLoopStart:loopStart forPage:i];
        }
    }
}

- (void) setLoopEnd:(int)loopEnd forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self setLoopEnd:loopEnd forPage:i];
        }
    }
}

- (void) incrementLoopStartForAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self incrementLoopStartForPage:i];
        }
    }
}

- (void) decrementLoopStartForAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self decrementLoopStartForPage:i];
        }
    }
}

- (void) incrementLoopEndForAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self incrementLoopEndForPage:i];
        }
    }
}

- (void) decrementLoopEndForAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self decrementLoopEndForPage:i];
        }
    }
}

- (void) setLoopStart:(int)loopStart andLoopEnd:(int)loopEnd forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            [self setLoopStart:loopStart andLoopEnd:loopEnd forPage:i];
        }
    }
}


- (int) swingTypeForPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return page.swingType;
}

- (void) setSwingType:(int)swingType forPage:(uint)pageId
{
    int swingAmount = [self swingAmountForPage:pageId];
    
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"type"] intValue] == swingType && [[obj valueForKey:@"amount"] intValue] == swingAmount );
        return result;
    }];
    
    if( index != NSNotFound ) {
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setSwingType:page.swingType andSwingAmount:page.swingAmount forPage:pageId];
        [self.undoManager setActionName:@"Swing Change"];
        
        page.swingType = swingType;
    }
    
    [self postNotification:kSequencerPageSwingDidChangeNotification forPage:pageId];
}

- (int) swingAmountForPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return page.swingAmount;
}

- (void) setSwingAmount:(int)swingAmount forPage:(uint)pageId
{
    int swingType = [self swingTypeForPage:pageId];
    
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"type"] intValue] == swingType && [[obj valueForKey:@"amount"] intValue] == swingAmount );
        return result;
    }];
    
    if( index != NSNotFound ) {
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setSwingType:page.swingType andSwingAmount:page.swingAmount forPage:pageId];
        [self.undoManager setActionName:@"Swing Change"];
        
        page.swingAmount = swingAmount;
    }
    
    [self postNotification:kSequencerPageSwingDidChangeNotification forPage:pageId];
}

- (void) setSwingType:(int)swingType andSwingAmount:(int)swingAmount forPage:(uint)pageId
{
    NSUInteger index = [self.swingArray indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        BOOL result = ( [[obj valueForKey:@"type"] intValue] == swingType && [[obj valueForKey:@"amount"] intValue] == swingAmount );
        return result;
    }];
    
    if( index != NSNotFound ) {
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setSwingType:page.swingType andSwingAmount:page.swingAmount forPage:pageId];
        [self.undoManager setActionName:@"Swing Change"];
        
        page.swingType = swingType;
        page.swingAmount = swingAmount;
    }
    
    [self postNotification:kSequencerPageSwingDidChangeNotification forPage:pageId];
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
    
    [self postNotification:kSequencerPageVelocityGrooveDidChangeNotification forPage:pageId];
}


- (int) transposeForPage:(uint)pageId
{
    return [[self.song.pages objectAtIndex:pageId] transpose];
}

- (void) setTranspose:(int)transpose forPage:(uint)pageId
{
    if( transpose >= SEQUENCER_MIDI_MAX * -1 && transpose <= SEQUENCER_MIDI_MAX ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setTranspose:page.transpose forPage:pageId];
        [self.undoManager setActionName:@"Transpose Change"];
        
        page.transpose = transpose;
    }
    
    [self postNotification:kSequencerPageTransposeDidChangeNotification forPage:pageId];
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
    }
    
    [self postNotification:kSequencerPageTransposeZeroStepDidChangeNotification forPage:pageId];
}

- (void) setTranspose:(int)transpose andTransposeZeroStep:(int)transposeZeroStep forPage:(uint)pageId
{
    if( transpose >= SEQUENCER_MIDI_MAX * -1 && transpose <= SEQUENCER_MIDI_MAX && transposeZeroStep >= 0 && transposeZeroStep < self.sharedPreferences.gridWidth ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setTranspose:page.transpose forPage:pageId];
        [self.undoManager setActionName:@"Transpose Change"];
        
        page.transpose = transpose;
        page.transposeZeroStep = transposeZeroStep;
    }
    
    [self postNotification:kSequencerPageTransposeDidChangeNotification forPage:pageId];
    [self postNotification:kSequencerPageTransposeZeroStepDidChangeNotification forPage:pageId];
}


- (NSArray *) pitchesForPage:(uint)pageId
{
    NSArray *pitches = [[self.song.pages objectAtIndex:pageId] pitches];
    NSArray *pitchesToReturn = [[NSArray alloc] initWithArray:pitches copyItems:YES];
    
    return pitchesToReturn;
}

- (void) setPitches:(NSArray *)pitches forPage:(uint)pageId
{
    if( pitches.count == SEQUENCER_SIZE ) {
    
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setPitches:page.pitches forPage:pageId];
        [self.undoManager setActionName:@"Pitches Change"];
        
        page.pitches = [pitches mutableCopy];
    }
    
    [self postNotification:kSequencerPagePitchesDidChangeNotification forPage:pageId];
}

- (int) pitchAtRow:(uint)row forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    return [[page.pitches objectAtIndex:row] intValue];
}

- (void) setPitch:(int)pitch atRow:(uint)row forPage:(uint)pageId
{
    if( pitch >= SEQUENCER_MIDI_MIN && pitch <= SEQUENCER_MIDI_MAX && row < SEQUENCER_SIZE ) {
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        [[self.undoManager prepareWithInvocationTarget:self] setPitch:[[page.pitches objectAtIndex:row] intValue] atRow:row forPage:pageId];
        [self.undoManager setActionName:@"Pitch Change"];
        
        [page.pitches replaceObjectAtIndex:row withObject:[NSNumber numberWithInt:pitch]];
    }
    
    [self postNotification:kSequencerPagePitchesDidChangeNotification forPage:pageId];
}



#pragma mark - Pattern


- (void) startOrStopPattern:(uint)patternId inPage:(uint)pageId
{
    // Start fwd playback from loop start
    if( [self playModeForPage:pageId] == EatsSequencerPlayMode_Pause ) {
        
        [self setPlayMode:EatsSequencerPlayMode_Forward forPage:pageId];
        [self setNextStep:[NSNumber numberWithInt:[self loopStartForPage:pageId]] forPage:pageId];
        
        [self setNextOrCurrentPatternId:[NSNumber numberWithUnsignedInt:patternId] forPage:pageId];
        
    // Pause a pattern that is playing
    } else if( [self currentPatternIdForPage:pageId] == patternId ) {
        [self setPlayMode:EatsSequencerPlayMode_Pause forPage:pageId];
        
    } else {
        [self setNextOrCurrentPatternId:[NSNumber numberWithUnsignedInt:patternId] forPage:pageId];
    }
}

- (NSSet *) notesForPattern:(uint)patternId inPage:(uint)pageId
{
    __block NSSet *notesToReturn;
    
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *notes = [page.patterns objectAtIndex:patternId];
        notesToReturn = [[NSSet alloc] initWithSet:notes copyItems:YES];
        
    });
    
    return notesToReturn;
}

- (uint) numberOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    __block uint notesCount;
    
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        notesCount = (uint)[[page.patterns objectAtIndex:patternId] count];
        
    });
    
    return notesCount;
}

- (void) setNotes:(NSSet *)notes forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:[page.patterns objectAtIndex:patternId] forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
        [page.patterns replaceObjectAtIndex:patternId withObject:[notes mutableCopy]];
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}


- (void) shiftPatternLeft:(uint)patternId inPage:(uint)pageId
{
    [self shiftPattern:patternId inPage:pageId horizontally:-1];
}

- (void) shiftPatternRight:(uint)patternId inPage:(uint)pageId
{
    [self shiftPattern:patternId inPage:pageId horizontally:1];
}

- (void) shiftPatternUp:(uint)patternId inPage:(uint)pageId
{
    [self shiftPattern:patternId inPage:pageId vertically:1];
}

- (void) shiftPatternDown:(uint)patternId inPage:(uint)pageId
{
    [self shiftPattern:patternId inPage:pageId vertically:-1];
}

- (void) shiftPattern:(uint)patternId inPage:(uint)pageId horizontally:(int)amount
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
        for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
            if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                
                int newStep = note.step + amount;
                if( newStep >= (int)self.sharedPreferences.gridWidth )
                    newStep = 0;
                else if( newStep < 0 )
                    newStep = self.sharedPreferences.gridWidth - 1;
                
                note.step = newStep;
            }
        }
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}

- (void) shiftPattern:(uint)patternId inPage:(uint)pageId vertically:(int)amount
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
        for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
            if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                
                int newRow = note.row + amount;
                if( newRow >= (int)self.sharedPreferences.gridHeight )
                    newRow = 0;
                else if( newRow < 0 )
                    newRow = self.sharedPreferences.gridHeight - 1;
                
                note.row = newRow;
            }
        }
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}


- (void) setVelocityOfNotes:(int)velocity forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    if( velocity >= SEQUENCER_MIDI_MIN && velocity <= SEQUENCER_MIDI_MAX ) {
       
        dispatch_sync(self.sequencerQueue, ^(void) {
            
            NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
            [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
            [self.undoManager setActionName:@"Pattern Change"];
            
            for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
                
                if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                    note.velocity = velocity;
                    [self postNotification:kSequencerNoteVelocityDidChangeNotification forNote:note inPattern:patternId inPage:pageId];
                }
            }
            
        });
    }
}

- (void) incrementVelocityOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustVelocityOfNotesByAmount:1 forPattern:patternId inPage:pageId];
}

- (void) decrementVelocityOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustVelocityOfNotesByAmount:-1 forPattern:patternId inPage:pageId];
}

- (void) incrementByLargeStepVelocityOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustVelocityOfNotesByAmount:( SEQUENCER_MIDI_MAX + 1 ) / self.sharedPreferences.gridWidth forPattern:patternId inPage:pageId];
}

- (void) decrementByLargeStepVelocityOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustVelocityOfNotesByAmount:-( ( SEQUENCER_MIDI_MAX + 1 ) / self.sharedPreferences.gridWidth ) forPattern:patternId inPage:pageId];
}

- (void) adjustVelocityOfNotesByAmount:(int)amount forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];

    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
        for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
            
            if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                int newVelocity = note.velocity + amount;
                
                if( newVelocity < SEQUENCER_MIDI_MIN )
                    newVelocity = SEQUENCER_MIDI_MIN;
                if( newVelocity > SEQUENCER_MIDI_MAX )
                    newVelocity = SEQUENCER_MIDI_MAX;
                    
                note.velocity = newVelocity;
                
                [self postNotification:kSequencerNoteVelocityDidChangeNotification forNote:note inPattern:patternId inPage:pageId];
            }
        }
        
    });
}


- (void) setLengthOfNotes:(int)length forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    if( length >= 1 && length <= self.sharedPreferences.gridWidth ) {
        
        dispatch_sync(self.sequencerQueue, ^(void) {
            
            NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
            [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
            [self.undoManager setActionName:@"Pattern Change"];
            
            for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
                
                if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                    note.length = length;
                    [self postNotification:kSequencerNoteLengthDidChangeNotification forNote:note inPattern:patternId inPage:pageId];
                }
            }
            
        });
    }
}

- (void) incrementLengthOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustLengthOfNotesByAmount:1 forPattern:patternId inPage:pageId];
}

- (void) decrementLengthOfNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    [self adjustLengthOfNotesByAmount:-1 forPattern:patternId inPage:pageId];
}

- (void) adjustLengthOfNotesByAmount:(int)amount forPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *currentNotes = [[NSSet alloc] initWithSet:[page.patterns objectAtIndex:patternId] copyItems:YES];
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
        for( SequencerNote *note in [page.patterns objectAtIndex:patternId] ){
            
            if( note.step < self.sharedPreferences.gridWidth && note.row < self.sharedPreferences.gridHeight ) {
                int newLength = note.length + amount;
                
                if( newLength < 1 )
                    newLength = 1;
                if( newLength > self.sharedPreferences.gridWidth )
                    newLength = self.sharedPreferences.gridWidth;

                note.length = newLength;
                    
                [self postNotification:kSequencerNoteLengthDidChangeNotification forNote:note inPattern:patternId inPage:pageId];

            }
        }
        
    });
}


- (void) clearNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:[[page.patterns objectAtIndex:patternId] copy] forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
    
        [[page.patterns objectAtIndex:patternId] removeAllObjects];
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}

- (void) copyNotesFromPattern:(uint)fromPatternId fromPage:(uint)fromPageId toPattern:(uint)toPatternId toPage:(uint)toPageId
{
    SequencerPage *fromPage = [self.song.pages objectAtIndex:fromPageId];
    SequencerPage *toPage = [self.song.pages objectAtIndex:toPageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:[toPage.patterns objectAtIndex:toPatternId] forPattern:toPatternId inPage:toPageId];
        [self.undoManager setActionName:@"Pattern Copy"];

        NSMutableSet *fromNotes = [[NSMutableSet alloc] initWithSet:[fromPage.patterns objectAtIndex:fromPatternId] copyItems:YES];
        [toPage.patterns replaceObjectAtIndex:toPatternId withObject:fromNotes];
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:toPatternId inPage:toPageId];
}


- (void) pasteboardCutNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    [self pasteboardCopyNotesForPattern:patternId inPage:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *currentNotes = [[page.patterns objectAtIndex:patternId] copy];
        [[page.patterns objectAtIndex:patternId] removeAllObjects];
        
        [[self.undoManager prepareWithInvocationTarget:self] setNotes:currentNotes forPattern:patternId inPage:pageId];
        [self.undoManager setActionName:@"Pattern Change"];
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}

- (void) pasteboardCopyNotesForPattern:(uint)patternId inPage:(uint)pageId
{    
    NSSet *notes = [self notesForPattern:patternId inPage:pageId];
        
    if( notes.count ) {
        NSData *notesData = [NSKeyedArchiver archivedDataWithRootObject:notes];
        
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        
        NSString *pasteboardType = kSequencerNotesDataPasteboardType;
        NSArray *pasteboardTypes = [NSArray arrayWithObject:pasteboardType];
        [pasteboard declareTypes:pasteboardTypes owner:nil];
        
        [pasteboard setData:notesData forType:pasteboardType];
    }
}

- (void) pasteboardPasteNotesForPattern:(uint)patternId inPage:(uint)pageId
{
    NSString *pasteboardType = kSequencerNotesDataPasteboardType;
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    
    NSData *notesData = [pasteboard dataForType:pasteboardType];
    if( notesData ) {
        NSSet *newNotes = [NSKeyedUnarchiver unarchiveObjectWithData:notesData];
        [self setNotes:newNotes forPattern:patternId inPage:pageId];
    }
}



#pragma mark - Note


- (SequencerNote *) noteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    __block SequencerNote *noteToReturn = nil;
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *notes = [page.patterns objectAtIndex:patternId];
    
        for( SequencerNote *note in notes ) {
            if( note.row == row && note.step == step ) {
                // Return a copy so no-one can change what's stored in the model
                noteToReturn = [note copy];
                break;
            }
        }
        
    });
    
    return noteToReturn;
}


- (SequencerNote *) noteThatIsSelectableAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    // See if there's a note there and return a copy of it if there is
    
    // If we are showing note length on the grid then then we need to look through all the notes on the row, checking their length
    if( self.sharedPreferences.showNoteLengthOnGrid ) {
        
        int playMode = [self playModeForPage:pageId];
        BOOL sortDirection = ( playMode == EatsSequencerPlayMode_Reverse ) ? NO : YES;
        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"step" ascending:sortDirection]];
        
        NSSet *notesOnThisRow = [self notesAtRow:row inPattern:patternId inPage:pageId];
        
        NSArray *sortedNotesOnThisRow = [notesOnThisRow sortedArrayUsingDescriptors:sortDescriptors];
        
        for( SequencerNote *note in sortedNotesOnThisRow ) {
            
            if( note.step < self.sharedPreferences.gridWidth ) {
                int endPoint;
                
                // When in reverse
                if( playMode == EatsSequencerPlayMode_Reverse ) {
                    endPoint = note.step - note.length + 1;
                    
                    // If it's wrapping
                    if( endPoint < 0 && ( step <= note.step || step >= endPoint + self.sharedPreferences.gridWidth ) ) {
                        return note;
                        
                    // If it's not wrapping
                    } else if( step <= note.step && step >= endPoint ) {
                        return note;
                    }
                    
                // When playing forwards
                } else {
                    endPoint = note.step + note.length - 1;
                    
                    // If it's wrapping and we're going forwards
                    if( endPoint >= self.sharedPreferences.gridWidth && ( step >= note.step || step <= endPoint - self.sharedPreferences.gridWidth ) ) {
                        return note;
                        
                    // If it's not wrapping
                    } else if( step >= note.step && step <= endPoint ) {
                        return note;
                    }
                }
            }
        }
        
    // If we're not showing note length on the grid then this is much simpler!
    } else {
        return [self noteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    }
    
    // Return nil if we didn't find one
    return nil;
}

- (NSSet *) notesAtStep:(uint)step inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    __block NSSet *notesToCheck;
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        NSSet *notes = [page.patterns objectAtIndex:patternId];
        notesToCheck = [[NSSet alloc] initWithSet:notes copyItems:YES];
        
    });
    
    NSSet *notesMatchingStep = [notesToCheck objectsPassingTest:^(id obj, BOOL *stop) {
        SequencerNote *note = (SequencerNote *)obj;
        BOOL testResult = ( note.step == step );
        return testResult;
    }];
    
    return notesMatchingStep;
}

- (NSSet *) notesAtRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    __block NSSet *notesToCheck;
    
    dispatch_sync(self.sequencerQueue, ^(void) {
        
        NSSet *notes = [page.patterns objectAtIndex:patternId];
        notesToCheck = [[NSSet alloc] initWithSet:notes copyItems:YES];
        
    });
    
    NSSet *notesMatchingRow = [notesToCheck objectsPassingTest:^(id obj, BOOL *stop) {
        SequencerNote *note = (SequencerNote *)obj;
        BOOL testResult = ( note.row == row );
        return testResult;
    }];
    
    return notesMatchingRow;
}


- (int) lengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerNote *note = [self noteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    
    if( note )
        return note.length;
    
    return 0;
}

- (void) setLength:(int)length forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    if( length > 0 && length <= self.sharedPreferences.gridWidth ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        dispatch_sync(self.sequencerQueue, ^(void) {
        
            NSSet *notes = [page.patterns objectAtIndex:patternId];
            
            for( SequencerNote *note in notes ) {
                if( note.row == row && note.step == step ) {
                    
                    [[self.undoManager prepareWithInvocationTarget:self] setLength:note.length forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
                    [self.undoManager setActionName:@"Note Length Change"];
                    
                    note.length = length;
                    
                    [self postNotification:kSequencerNoteLengthDidChangeNotification forNote:note inPattern:patternId inPage:pageId];
                    
                    return;
                }
            }
            
        });
        
    }
}

- (void) incrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    [self setLength:[self lengthForNoteAtStep:step atRow:row inPattern:patternId inPage:pageId] + 1 forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
}

- (void) decrementLengthForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    [self setLength:[self lengthForNoteAtStep:step atRow:row inPattern:patternId inPage:pageId] - 1 forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
}


- (int) velocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerNote *note = [self noteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    
    if( note )
        return note.velocity;
    
    return 0;
}

- (void) setVelocity:(int)velocity forNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    if( velocity >= SEQUENCER_MIDI_MIN && velocity <= SEQUENCER_MIDI_MAX ) {
        
        SequencerPage *page = [self.song.pages objectAtIndex:pageId];
        
        dispatch_sync(self.sequencerQueue, ^(void) {
        
            NSSet *notes = [page.patterns objectAtIndex:patternId];
            
            for( SequencerNote *note in notes ) {
                if( note.row == row && note.step == step ) {
                    
                    [[self.undoManager prepareWithInvocationTarget:self] setVelocity:note.velocity forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
                    [self.undoManager setActionName:@"Note Velocity Change"];
                    
                    note.velocity = velocity;
                    
                    [self postNotification:kSequencerNoteVelocityDidChangeNotification forNote:note inPattern:patternId inPage:pageId];
                    
                    return;
                }
            }
            
        });
        
    }
}

- (void) incrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    [self setVelocity:[self velocityForNoteAtStep:step atRow:row inPattern:patternId inPage:pageId] + 1 forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
}

- (void) decrementVelocityForNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    [self setVelocity:[self velocityForNoteAtStep:step atRow:row inPattern:patternId inPage:pageId] - 1 forNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
}

- (void) addOrRemoveNoteThatIsSelectableAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerNote *note = [self noteThatIsSelectableAtStep:step atRow:row inPattern:patternId inPage:pageId];
    if( note )
        [self removeNoteAtStep:note.step atRow:note.row inPattern:patternId inPage:pageId];
    else
        [self addNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
}

- (void) addNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    [self addNoteAtStep:step atRow:row withLength:1 withVelocity:self.sharedPreferences.defaultMIDINoteVelocity.intValue inPattern:patternId inPage:pageId];
}

- (void) addNoteAtStep:(uint)step atRow:(uint)row withLength:(uint)length withVelocity:(uint)velocity inPattern:(uint)patternId inPage:(uint)pageId
{
    [[self.undoManager prepareWithInvocationTarget:self] removeNoteAtStep:step atRow:row inPattern:patternId inPage:pageId];
    [self.undoManager setActionName:@"Pattern Change"];
    
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    SequencerNote *note = [[SequencerNote alloc] init];
    note.step = step;
    note.row = row;
    note.length = length;
    note.velocity = velocity;
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        NSMutableSet *pattern = [page.patterns objectAtIndex:patternId];
        [pattern addObject:note];
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}

- (void) removeNoteAtStep:(uint)step atRow:(uint)row inPattern:(uint)patternId inPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    dispatch_sync(self.sequencerQueue, ^(void) {
    
        NSSet *notes = [page.patterns objectAtIndex:patternId];
        
        SequencerNote *noteToRemove;
        
        for( SequencerNote *note in notes ) {
            if( note.row == row && note.step == step ) {
                noteToRemove = note;
                break;
            }
        }
        
        if( noteToRemove ) {
        
            [[self.undoManager prepareWithInvocationTarget:self] addNoteAtStep:step atRow:row withLength:noteToRemove.length withVelocity:noteToRemove.velocity inPattern:patternId inPage:pageId];
            [self.undoManager setActionName:@"Pattern Change"];
            
            SequencerPage *page = [self.song.pages objectAtIndex:pageId];
            NSMutableSet *pattern = [page.patterns objectAtIndex:patternId];
            
            [pattern removeObject:noteToRemove];
            
        }
        
    });
    
    [self postNotification:kSequencerPagePatternNotesDidChangeNotification forPattern:patternId inPage:pageId];
}



#pragma mark - State


- (int) currentPageId
{
    return self.state.currentPageId;
}

- (void) setCurrentPageId:(int)pageId
{
    if( pageId >= 0 && pageId < kSequencerNumberOfPages && pageId != self.state.currentPageId ) {
        
        BOOL directionRight = NO;
        if( pageId > self.state.currentPageId )
            directionRight = YES;
        
        self.state.currentPageId = pageId;
        
        if( directionRight )
            [self postNotification:kSequencerStateCurrentPageDidChangeRightNotification];
        else
            [self postNotification:kSequencerStateCurrentPageDidChangeLeftNotification];
    }
}

- (void) incrementCurrentPageId
{
    int newPageId = self.state.currentPageId + 1;
    if( newPageId >= kSequencerNumberOfPages )
        newPageId = 0;
    
    self.state.currentPageId = newPageId;
    
    [self postNotification:kSequencerStateCurrentPageDidChangeRightNotification];
}

- (void) decrementCurrentPageId
{
    int newPageId = self.state.currentPageId - 1;
    if( newPageId < 0 )
        newPageId = kSequencerNumberOfPages - 1;
    
    self.state.currentPageId = newPageId;
    
    [self postNotification:kSequencerStateCurrentPageDidChangeLeftNotification];
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
    }
    
    [self postNotification:kSequencerPageStateCurrentPatternIdDidChangeNotification forPage:pageId];
}


- (NSNumber *) nextPatternIdForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return [pageState.nextPatternId copy];
}

- (void) setNextPatternId:(NSNumber *)patternId forPage:(uint)pageId
{
    SequencerPage *page = [self.song.pages objectAtIndex:pageId];
    
    if( patternId.intValue >= 0 && patternId.intValue < page.patterns.count ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.nextPatternId = patternId;
    }
    
    [self postNotification:kSequencerPageStateNextPatternIdDidChangeNotification forPage:pageId];
}

- (void) setNextOrCurrentPatternId:(NSNumber *)patternId forPage:(uint)pageId
{
    if( [self patternQuantization] && ( [self playModeForPage:pageId] != EatsSequencerPlayMode_Pause && [self playModeForPage:pageId] != EatsSequencerPlayMode_Slice ) )
        [self setNextPatternId:patternId forPage:pageId];
    else
        [self setCurrentPatternId:patternId.intValue forPage:pageId];
}

- (void) setNextOrCurrentPatternIdForAllPages:(NSNumber *)patternId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        [self setNextOrCurrentPatternId:patternId forPage:i];
    }
}

- (void) setNextOrCurrentPatternId:(NSNumber *)patternId forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            SequencerPageState *pageState = [self.state.pageStates objectAtIndex:i];
            if( pageState.playMode != EatsSequencerPlayMode_Pause )
                [self setNextOrCurrentPatternId:patternId forPage:i];
        }
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
    }
    
    [self postNotification:kSequencerPageStateCurrentStepDidChangeNotification forPage:pageId];
}


- (NSNumber *) nextStepForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return [pageState.nextStep copy];
}

- (void) setNextStep:(NSNumber *)step forPage:(uint)pageId
{
    if( step.intValue >= 0 && step.intValue < self.sharedPreferences.gridWidth ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.nextStep = step;
    }
    
    [self postNotification:kSequencerPageStateNextStepDidChangeNotification forPage:pageId];
}

- (void) setNextStepForAllPages:(NSNumber *)step
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:i];
        if( pageState.playMode != EatsSequencerPlayMode_Pause )
            [self setNextStep:step forPage:i];
    }
}

- (void) setNextStep:(NSNumber *)step forAllPagesExcept:(uint)pageId
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        if( i != pageId ) {
            SequencerPageState *pageState = [self.state.pageStates objectAtIndex:i];
            if( pageState.playMode != EatsSequencerPlayMode_Pause )
                [self setNextStep:step forPage:i];
        }
    }
}


- (void) incrementStepForPage:(uint)pageId
{
    int step = [self currentStepForPage:pageId] + 1;
    
    if ( step > [self loopEndForPage:pageId] )
        step = [self loopStartForPage:pageId];
    
    [self setNextStep:[NSNumber numberWithInt:step] forPage:pageId];
}

- (void) incrementStepForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        
        int step = [self currentStepForPage:i] + 1;
        
        if ( step > [self loopEndForPage:i] )
            step = [self loopStartForPage:i];
        
        [self setNextStep:[NSNumber numberWithInt:step] forPage:i];
    }
}


- (void) decrementStepForPage:(uint)pageId
{
    int step = [self currentStepForPage:pageId] - 1;
    
    if ( step < [self loopStartForPage:pageId] )
        step = [self loopEndForPage:pageId];
    
    [self setNextStep:[NSNumber numberWithInt:step] forPage:pageId];
}

- (void) decrementStepForAllPages
{
    for( int i = 0; i < kSequencerNumberOfPages; i ++ ) {
        
        int step = [self currentStepForPage:i] - 1;
        
        if ( step < [self loopStartForPage:i] )
            step = [self loopEndForPage:i];
        
        [self setNextStep:[NSNumber numberWithInt:step] forPage:i];
    }
}


- (void) resetPlayPositionsForAllPlayingPages
{
    //Reset the play positions of all the active loops
    int pageId = 0;
    for( SequencerPageState *pageState in self.state.pageStates ) {
        if( pageState.playMode == EatsSequencerPlayMode_Pause || pageState.playMode == EatsSequencerPlayMode_Forward ) {
            [self setCurrentStep:[self loopEndForPage:pageId] forPage:pageId];
            [self setInLoop:YES forPage:pageId];
        } else if( pageState.playMode == EatsSequencerPlayMode_Reverse ) {
            [self setCurrentStep:[self loopStartForPage:pageId] forPage:pageId];
            [self setInLoop:YES forPage:pageId];
        }
        pageId ++;
    }
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
    
    [self postNotification:kSequencerPageStateInLoopDidChangeNotification forPage:pageId];
}


- (int) playModeForPage:(uint)pageId
{
    SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
    return pageState.playMode;
}

- (void) setPlayMode:(int)playMode forPage:(uint)pageId
{
    if( playMode >= 0 && playMode <= 4 ) {
        SequencerPageState *pageState = [self.state.pageStates objectAtIndex:pageId];
        pageState.playMode = playMode;
        [self setNextStep:nil forPage:pageId];
    }
    
    [self postNotification:kSequencerPageStatePlayModeDidChangeNotification forPage:pageId];
}


#pragma mark - Private methods

// Some useful methods for notifications to use

- (BOOL) isNotificationFromCurrentPage:(NSNotification *)notification
{
    return ( [[notification.userInfo valueForKey:@"pageId"] intValue] == self.currentPageId );
}

- (BOOL) isNotificationFromCurrentPattern:(NSNotification *)notification
{
    return ( [[notification.userInfo valueForKey:@"pageId"] intValue] == self.currentPageId && [[notification.userInfo valueForKey:@"patternId"] intValue] == [self currentPatternIdForPage:self.currentPageId] );
}

- (void) postNotification:(NSString *)notificationName
{
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    });
}

- (void) postNotification:(NSString *)notificationName forPage:(uint)pageId
{
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pageId], @"pageId", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
    });
}

- (void) postNotification:(NSString *)notificationName forPattern:(int)patternId inPage:(uint)pageId
{
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:patternId], @"patternId",
                                                                            [NSNumber numberWithInt:pageId], @"pageId",
                                                                            nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
    });
}

- (void) postNotification:(NSString *)notificationName forNote:(SequencerNote *)note inPattern:(int)patternId inPage:(uint)pageId
{
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[note copy], @"note",
                                                                            [NSNumber numberWithInt:patternId], @"patternId",
                                                                            [NSNumber numberWithInt:pageId], @"pageId",
                                                                            nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
    });
}


@end
