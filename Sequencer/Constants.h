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
    EatsSequencerPlayMode_Random,
    EatsSequencerPlayMode_Slice
} EatsSequencerPlayMode;


#pragma mark - Errors

extern NSString *const kSequencerErrorDomain;

typedef enum SequencerErrorCode {
    SequencerErrorCode_Undefined = 0,
    SequencerErrorCode_UnarchiveFailed
} SequencerErrorCode;


#pragma mark - Notifications

// Grid controller connection

extern NSString *const kGridControllerNoneNotification;
extern NSString *const kGridControllerConnectingNotification;
extern NSString *const kGridControllerConnectionErrorNotification;
extern NSString *const kGridControllerConnectedNotification;
extern NSString *const kGridControllerSetRotationNotification;
extern NSString *const kGridControllerSizeChangedNotification;


// Input

extern NSString *const kInputGridNotification;
extern NSString *const kInputButtonNotification;
extern NSString *const kInputValueNotification;


// External clock

extern NSString *const kExternalClockZeroNotification;
extern NSString *const kExternalClockStartNotification;
extern NSString *const kExternalClockContinueNotification;
extern NSString *const kExternalClockStopNotification;
extern NSString *const kExternalClockBPMNotification;


// Tick

extern NSString *const kClockMinQuantizationTick;


// Preferences

extern NSString *const kPreferencesThatRequiresGridRedrawDidChangeNotification;

// Song

extern NSString *const kSequencerSongBPMDidChangeNotification;
extern NSString *const kSequencerSongStepQuantizationDidChangeNotification;
extern NSString *const kSequencerSongPatternQuantizationDidChangeNotification;

extern NSString *const kSequencerPageChannelDidChangeNotification;
extern NSString *const kSequencerPageNameDidChangeNotification;

extern NSString *const kSequencerPageStepLengthDidChangeNotification;
extern NSString *const kSequencerPageLoopDidChangeNotification;

extern NSString *const kSequencerPageSwingDidChangeNotification;
extern NSString *const kSequencerPageVelocityGrooveDidChangeNotification;
extern NSString *const kSequencerPageTransposeDidChangeNotification;
extern NSString *const kSequencerPageTransposeZeroStepDidChangeNotification;

extern NSString *const kSequencerPagePitchesDidChangeNotification;

extern NSString *const kSequencerPagePatternNotesDidChangeNotification;

extern NSString *const kSequencerNoteLengthDidChangeNotification;
extern NSString *const kSequencerNoteVelocityDidChangeNotification;


// State

extern NSString *const kSequencerStateCurrentPageDidChangeLeftNotification;
extern NSString *const kSequencerStateCurrentPageDidChangeRightNotification;

extern NSString *const kSequencerPageStateCurrentPatternIdDidChangeNotification;
extern NSString *const kSequencerPageStateNextPatternIdDidChangeNotification;

extern NSString *const kSequencerPageStateCurrentStepDidChangeNotification;
extern NSString *const kSequencerPageStateNextStepDidChangeNotification;
extern NSString *const kSequencerPageStateInLoopDidChangeNotification;

extern NSString *const kSequencerPageStatePlayModeDidChangeNotification;


// Automation

extern NSString *const kSequencerAutomationLoopLengthDidChangeNotification;
extern NSString *const kSequencerAutomationTickDidChangeNotification;
extern NSString *const kSequencerAutomationModeDidChangeNotification;
extern NSString *const kSequencerAutomationChangesDidChangeNotification;
