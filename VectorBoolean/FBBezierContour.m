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
#import "FBEdgeCrossing.h"
#import "FBDebug.h"
#import "FBBezierIntersection.h"

@implementation FBBezierContour

@synthesize edges=_edges;
@synthesize inside=_inside;

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
    // Add the curve by wrapping it in an edge
    if ( curve == nil )
        return;
    FBContourEdge *edge = [[[FBContourEdge alloc] initWithBezierCurve:curve contour:self] autorelease];
    edge.index = [_edges count];
    [_edges addObject:edge];
    _bounds = NSZeroRect; // force the bounds to be recalculated
}

- (void) addCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing
{
    // First construct the curve that we're going to add, by seeing which crossing
    //  is nil. If the crossing isn't given go to the end of the edge on that side.
    FBBezierCurve *curve = nil;
    if ( startCrossing == nil && endCrossing != nil ) {
        // From start to endCrossing
        curve = endCrossing.leftCurve;
    } else if ( startCrossing != nil && endCrossing == nil ) {
        // From startCrossing to end
        curve = startCrossing.rightCurve;
    } else if ( startCrossing != nil && endCrossing != nil ) {
        // From startCrossing to endCrossing
        curve = [startCrossing.curve subcurveWithRange:FBRangeMake(startCrossing.parameter, endCrossing.parameter)];
    }
    [self addCurve:curve];
}

- (void) addReverseCurve:(FBBezierCurve *)curve
{
    // Just reverse the points on the curve. Need to do this to ensure the end point from one edge, matches the start
    //  on the next edge.
    if ( curve == nil )
        return;
    FBBezierCurve *reverseCurve = [FBBezierCurve bezierCurveWithEndPoint1:curve.endPoint2 controlPoint1:curve.controlPoint2 controlPoint2:curve.controlPoint1 endPoint2:curve.endPoint1];
    [self addCurve:reverseCurve];
}

- (void) addReverseCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing
{
    // First construct the curve that we're going to add, by seeing which crossing
    //  is nil. If the crossing isn't given go to the end of the edge on that side.
    FBBezierCurve *curve = nil;
    if ( startCrossing == nil && endCrossing != nil ) {
        // From start to endCrossing
        curve = endCrossing.leftCurve;
    } else if ( startCrossing != nil && endCrossing == nil ) {
        // From startCrossing to end
        curve = startCrossing.rightCurve;
    } else if ( startCrossing != nil && endCrossing != nil ) {
        // From startCrossing to endCrossing
        curve = [startCrossing.curve subcurveWithRange:FBRangeMake(startCrossing.parameter, endCrossing.parameter)];
    }
    [self addReverseCurve:curve];
}

- (NSRect) bounds
{
    // Cache the bounds to save time
    if ( !NSEqualRects(_bounds, NSZeroRect) )
        return _bounds;
    
    // If no edges, no bounds
    if ( [_edges count] == 0 )
        return NSZeroRect;
    
    // Start with the first point to set the topLeft and bottom right points
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

- (NSPoint) firstPoint
{
    if ( [_edges count] == 0 )
        return NSZeroPoint;

    FBContourEdge *edge = [_edges objectAtIndex:0];
    return edge.curve.endPoint1;
}

- (BOOL) containsPoint:(NSPoint)testPoint
{
    // Create a test line from our point to somewhere outside our graph. We'll see how many times the test
    //  line intersects edges of the graph. Based on the even/odd rule, if it's an odd number, we're inside
    //  the graph, if even, outside.
    NSPoint lineEndPoint = NSMakePoint(testPoint.x > NSMinX(self.bounds) ? NSMinX(self.bounds) - 10 : NSMaxX(self.bounds) + 10, testPoint.y); /* just move us outside the bounds of the graph */
    FBBezierCurve *testCurve = [FBBezierCurve bezierCurveWithLineStartPoint:testPoint endPoint:lineEndPoint];
    
    NSUInteger intersectCount = 0;
    for (FBContourEdge *edge in _edges) {
        NSArray *intersections = [testCurve intersectionsWithBezierCurve:edge.curve];
        for (FBBezierIntersection *intersection in intersections) {
            if ( intersection.isTangent )
                continue;
            intersectCount++;
        }
    }
    
    return (intersectCount % 2) == 1;
}

- (void) markCrossingsAsEntryOrExitWithContour:(FBBezierContour *)otherContour markInside:(BOOL)markInside
{
    // Go through and mark all the crossings with the given contour as "entry" or "exit". This 
    //  determines what part of ths contour is outputted. 
    
    // When marking we need to start at a point that is clearly either inside or outside
    //  the other graph, otherwise we could mark the crossings exactly opposite of what
    //  they're supposed to be.
    FBContourEdge *startEdge = [self.edges objectAtIndex:0];
    FBContourEdge *stopValue = startEdge;
    while ( startEdge.isStartShared ) {
        startEdge = startEdge.next;
        if ( startEdge == stopValue )
            break; // for safety. But if we're here, we could be hosed
    }
    
    // Calculate the first entry value. We need to determine if the edge we're starting
    //  on is inside or outside the otherContour.
    BOOL contains = [otherContour containsPoint:startEdge.curve.endPoint1];
    BOOL isEntry = markInside ? !contains : contains;
    
    // Walk all the edges in this contour and mark the crossings
    FBContourEdge *edge = startEdge;
    do {
        // Mark all the crossings on this edge
        for (FBEdgeCrossing *crossing in edge.crossings) {
            // skip over other contours
            if ( crossing.counterpart.edge.contour != otherContour )
                continue;
            crossing.entry = isEntry;
            isEntry = !isEntry; // toggle.
        }
        
        edge = edge.next;
    } while ( edge != startEdge );
}

- (void) round
{
    // Go through and round all the end points to integral value
    for (FBContourEdge *edge in _edges)
        [edge round];
}

- (NSArray *) intersectingContours
{
    // Go and find all the unique contours that intersect this specific contour
    NSMutableArray *contours = [NSMutableArray arrayWithCapacity:3];
    for (FBContourEdge *edge in _edges) {
        NSArray *intersectingEdges = edge.intersectingEdges;
        for (FBContourEdge *intersectingEdge in intersectingEdges) {
            if ( ![contours containsObject:intersectingEdge.contour] )
                [contours addObject:intersectingEdge.contour];
        }
    }
    return contours;
}

- (id)copyWithZone:(NSZone *)zone
{
    FBBezierContour *copy = [[FBBezierContour allocWithZone:zone] init];
    for (FBContourEdge *edge in _edges)
        [copy addCurve:edge.curve];
    return copy;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: bounds = (%f, %f)(%f, %f) edges = %@>", 
            NSStringFromClass([self class]),
            NSMinX(self.bounds), NSMinY(self.bounds),
            NSWidth(self.bounds), NSHeight(self.bounds),
            FBArrayDescription(_edges)
            ];
}
@end
