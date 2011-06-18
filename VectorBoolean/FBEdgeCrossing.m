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
@synthesize entry=_entry;
@synthesize processed=_processed;
@synthesize index=_index;

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
    return self.parameter;
}

- (FBEdgeCrossing *) next
{
    if ( _index >= ([self.edge.crossings count] - 1) )
        return nil;
    
    return [self.edge.crossings objectAtIndex:_index + 1];
}

- (FBEdgeCrossing *) previous
{
    if ( _index == 0 )
        return nil;
    
    return [self.edge.crossings objectAtIndex:_index - 1];
}

- (CGFloat) parameter
{
    if ( self.edge.curve == _intersection.curve1 )
        return _intersection.parameter1;
    
    return _intersection.parameter2;
}

- (FBBezierCurve *) curve
{
    return self.edge.curve;
}

- (FBBezierCurve *) leftCurve
{
    if ( self.edge.curve == _intersection.curve1 )
        return _intersection.curve1LeftBezier;
    
    return _intersection.curve2LeftBezier;
}

- (FBBezierCurve *) rightCurve
{
    if ( self.edge.curve == _intersection.curve1 )
        return _intersection.curve1RightBezier;
    
    return _intersection.curve2RightBezier;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: isEntry = %d, isProcessed = %d, intersection = %@>", 
            NSStringFromClass([self class]),
            (int)_entry,
            (int)_processed,
            [_intersection description]
            ];
}

@end
