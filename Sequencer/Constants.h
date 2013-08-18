//
//  Constants.h
//  Sequencer
//
//  Created by Mark Wheeler on 17/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//


#pragma mark - General

extern int const kSequencerNumberOfPages;

extern NSString *const kSequencerNotesDataPasteboardType;

typedef enum EatsSequencerPlayMode {
    EatsSequencerPlayMode_Pause,
    EatsSequencerPlayMode_Forward,
    EatsSequencerPlayMode_Reverse,
    EatsSequencerPlayMode_Random
} EatsSequencerPlayMode;


#pragma mark - Errors

extern NSString *const kSequencerErrorDomain;

typedef enum SequencerErrorCode {
    SequencerErrorCode_Undefined = 0,
    SequencerErrorCode_UnarchiveFailed
} SequencerErrorCode;


#pragma mark - Notifications

// Song

extern NSString *const kSequencerSongBPMDidChangeNotification;
extern NSString *const kSequencerSongStepQuantizationDidChangeNotification;
extern NSString *const kSequencerSongPatternQuantizationDidChangeNotification;

extern NSString *const kSequencerPageChannelDidChangeNotification;
extern NSString *const kSequencerPageNameDidChangeNotification;

extern NSString *const kSequencerPageStepLengthDidChangeNotification;
extern NSString *const kSequencerPageLoopDidChangeNotification;

extern NSString *const kSequencerPageSwingTypeDidChangeNotification;
extern NSString *const kSequencerPageSwingAmountDidChangeNotification;
extern NSString *const kSequencerPageVelocityGrooveDidChangeNotification;
extern NSString *const kSequencerPageTransposeDidChangeNotification;
extern NSString *const kSequencerPageTransposeZeroStepDidChangeNotification;

extern NSString *const kSequencerPagePitchesDidChangeNotification;

extern NSString *const kSequencerPatternDidChangeNotification;


// State

extern NSString *const kSequencerStateCurrentPageDidChangeNotification;

extern NSString *const kSequencerPageStateCurrentPatternIdDidChangeNotification;
extern NSString *const kSequencerPageStateNextPatternIdDidChangeNotification;

extern NSString *const kSequencerPageStateCurrentStepDidChangeNotification;
extern NSString *const kSequencerPageStateNextStepDidChangeNotification;
extern NSString *const kSequencerPageStateInLoopDidChangeNotification;

extern NSString *const kSequencerPageStatePlayModeDidChangeNotification;