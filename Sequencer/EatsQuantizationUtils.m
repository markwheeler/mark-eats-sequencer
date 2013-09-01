//
//  EatsQuantizationUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 18/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsQuantizationUtils.h"

@implementation EatsQuantizationUtils

+ (NSArray *) stepQuantizationArrayWithMinimum:(uint)min andMaximum:(uint)max
{
    NSMutableArray *stepQuantizationArray = [NSMutableArray array];
    int quantizationSetting = min;
    while( quantizationSetting >= max ) {
        
        NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:quantizationSetting], @"quantization", nil];
        
        if( quantizationSetting == 1)
            [quantization setObject:[NSString stringWithFormat:@"1 bar"] forKey:@"label"];
        else
            [quantization setObject:[NSString stringWithFormat:@"1/%i", quantizationSetting] forKey:@"label"];
        
        [stepQuantizationArray insertObject:quantization atIndex:0];
        quantizationSetting = quantizationSetting / 2;
    }
    
    return stepQuantizationArray;
}

+ (NSArray *) patternQuantizationArrayWithMinimum:(uint)min andMaximum:(uint)max forGridWidth:(uint)gridWidth;
{
    NSMutableArray *patternQuantizationArray = [NSMutableArray array];
    int quantizationSetting = gridWidth;
    while ( quantizationSetting >= max ) {
        
        NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:quantizationSetting], @"quantization", nil];
        
        if( quantizationSetting == 1)
            [quantization setObject:[NSString stringWithFormat:@"1 loop"] forKey:@"label"];
        else
            [quantization setObject:[NSString stringWithFormat:@"1/%i", quantizationSetting] forKey:@"label"];
        
        [patternQuantizationArray insertObject:quantization atIndex:0];
        quantizationSetting = quantizationSetting / 2;
    }
    
    return patternQuantizationArray;
}

@end
