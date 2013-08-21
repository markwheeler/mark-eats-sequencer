//
//  Constants.m
//  Sequencer
//
//  Created by Mark Wheeler on 17/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "Constants.h"


#pragma mark - General

int const kSequencerNumberOfPages = 8;

NSString *const kSequencerNotesDataPasteboardType = @"com.MarkEats.Sequencer.SequencerNotesData";


#pragma mark - Errors

NSString *const kSequencerErrorDomain = @"com.MarkEats.Sequencer.ErrorDomain";


#pragma mark - Notifications

NSString *const kPreferencesThatRequiresGridRedrawDidChangeNotification = @"PreferencesThatRequiresGridRedrawDidChangeNotification";

// Song

NSString *const kSequencerSongBPMDidChangeNotification = @"SequencerSongBPMDidChangeNotification";
NSString *const kSequencerSongStepQuantizationDidChangeNotification = @"SequencerSongStepQuantizationDidChangeNotification";
NSString *const kSequencerSongPatternQuantizationDidChangeNotification = @"SequencerSongPatternQuantizationDidChangeNotification";

NSString *const kSequencerPageChannelDidChangeNotification = @"SequencerPageChannelDidChangeNotification";
NSString *const kSequencerPageNameDidChangeNotification = @"SequencerPageNameDidChangeNotification";

NSString *const kSequencerPageStepLengthDidChangeNotification = @"SequencerPageStepLengthDidChangeNotification";
NSString *const kSequencerPageLoopDidChangeNotification = @"SequencerPageLoopDidChangeNotification";

NSString *const kSequencerPageSwingDidChangeNotification = @"SequencerPageSwingDidChangeNotification";
NSString *const kSequencerPageVelocityGrooveDidChangeNotification = @"SequencerPageVelocityGrooveDidChangeNotification";
NSString *const kSequencerPageTransposeDidChangeNotification = @"SequencerPageTransposeDidChangeNotification";
NSString *const kSequencerPageTransposeZeroStepDidChangeNotification = @"SequencerPageTransposeZeroStepDidChangeNotification";

NSString *const kSequencerPagePitchesDidChangeNotification = @"SequencerPagePitchesDidChangeNotification";

NSString *const kSequencerPagePatternNotesDidChangeNotification = @"SequencerPagePatternNotesDidChangeNotification";

NSString *const kSequencerNoteLengthDidChangeNotification = @"SequencerNoteLengthDidChangeNotification";
NSString *const kSequencerNoteVelocityDidChangeNotification = @"SequencerNoteVelocityDidChangeNotification";


// State

NSString *const kSequencerStateCurrentPageDidChangeLeftNotification = @"SequencerStateCurrentPageDidChangeLeftNotification";
NSString *const kSequencerStateCurrentPageDidChangeRightNotification = @"SequencerStateCurrentPageDidChangeRightNotification";

NSString *const kSequencerPageStateCurrentPatternIdDidChangeNotification = @"SequencerPageStateCurrentPatternIdDidChangeNotification";
NSString *const kSequencerPageStateNextPatternIdDidChangeNotification = @"SequencerPageStateNextPatternIdDidChangeNotification";

NSString *const kSequencerPageStateCurrentStepDidChangeNotification = @"SequencerPageStateCurrentStepDidChangeNotification";
NSString *const kSequencerPageStateNextStepDidChangeNotification = @"SequencerPageStateNextStepDidChangeNotification";
NSString *const kSequencerPageStateInLoopDidChangeNotification = @"SequencerPageStateInLoopDidChangeNotification";

NSString *const kSequencerPageStatePlayModeDidChangeNotification = @"SequencerPageStatePlayModeDidChangeNotification";
