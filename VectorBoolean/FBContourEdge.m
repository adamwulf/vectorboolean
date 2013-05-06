//
//  FBContourEdge.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBContourEdge.h"
#import "FBEdgeCrossing.h"
#import "FBBezierContour.h"
#import "FBBezierIntersection.h"
#import "FBBezierCurve.h"
#import "Geometry.h"
#import "FBDebug.h"


@interface FBContourEdge ()

- (void) sortCrossings;

@end

@implementation FBContourEdge

@synthesize curve=_curve;
@synthesize crossings=_crossings;
@synthesize index=_index;
@synthesize contour=_contour;
@synthesize startShared=_startShared;

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

- (void) addCrossing:(FBEdgeCrossing *)crossing
{
    // Make sure the crossing can make it back to us, and keep all the crossings sorted
    crossing.edge = self;
    [_crossings addObject:crossing];
    [self sortCrossings];
}

- (void) removeCrossing:(FBEdgeCrossing *)crossing
{
    // Keep the crossings sorted
    crossing.edge = nil;
    [_crossings removeObject:crossing];
    [self sortCrossings];
}

- (void) sortCrossings
{
    // Sort by the "order" of the crossing, then assign indices so next and previous work correctly.
    [_crossings sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        FBEdgeCrossing *crossing1 = obj1;
        FBEdgeCrossing *crossing2 = obj2;
        if ( crossing1.order < crossing2.order )
            return NSOrderedAscending;
        else if ( crossing1.order > crossing2.order )
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSUInteger index = 0;
    for (FBEdgeCrossing *crossing in _crossings)
        crossing.index = index++;
}

- (void) removeAllCrossings
{
    [_crossings removeAllObjects];
}

- (FBContourEdge *)next
{
    if ( _index >= ([self.contour.edges count] - 1) )
        return [self.contour.edges objectAtIndex:0];
    
    return [self.contour.edges objectAtIndex:_index + 1];
}

- (FBContourEdge *)previous
{
    if ( _index == 0 )
        return [self.contour.edges objectAtIndex:[self.contour.edges count] - 1];
    
    return [self.contour.edges objectAtIndex:_index - 1];
}

- (NSArray *) intersectingEdges
{
    NSMutableArray *edges = [NSMutableArray arrayWithCapacity:[_crossings count]];
    for (FBEdgeCrossing *crossing in _crossings) {
        if ( crossing.isSelfCrossing )
            continue; // Right now skip over self intersecting crossings
        FBContourEdge *intersectingEdge = crossing.counterpart.edge;
        if ( ![edges containsObject:intersectingEdge] )
            [edges addObject:intersectingEdge];
    }
    return edges;
}

- (NSArray *) selfIntersectingEdges
{
    NSMutableArray *edges = [NSMutableArray arrayWithCapacity:[_crossings count]];
    for (FBEdgeCrossing *crossing in _crossings) {
        if ( !crossing.isSelfCrossing )
            continue; // Only want the self intersecting crossings
        FBContourEdge *intersectingEdge = crossing.counterpart.edge;
        if ( ![edges containsObject:intersectingEdge] )
            [edges addObject:intersectingEdge];
    }
    return edges;
}

- (FBEdgeCrossing *) firstCrossing
{
    if ( [_crossings count] == 0 )
        return nil;
    return [_crossings objectAtIndex:0];
}

- (FBEdgeCrossing *) lastCrossing
{
    if ( [_crossings count] == 0 )
        return nil;
    return [_crossings objectAtIndex:[_crossings count] - 1];    
}

- (BOOL) crossesEdge:(FBContourEdge *)edge2 atIntersection:(FBBezierIntersection *)intersection
{
    // If it's tangent, then it doesn't cross
    if ( intersection.isTangent ) 
        return NO;
    // If the intersect happens in the middle of both curves, then it definitely crosses, so we can just return yes. Most
    //  intersections will fall into this category.
    if ( !intersection.isAtEndPointOfCurve )
        return YES;
    
    // The intersection happens at the end of one of the edges, meaning we'll have to look at the next
    //  edge in sequence to see if it crosses or not. We'll do that by computing the four tangents at the exact
    //  point the intersection takes place. We'll compute the polar angle for each of the tangents. If the
    //  angles of self split the angles of edge2 (i.e. they alternate when sorted), then the edges cross. If
    //  any of the angles are equal or if the angles group up, then the edges don't cross.
    
    // Calculate the four tangents: The two tangents moving away from the intersection point on self, the two tangents
    //  moving away from the intersection point on edge2.
    NSPoint edge1Tangents[] = { NSZeroPoint, NSZeroPoint };
    NSPoint edge2Tangents[] = { NSZeroPoint, NSZeroPoint };
    if ( intersection.isAtStartOfCurve1 ) {
        FBContourEdge *otherEdge1 = self.previous;
        edge1Tangents[0] = FBSubtractPoint(otherEdge1.curve.controlPoint2, otherEdge1.curve.endPoint2);
        edge1Tangents[1] = FBSubtractPoint(self.curve.controlPoint1, self.curve.endPoint1);
    } else if ( intersection.isAtStopOfCurve1 ) {
        FBContourEdge *otherEdge1 = self.next;
        edge1Tangents[0] = FBSubtractPoint(self.curve.controlPoint2, self.curve.endPoint2);
        edge1Tangents[1] = FBSubtractPoint(otherEdge1.curve.controlPoint1, otherEdge1.curve.endPoint1);
    } else {
        edge1Tangents[0] = FBSubtractPoint(intersection.curve1LeftBezier.controlPoint2, intersection.curve1LeftBezier.endPoint2);
        edge1Tangents[1] = FBSubtractPoint(intersection.curve1RightBezier.controlPoint1, intersection.curve1RightBezier.endPoint1);
    }
    if ( intersection.isAtStartOfCurve2 ) {
        FBContourEdge *otherEdge2 = edge2.previous;
        edge2Tangents[0] = FBSubtractPoint(otherEdge2.curve.controlPoint2, otherEdge2.curve.endPoint2);
        edge2Tangents[1] = FBSubtractPoint(edge2.curve.controlPoint1, edge2.curve.endPoint1);
    } else if ( intersection.isAtStopOfCurve2 ) {
        FBContourEdge *otherEdge2 = edge2.next;
        edge2Tangents[0] = FBSubtractPoint(edge2.curve.controlPoint2, edge2.curve.endPoint2);
        edge2Tangents[1] = FBSubtractPoint(otherEdge2.curve.controlPoint1, otherEdge2.curve.endPoint1);
    } else {
        edge2Tangents[0] = FBSubtractPoint(intersection.curve2LeftBezier.controlPoint2, intersection.curve2LeftBezier.endPoint2);
        edge2Tangents[1] = FBSubtractPoint(intersection.curve2RightBezier.controlPoint1, intersection.curve2RightBezier.endPoint1);
    }
    
    return FBTangentsCross(edge1Tangents, edge2Tangents);
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: curve = %@ crossings = %@>", NSStringFromClass([self class]), [_curve description], FBArrayDescription(_crossings)];
}

@end
