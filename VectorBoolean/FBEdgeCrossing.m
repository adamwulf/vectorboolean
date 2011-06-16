//
//  FBEdgeCrossing.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBEdgeCrossing.h"
#import "FBContourEdge.h"
#import "FBBezierCurve.h"
#import "FBBezierIntersection.h"

@implementation FBEdgeCrossing

@synthesize edge=_edge;
@synthesize counterpart=_counterpart;

+ (id) crossingWithIntersection:(FBBezierIntersection *)intersection
{
    return [[[FBEdgeCrossing alloc] initWithIntersection:intersection] autorelease];
}

- (id) initWithIntersection:(FBBezierIntersection *)intersection
{
    self = [super init];
    
    if ( self != nil ) {
        _intersection = [intersection retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_intersection release];
    
    [super dealloc];
}

- (CGFloat) order
{
    if ( self.edge.curve == _intersection.curve1 )
        return _intersection.parameter1;
    
    return _intersection.parameter2;
}

@end
