//
//  EatsModulationUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 02/01/2016.
//  Copyright © 2016 Mark Eats. All rights reserved.
//

#import "EatsModulationUtils.h"
#import <VVMIDI/VVMIDI.h>

@implementation EatsModulationUtils

+ (NSArray *) modulationDestinationsArray
{
    
    NSArray *modulationDestinations = [NSArray arrayWithObjects:
                                       
                                       // None
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"None", @"name", [NSNumber numberWithInt:0], @"type", [NSNumber numberWithInt:0], @"controllerNumber", nil],
                                       
                                       // Pitch Bend
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"Pitch Bend", @"name", [NSNumber numberWithInt:VVMIDIPitchWheelVal], @"type", [NSNumber numberWithInt:0], @"controllerNumber", nil],
                                       
                                       // Channel Pressure
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"Channel Pressure", @"name", [NSNumber numberWithInt:VVMIDIChannelPressureVal], @"type", [NSNumber numberWithInt:0], @"controllerNumber", nil],
                                       
                                       // CCs
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 0 (Bank Select)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:0], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 1 (Modulation)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:1], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 2 (Breath Controller)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:2], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 3", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:3], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 4 (Foot Controller)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:4], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 5 (Portamento Time)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:5], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 6 (Data Entry)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:6], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 7 (Volume)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:7], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 8 (Balance)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:8], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 9", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:9], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 10 (Pan)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:10], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 11 (Expression)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:11], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 12 (Effect Control 1)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:12], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 13 (Effect Control 2)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:13], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 14", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:14], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 15", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:15], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 16", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:16], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 17", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:17], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 18", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:18], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 19", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:19], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 20", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:20], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 21", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:21], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 22", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:22], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 23", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:23], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 24", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:24], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 25", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:25], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 26", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:26], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 27", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:27], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 28", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:28], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 29", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:29], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 30", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:30], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 31", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:31], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 32", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:32], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 33", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:33], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 34", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:34], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 35", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:35], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 36", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:36], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 37", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:37], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 38 (Data Entry Fine)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:38], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 39", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:39], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 40", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:40], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 41", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:41], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 42", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:42], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 43", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:43], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 44", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:44], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 45", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:45], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 46", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:46], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 47", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:47], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 48", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:48], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 49", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:49], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 50", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:50], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 51", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:51], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 52", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:52], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 53", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:53], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 54", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:54], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 55", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:55], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 56", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:56], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 57", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:57], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 58", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:58], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 59", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:59], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 60", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:60], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 61", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:61], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 62", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:62], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 63", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:63], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 64 (Hold Pedal)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:64], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 65 (Portamento On/Off)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:65], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 66 (Sostenuto Pedal)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:66], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 67 (Soft Pedal)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:67], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 68 (Legato Pedal)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:68], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 69 (Hold Pedal 2)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:69], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 70", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:70], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 71", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:71], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 72", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:72], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 73", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:73], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 74", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:74], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 75", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:75], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 76", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:76], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 77", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:77], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 78", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:78], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 79", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:79], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 80", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:80], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 81", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:81], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 82", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:82], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 83", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:83], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 84", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:84], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 85", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:85], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 86", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:86], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 87", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:87], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 88", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:88], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 89", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:89], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 90", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:90], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 91", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:91], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 92", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:92], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 93", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:93], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 94", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:94], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 95", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:95], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 96 (Data Entry Increment)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:96], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 97 (Data Entry Decrement)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:97], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 98 (NRPN LSB)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:98], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 99 (NRPN MSB)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:99], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 100 (RPN LSB)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:100], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 101 (RPN MSB)", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:101], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 102", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:102], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 103", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:103], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 104", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:104], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 105", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:105], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 106", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:106], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 107", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:107], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 108", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:108], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 109", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:109], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 110", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:110], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 111", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:111], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 112", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:112], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 113", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:113], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 114", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:114], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 115", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:115], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 116", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:116], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 117", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:117], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 118", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:118], @"controllerNumber", nil],
                                       
                                       [NSDictionary dictionaryWithObjectsAndKeys:@"CC 119", @"name", [NSNumber numberWithInt:VVMIDIControlChangeVal], @"type", [NSNumber numberWithInt:119], @"controllerNumber", nil],
                                       
                                       nil];
    
    return modulationDestinations;
}

@end
