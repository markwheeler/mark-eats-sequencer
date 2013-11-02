//
//  EatsQuantizationUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 18/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsQuantizationUtils.h"

@implementation EatsQuantizationUtils

+ (NSArray *) stepQuantizationArray
{
    NSArray *quantizationValues = [NSArray arrayWithObjects:[NSNumber numberWithInt:64],
                                                            [NSNumber numberWithInt:48],
                                                            [NSNumber numberWithInt:32],
                                                            [NSNumber numberWithInt:24],
                                                            [NSNumber numberWithInt:16],
                                                            [NSNumber numberWithInt:12],
                                                            [NSNumber numberWithInt:8],
                                                            [NSNumber numberWithInt:6],
                                                            [NSNumber numberWithInt:4],
                                                            [NSNumber numberWithInt:3],
                                                            [NSNumber numberWithInt:2],
                                                            [NSNumber numberWithInt:1],
                                                            nil];
    
    NSMutableArray *stepQuantizationArray = [NSMutableArray array];
    
    for( NSNumber *quantizationValue in quantizationValues ) {
        
        NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:quantizationValue, @"quantization", nil];
        
        if( quantizationValue.intValue == 1)
            [quantization setObject:[NSString stringWithFormat:@"1 bar"] forKey:@"label"];
        else
            [quantization setObject:[NSString stringWithFormat:@"1/%@", quantizationValue] forKey:@"label"];
        
        [stepQuantizationArray insertObject:quantization atIndex:0];
    }
    
    return stepQuantizationArray;
}

+ (NSArray *) patternQuantizationArrayForGridWidth:(uint)gridWidth;
{
    NSArray *quantizationValues = [NSArray arrayWithObjects:[NSNumber numberWithInt:64],
                                                            [NSNumber numberWithInt:32],
                                                            [NSNumber numberWithInt:16],
                                                            [NSNumber numberWithInt:8],
                                                            [NSNumber numberWithInt:4],
                                                            [NSNumber numberWithInt:2],
                                                            [NSNumber numberWithInt:1],
                                                            nil];
    
    NSMutableArray *patternQuantizationArray = [NSMutableArray array];
    
    for( NSNumber *quantizationValue in quantizationValues ) {
        
        if( quantizationValue.intValue <= gridWidth ) {
            
            NSMutableDictionary *quantization = [NSMutableDictionary dictionaryWithObjectsAndKeys:quantizationValue, @"quantization", nil];
            
            if( quantizationValue.intValue == 1)
                [quantization setObject:[NSString stringWithFormat:@"1 loop"] forKey:@"label"];
            else
                [quantization setObject:[NSString stringWithFormat:@"1/%@", quantizationValue] forKey:@"label"];
            
            [patternQuantizationArray insertObject:quantization atIndex:0];
            
        }
    }
    
    return patternQuantizationArray;
}

@end
