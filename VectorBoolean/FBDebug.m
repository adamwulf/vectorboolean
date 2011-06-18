//
//  FBDebug.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/17/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBDebug.h"

NSString *FBArrayDescription(NSArray *array)
{
    NSMutableString *description = [NSMutableString string];
    [description appendString:@"["];
    for (NSUInteger i = 0; i < [array count]; i++) {
        if ( i == 0 )
            [description appendString:@"\n"];
        [description appendFormat:@"\t%lu\t=\t%@\n", i, [array objectAtIndex:i]];
    }
    [description appendString:@"]"];
    return description;
}
