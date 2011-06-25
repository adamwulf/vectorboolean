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

@interface FBBezierContour ()

- (BOOL) testPoint:(NSPoint *)point onRay:(FBBezierCurve *)ray;

@end

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
    if ( curve == nil )
        return;
    FBContourEdge *edge = [[[FBContourEdge alloc] initWithBezierCurve:curve contour:self] autorelease];
    edge.index = [_edges count];
    [_edges addObject:edge];
    _bounds = NSZeroRect; // force the bounds to be recalculated
}

- (void) addCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing
{
    // First construct the curve
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
    if ( curve == nil )
        return;
    FBBezierCurve *reverseCurve = [FBBezierCurve bezierCurveWithEndPoint1:curve.endPoint2 controlPoint1:curve.controlPoint2 controlPoint2:curve.controlPoint1 endPoint2:curve.endPoint1];
    [self addCurve:reverseCurve];
}

- (void) addReverseCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing
{
    // First construct the curve
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

- (NSPoint) testPoint
{
    if ( [_edges count] == 0 )
        return NSZeroPoint;
    
    static const CGFloat FBRayOverlap = 10.0;
    
    NSUInteger count = MAX(ceilf(NSWidth(self.bounds)), ceilf(NSHeight(self.bounds)));
    for (NSUInteger fraction = 2; fraction <= count; fraction++) {
        CGFloat verticalSpacing = NSHeight(self.bounds) / (CGFloat)fraction;
        for (CGFloat y = NSMinY(self.bounds) + verticalSpacing; y <= NSMaxY(self.bounds); y += verticalSpacing) {
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(NSMinX(self.bounds) - FBRayOverlap, y) endPoint:NSMakePoint(NSMaxX(self.bounds) + FBRayOverlap, y)];
            NSPoint testPoint = NSZeroPoint;
            if ( [self testPoint:&testPoint onRay:ray] )
                return testPoint;
        }
        
        CGFloat horizontalSpacing = NSWidth(self.bounds) / (CGFloat)fraction;
        for (CGFloat x = NSMinX(self.bounds) + horizontalSpacing; x <= NSMaxX(self.bounds); x += horizontalSpacing) {
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(x, NSMinY(self.bounds) - FBRayOverlap) endPoint:NSMakePoint(x, NSMaxY(self.bounds) + FBRayOverlap)];
            NSPoint testPoint = NSZeroPoint;
            if ( [self testPoint:&testPoint onRay:ray] )
                return testPoint;            
        }
    }
    
    return NSZeroPoint; // we're hosed
}

- (BOOL) testPoint:(NSPoint *)point onRay:(FBBezierCurve *)ray
{
    static const CGFloat FBMinimumIntersectionDistance = 2.0;
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line

    // First, find all the intersections and sort them
    NSMutableArray *intersections = [NSMutableArray arrayWithCapacity:10];
    for (FBContourEdge *edge in _edges) 
        [intersections addObjectsFromArray:[ray intersectionsWithBezierCurve:edge.curve]];
    if ( [intersections count] < 2 )
        return NO;
    [intersections sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        FBBezierIntersection *intersection1 = obj1;
        FBBezierIntersection *intersection2 = obj2;
        if ( horizontalRay ) {
            if ( intersection1.location.x < intersection2.location.x )
                return NSOrderedAscending;
            else if ( intersection1.location.x > intersection2.location.x )
                return NSOrderedDescending;
            else
                return NSOrderedSame;
        }
        
        if ( intersection1.location.y < intersection2.location.y )
            return NSOrderedAscending;
        else if ( intersection1.location.y > intersection2.location.y )
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    
    // Walk the intersections looking for when the ray crosses inside of the contour
    for (NSUInteger i = 0; i < ([intersections count] - 1); i += 2) {
        // Between these two intersections is "inside" the contour
        FBBezierIntersection *firstIntersection = [intersections objectAtIndex:i];
        FBBezierIntersection *secondIntersection = [intersections objectAtIndex:i + 1];
        
        // We don't want a point on the edge, so make sure there is a minimum distance between them
        CGFloat distance = horizontalRay ? secondIntersection.location.x - firstIntersection.location.x : secondIntersection.location.y - firstIntersection.location.y;
        if ( distance < FBMinimumIntersectionDistance )
            continue;
        
        // We have a winner
        if ( horizontalRay )
            *point = NSMakePoint((secondIntersection.location.x + firstIntersection.location.x) / 2.0, firstIntersection.location.y);
        else
            *point = NSMakePoint(firstIntersection.location.x, (secondIntersection.location.y + firstIntersection.location.y) / 2.0);
        return YES;
    }
    
    return NO;
}

- (BOOL) containsPoint:(NSPoint)testPoint
{
    // Create a test line from our point to somewhere outside our graph. We'll see how many times the test
    //  line intersects edges of the graph. Based on the winding rule, if it's an odd number, we're inside
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


- (void) round
{
    for (FBContourEdge *edge in _edges)
        [edge round];
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
