//
//  InputMappingOutlineViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2014.
//  Copyright (c) 2014 Mark Eats. All rights reserved.
//

#import "InputMappingOutlineViewController.h"

@implementation InputMappingOutlineViewController

//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
//{
//    if( [[item valueForKeyPath:@"isLeaf"] boolValue] )
//        return YES;
//    else
//        return NO;
//}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if( [[item valueForKeyPath:@"isLeaf"] boolValue] ) { // TODO: And row has device set to something other than 'none'
        [cell setEnabled:YES];
        if( [cell class] == [NSPopUpButtonCell class] )
            [(NSPopUpButtonCell *)cell setTransparent:NO];
        
    } else {
        [cell setEnabled:NO];
        if( [cell class] == [NSPopUpButtonCell class] )
            [(NSPopUpButtonCell *)cell setTransparent:YES];
    }
    
}

@end
