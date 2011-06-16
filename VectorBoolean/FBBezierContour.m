//
//  FBBezierContour.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierContour.h"
#import "FBBezierCurve.h"
#import "FBContourEdge.h"

@implementation FBBezierContour

@synthesize edges=_edges;

- (id)init
{
    self = [super init];
    if ( self != nil ) {
        _edges = [[NSMutableArray alloc] initWithCapacity:12];
    }
    
    return self;
}

- (void)dealloc
{
    [_edges release];
    
    [super dealloc];
}

- (void) addCurve:(FBBezierCurve *)curve
{
    [_edges addObject:[[[FBContourEdge alloc] initWithBezierCurve:curve contour:self] autorelease]];
    _bounds = NSZeroRect; // force the bounds to be recalculated
}

- (NSRect) bounds
{
    if ( !NSEqualRects(_bounds, NSZeroRect) )
        return _bounds;
    
    if ( [_edges count] == 0 )
        return NSZeroRect;
    
    // Start with the first point
    FBContourEdge *firstEdge = [_edges objectAtIndex:0];
    NSPoint topLeft = firstEdge.curve.endPoint1;
    NSPoint bottomRight = topLeft;
    
    // All the edges are connected, so only add on based on the second end point
    for (FBContourEdge *edge in _edges) {
        NSPoint point = edge.curve.endPoint2;
        if ( point.x < topLeft.x )
            topLeft.x = point.x;
        if ( point.x > bottomRight.x )
            bottomRight.x = point.x;
        if ( point.y < topLeft.y )
            topLeft.y = point.y;
        if ( point.y > bottomRight.y )
            bottomRight.y = point.y;
    }
    
    _bounds = NSMakeRect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);

    return _bounds;
}

@end
