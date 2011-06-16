//
//  FBContourEdge.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBContourEdge.h"


@implementation FBContourEdge

@synthesize curve=_curve;

- (id) initWithBezierCurve:(FBBezierCurve *)curve contour:(FBBezierContour *)contour
{
    self = [super init];
    
    if ( self != nil ) {
        _curve = [curve retain];
        _crossings = [[NSMutableArray alloc] initWithCapacity:4];
        _contour = contour; // no cyclical references
    }
    
    return self;
}

- (void)dealloc
{
    [_crossings release];
    [_curve release];
    
    [super dealloc];
}

@end
