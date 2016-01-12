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

// Grid controller connection

NSString *const kGridControllerNoneNotification = @"GridControllerNoneNotification";
NSString *const kGridControllerConnectingNotification = @"GridControllerConnectingNotification";
NSString *const kGridControllerConnectionErrorNotification = @"GridControllerConnectionErrorNotification";
NSString *const kGridControllerConnectedNotification = @"GridControllerConnectedNotification";
NSString *const kGridControllerCalibratingNotification = @"GridControllerCalibratingNotification";
NSString *const kGridControllerDoneCalibratingNotification = @"GridControllerDoneCalibratingNotification";
NSString *const kGridControllerSetRotationNotification = @"GridControllerSetRotationNotification";
NSString *const kGridControllerSizeChangedNotification = @"GridControllerSizeChangedNotification";


// Input

NSString *const kInputGridNotification = @"InputGridNotification";
NSString *const kInputButtonNotification = @"InputButtonNotification";
NSString *const kInputValueNotification = @"InputValueNotification";


// External clock

NSString *const kExternalClockZeroNotification = @"ExternalClockZeroNotification";
NSString *const kExternalClockStartNotification = @"ExternalClockStartNotification";
NSString *const kExternalClockContinueNotification = @"ExternalClockContinueNotification";
NSString *const kExternalClockStopNotification = @"ExternalClockStopNotification";
NSString *const kExternalClockBPMNotification = @"ExternalClockBPMNotification";


// Tick

NSString *const kClockMinQuantizationTick = @"ClockMinQuantizationTick";


// Preferences

NSString *const kPreferencesThatRequiresGridRedrawDidChangeNotification = @"PreferencesThatRequiresGridRedrawDidChangeNotification";


// Song

NSString *const kSequencerSongBPMDidChangeNotification = @"SequencerSongBPMDidChangeNotification";
NSString *const kSequencerSongStepQuantizationDidChangeNotification = @"SequencerSongStepQuantizationDidChangeNotification";
NSString *const kSequencerSongPatternQuantizationDidChangeNotification = @"SequencerSongPatternQuantizationDidChangeNotification";

NSString *const kSequencerPageChannelDidChangeNotification = @"SequencerPageChannelDidChangeNotification";
NSString *const kSequencerPageNameDidChangeNotification = @"SequencerPageNameDidChangeNotification";

NSString *const kSequencerPageStepLengthDidChangeNotification = @"SequencerPageStepLengthDidChangeNotification";
NSString *const kSequencerPageLoopDidChangeNotification = @"SequencerPageLoopDidChangeNotification";

NSString *const kSequencerPageSendNotesDidChangeNotification = @"SequencerPageSendNotesDidChangeNotification";

NSString *const kSequencerPageModulationDestinationsDidChangeNotification = @"SequencerPageModulationDestinationsDidChangeNotification";
NSString *const kSequencerPageModulationSmoothDidChangeNotification = @"SequencerPageModulationSmoothDidChangeNotification";

NSString *const kSequencerPageSwingDidChangeNotification = @"SequencerPageSwingDidChangeNotification";
NSString *const kSequencerPageVelocityGrooveDidChangeNotification = @"SequencerPageVelocityGrooveDidChangeNotification";
NSString *const kSequencerPageTransposeDidChangeNotification = @"SequencerPageTransposeDidChangeNotification";
NSString *const kSequencerPageTransposeZeroStepDidChangeNotification = @"SequencerPageTransposeZeroStepDidChangeNotification";

NSString *const kSequencerPagePitchesDidChangeNotification = @"SequencerPagePitchesDidChangeNotification";

NSString *const kSequencerPagePatternNotesDidChangeNotification = @"SequencerPagePatternNotesDidChangeNotification";

NSString *const kSequencerNoteLengthDidChangeNotification = @"SequencerNoteLengthDidChangeNotification";
NSString *const kSequencerNoteVelocityDidChangeNotification = @"SequencerNoteVelocityDidChangeNotification";
NSString *const kSequencerNoteModulationValuesDidChangeNotification = @"SequencerNoteModulationValuesDidChangeNotification";


// State

NSString *const kSequencerStateCurrentPageDidChangeLeftNotification = @"SequencerStateCurrentPageDidChangeLeftNotification";
NSString *const kSequencerStateCurrentPageDidChangeRightNotification = @"SequencerStateCurrentPageDidChangeRightNotification";

NSString *const kSequencerPageStateCurrentPatternIdDidChangeNotification = @"SequencerPageStateCurrentPatternIdDidChangeNotification";
NSString *const kSequencerPageStateNextPatternIdDidChangeNotification = @"SequencerPageStateNextPatternIdDidChangeNotification";

NSString *const kSequencerPageStateCurrentStepDidChangeNotification = @"SequencerPageStateCurrentStepDidChangeNotification";
NSString *const kSequencerPageStateNextStepDidChangeNotification = @"SequencerPageStateNextStepDidChangeNotification";
NSString *const kSequencerPageStateInLoopDidChangeNotification = @"SequencerPageStateInLoopDidChangeNotification";

NSString *const kSequencerPageStateTickPositionDidChangeNotification = @"SequencerPageStateTickPositionDidChangeNotification";

NSString *const kSequencerPageStatePlayModeDidChangeNotification = @"SequencerPageStatePlayModeDidChangeNotification";


// Automation

NSString *const kSequencerAutomationLoopLengthDidChangeNotification = @"SequencerAutomationLoopLengthDidChangeNotification";
NSString *const kSequencerAutomationTickDidChangeNotification = @"SequencerAutomationTickDidChangeNotification";
NSString *const kSequencerAutomationModeDidChangeNotification = @"SequencerAutomationModeDidChangeNotification";
NSString *const kSequencerAutomationChangesDidChangeNotification = @"SequencerAutomationChangesDidChangeNotification";
NSString *const kSequencerAutomationRemoveAllChangesNotification = @"SequencerAutomationRemoveAllChangesNotification";
