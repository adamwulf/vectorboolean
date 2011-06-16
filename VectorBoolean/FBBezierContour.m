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
}

@end
