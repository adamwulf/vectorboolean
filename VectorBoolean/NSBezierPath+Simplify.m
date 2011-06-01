//
//  NSBezierPath+Simplify.m
//  VectorBrush
//
//  Created by Andrew Finnell on 5/27/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+Simplify.h"
#import "NSBezierPath+Utilities.h"
#import "Geometry.h"

// Implements the Ramer-Douglas-Peucker algorithm

@implementation NSBezierPath (Simplify)

- (NSBezierPath *) fb_simplify:(CGFloat)threshold
{
    if ( [self elementCount] <= 2 )
        return self;
    
    CGFloat maximumDistance = 0.0;
    NSUInteger maximumIndex = 0;
    
    // Find the point the furtherest away
    for (NSUInteger i = 1; i < ([self elementCount] - 1); i++) {
        CGFloat distance = FBDistancePointToLine([self fb_pointAtIndex:i], [self fb_pointAtIndex:0], [self fb_pointAtIndex:[self elementCount] - 1]);
        if ( distance > maximumDistance ) {
            maximumDistance = distance;
            maximumIndex = i;
        }
    }
    
    if ( maximumDistance >= threshold ) {
        // The distance is too great to simplify, so recurse
        NSBezierPath *results1 = [[self fb_subpathWithRange:NSMakeRange(0, maximumIndex + 1)] fb_simplify:threshold];
        NSBezierPath *results2 = [[self fb_subpathWithRange:NSMakeRange(maximumIndex, [self elementCount] - maximumIndex)] fb_simplify:threshold];
    
        [results1 fb_appendPath:[results2 fb_subpathWithRange:NSMakeRange(1, [results2 elementCount] - 1)]];
        return results1;
    } 
        
    // The greatest distance from our end points isn't that much, so we can simplify
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path fb_copyAttributesFrom:self];
    [path moveToPoint:[self fb_pointAtIndex:0]];
    [path lineToPoint:[self fb_pointAtIndex:[self elementCount] - 1]];
    return path;
}

@end
