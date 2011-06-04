//
//  FBPolygon.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBPolygon.h"
#import "NSBezierPath+FitCurve.h"
#import "NSBezierPath+Utilities.h"
#import "FBPoint.h"
#import "Geometry.h"

inline static NSPoint ComputeNormal(NSPoint lineStart, NSPoint lineEnd)
{
    return FBNormalizePoint(NSMakePoint(-(lineEnd.y - lineStart.y), lineEnd.x - lineStart.x));
}

inline static BOOL LinesIntersect(NSPoint line1Start, NSPoint line1End, NSPoint line2Start, NSPoint line2End, NSPoint *intersectPoint, CGFloat *relativeDistance1, CGFloat *relativeDistance2)
{
    // Based on Cyrus-Beck line clipping algorithm described in Computer Graphics: Principles and Practice by Foley, van Dam, et al
    //  Chapter 3, pp 117-119
    
    // Assume the line formed by line1Start, line1End is represented by the parametric function
    //  P(t) = line1Start + (line1End - line1Start) * t
    // Where t ranges from [0..1], and P(0) == line1Start and P(1) == line1End
    //
    // Assume N is a unit vector perpendicular to (line2Start, line2End), i.e. its normal.
    //  If we create a line from line2Start (the "arbitrary point" described in the book) to the intersection
    //  of line1 and line2 (called P(t)), that line will be colinear to line2, and thus perpendicular to the normal 
    //  as well. Thus, we can say
    //
    //  normal * (P(t) - line2Start) = 0
    //
    //  We can think substitute in our original defintion of P(t) to get
    //
    //  normal * ((line1Start + (line1End - line1Start) * t) - line2Start) = 0
    //
    //  Simplify:
    //
    //  normal * (line1Start - line2Start) + normal * (line1End - line1Start) * t
    //
    //  Solve for t:
    //
    //  t = (normal * (line1Start - line2Start)) / -(normal * (line1End - line1Start))
    //
    //  After solving for t, we can plug it back into P(t) to calculate the intersection point
    //  of the two lines. However, if t is outside the range [0..1] then it's not on the line
    //  segment defined by line1, so there's no intersection.
    
    NSPoint normal = ComputeNormal(line2End, line2Start);
    CGFloat denominator = FBDotMultiplyPoint(normal, FBSubtractPoint(line1End, line1Start));
    
    // If the dot product of the normal and line1 is 0, that means they are perpendicular. We already know
    //  the normal is perpendicular to line2, so if they are both perpendicular to the normal, they are
    //  parallel, and don't intersect. Also, divide by zero is bad.
    if ( denominator == 0.0 )
        return NO;
    
    CGFloat t = FBDotMultiplyPoint(normal, FBSubtractPoint(line1Start, line2Start)) / -denominator;
    
    if ( t < 0.0 || t > 1.0 )
        return NO; // No intersection on the line1 segment we care about
    
    NSPoint intersectionPoint = FBAddPoint(line1Start, FBScalePoint(FBSubtractPoint(line1End, line1Start), t));
    
    // We know the intersectionPoint lies on the line segment (line1Start, line1End) because t is in the range
    //  [0..1]. But does it lie on the line segment (line2Start, line2End)? Do a simple bounds check.
    if ( intersectionPoint.x < MIN(line2Start.x, line2End.x) || intersectionPoint.x > MAX(line2Start.x, line2End.x) || intersectionPoint.y < MIN(line2Start.y, line2End.y) || intersectionPoint.y > MAX(line2Start.y, line2End.y) )
        return NO;
    
    // We have an intersection for sure now. Fill in the out parameters
    *intersectPoint = intersectionPoint;
    *relativeDistance1 = FBDistanceBetweenPoints(line1Start, intersectionPoint) / FBDistanceBetweenPoints(line1Start, line1End);
    *relativeDistance2 = FBDistanceBetweenPoints(line2Start, intersectionPoint) / FBDistanceBetweenPoints(line2Start, line2End);
    
    // TODO: handle "degenerate" cases where an endpoint lies directly on the other line segment
    
    return YES;
}

@interface FBPolygon ()

- (BOOL) insertIntersectionPointsWith:(FBPolygon *)otherPolygon;
- (void) markIntersectionPointsAsEntryOrExitWith:(FBPolygon *)otherPolygon;
- (BOOL) containsPoint:(NSPoint)point;
- (FBPoint *) findFirstUnprocessedIntersection;
- (FBPolygon *) createPolygonFromIntersections;
- (void) removeIntersectionPoints;

- (void) enumeratePointsWithBlock:(void (^)(FBPointList *pointList, FBPoint *point, BOOL *stop))block;
- (void) addPointList:(FBPointList *)pointList;

- (FBPoint *) firstPoint;

@end

@implementation FBPolygon

- (id)init
{
    self = [super init];
    if (self != nil) {
        _subpolygons = [[NSMutableArray alloc] initWithCapacity:2];
    }
    
    return self;
}

- (id) initWithBezierPath:(NSBezierPath *)bezier
{
    self = [self init];
    
    if ( self != nil ) {
        // Normally there will only be one point list. However if the polygon has a hole,
        //  or has been cut in half completely (from a previous operation, perhaps), then
        //  there will be multiple. We use move to ops as a flag that we're starting a new
        //  point list.
        FBPointList *pointList = nil;
        NSBezierPath *flatPath = [bezier bezierPathByFlatteningPath];
        for (NSUInteger i = 0; i < [flatPath elementCount]; i++) {
            NSBezierElement element = [flatPath fb_elementAtIndex:i];
            if ( element.kind == NSMoveToBezierPathElement ) {
                pointList = [[[FBPointList alloc] init] autorelease];
                [_subpolygons addObject:pointList];
            }
            
            if ( element.kind == NSMoveToBezierPathElement || element.kind == NSLineToBezierPathElement ) 
                [pointList addPoint:[[[FBPoint alloc] initWithLocation:element.point] autorelease]];
        }
        _bounds = [bezier bounds];
    }
    
    return self;
}


- (void)dealloc
{
    [_subpolygons release];
    
    [super dealloc];
}

- (void) addPointList:(FBPointList *)pointList
{
    [_subpolygons addObject:pointList];
    
    // Determine the bounds of the subpolygon, and union it to what we have
    __block NSPoint topLeft  = [pointList firstPoint].location;
    __block NSPoint bottomRight = topLeft;
    [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
        if ( point.location.x < topLeft.x )
            topLeft.x = point.location.x;
        if ( point.location.x > bottomRight.x )
            bottomRight.x = point.location.x;
        if ( point.location.y < topLeft.y )
            topLeft.y = point.location.y;
        if ( point.location.y > bottomRight.y )
            bottomRight.y = point.location.y;
    }];
    NSRect bounds = NSMakeRect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    _bounds = NSUnionRect(_bounds, bounds);
}

- (FBPoint *) firstPoint
{
    FBPointList *pointList = [_subpolygons objectAtIndex:0];
    return pointList.firstPoint;
}

- (FBPolygon *) unionWithPolygon:(FBPolygon *)polygon
{
    return self; // TODO: implement
    // TODO: if no intersection points, what can we say?
    // TODO: clean up intersection points so we can chain operations
}

- (FBPolygon *) intersectWithPolygon:(FBPolygon *)polygon
{
    BOOL hasIntersections = [self insertIntersectionPointsWith:polygon];
    if ( !hasIntersections ) {
        // There are no intersections, which means one contains the other, or they're completely disjoint 
        BOOL subjectContainsClip = [self containsPoint:[polygon firstPoint].location];
        BOOL clipContainsSubject = [polygon containsPoint:[self firstPoint].location];
        
        // Clean up intersection points so the polygons can be reused
        [self removeIntersectionPoints];
        [polygon removeIntersectionPoints];

        if ( subjectContainsClip )
            return polygon; // intersection is the clip polygon
        if ( clipContainsSubject )
            return self; // intersection is the subject (clip doesn't do anything)
        
        // Neither contains the other, which means the intersection is nil
        return [[[FBPolygon alloc] init] autorelease];
    }
    
    [self markIntersectionPointsAsEntryOrExitWith:polygon];
    [polygon markIntersectionPointsAsEntryOrExitWith:self];

    FBPolygon *result = [self createPolygonFromIntersections];
    
    // Clean up intersection points so the polygons can be reused
    [self removeIntersectionPoints];
    [polygon removeIntersectionPoints];
    
    return result; // TODO: implement
}

- (FBPolygon *) differenceWithPolygon:(FBPolygon *)polygon
{
    return self; // TODO: implement
    // TODO: if no intersection points, what can we say?
    // TODO: clean up intersection points so we can chain operations
}

- (FBPolygon *) xorWithPolygon:(FBPolygon *)polygon
{
    FBPolygon *allParts = [self unionWithPolygon:polygon];
    FBPolygon *intersectingParts = [self intersectWithPolygon:polygon];
    return [allParts differenceWithPolygon:intersectingParts];
}

- (void) enumeratePointsWithBlock:(void (^)(FBPointList *pointList, FBPoint *point, BOOL *stop))block
{
    __block BOOL shouldStop = NO;
    for (FBPointList *pointList in _subpolygons) {
        [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            block(pointList, point, &shouldStop);
            if ( shouldStop )
                *stop = YES;
        }];
        if ( shouldStop )
            break;
    }
}

- (BOOL) insertIntersectionPointsWith:(FBPolygon *)clipPolygon
{
    __block BOOL hasIntersections = NO;
    [self enumeratePointsWithBlock:^(FBPointList *subjectPointList, FBPoint *subjectPoint, BOOL *subjectStop) {
        // Skip over intersection points
        if ( subjectPoint.isIntersection )
            return;
        
        [clipPolygon enumeratePointsWithBlock:^(FBPointList *clipPointList, FBPoint *clipPoint, BOOL *stop) {
            // Skip over intersection points
            if ( clipPoint.isIntersection )
                return;
            
            // First determine if the two line segments intersect
            CGFloat subjectDistance = 0.0;
            CGFloat clipDistance = 0.0;
            NSPoint intersectLocation = NSZeroPoint;
            BOOL linesIntersect = subjectPoint.next != nil && clipPoint.next != nil && LinesIntersect(subjectPoint.location, subjectPoint.next.location, clipPoint.location, clipPoint.next.location, &intersectLocation, &subjectDistance, &clipDistance);
            
            // If the line segments don't intersect, we're done here
            if ( !linesIntersect )
                return; // continue
                
            // Create an intersection point for each polygon
            FBPoint *subjectIntersectPoint = [[[FBPoint alloc] initWithLocation:intersectLocation] autorelease];
            FBPoint *clipIntersectPoint = [[[FBPoint alloc] initWithLocation:intersectLocation] autorelease];
            subjectIntersectPoint.intersection = YES;
            subjectIntersectPoint.relativeDistance = subjectDistance;
            subjectIntersectPoint.neighbor = clipIntersectPoint;
            clipIntersectPoint.intersection = YES;
            clipIntersectPoint.relativeDistance = clipDistance;
            clipIntersectPoint.neighbor = subjectIntersectPoint;
            
            // Insert the intersect points in their proper place (will we immediately hit them next?)
            [subjectPointList insertPoint:subjectIntersectPoint after:subjectPoint];
            [clipPointList insertPoint:clipIntersectPoint after:clipPoint];
            hasIntersections = YES;
        }];
    }];
        
    return hasIntersections;
}

- (BOOL) containsPoint:(NSPoint)testPoint
{
    // Create a test line from our point to somewhere outside our polygon. We'll see how many times the test
    //  line intersects edges of the polygon. Based on the winding rule, if it's an odd number, we're inside
    //  the polygon, if even, outside.
    NSPoint lineEndPoint = NSMakePoint(testPoint.x > NSMinX(_bounds) ? NSMinX(_bounds) - 10 : NSMaxX(_bounds) + 10, testPoint.y); /* just move us outside the bounds of the polygon */
    __block NSUInteger intersectCount = 0;
    [self enumeratePointsWithBlock:^(FBPointList *pointList, FBPoint *point, BOOL *stop) {
        NSPoint intersectLocation = NSZeroPoint;
        CGFloat distance1 = 0.0;
        CGFloat distance2 = 0.0;
        if ( point.next != nil && LinesIntersect(point.location, point.next.location, lineEndPoint, testPoint, &intersectLocation, &distance1, &distance2) )
            intersectCount++;

    }];
    return (intersectCount % 2) == 1;
}

- (void) markIntersectionPointsAsEntryOrExitWith:(FBPolygon *)otherPolygon
{
    for (FBPointList *pointList in _subpolygons) {
        __block FBPoint *firstPoint = nil;
        __block BOOL isEntry = NO;
        [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            // Handle the first point special case
            if ( firstPoint == nil ) {
                firstPoint = point;
                isEntry = ![otherPolygon containsPoint:firstPoint.location];
            }
            
            if ( point.isIntersection ) {
                point.entry = isEntry;
                isEntry = !isEntry; // toggle
            }
        }];
    }
}

- (FBPoint *) findFirstUnprocessedIntersection
{
    __block FBPoint *unprocessedPoint = nil;
    [self enumeratePointsWithBlock:^(FBPointList *pointList, FBPoint *point, BOOL *stop) {
        if ( point.isIntersection && !point.isVisited ) {
            unprocessedPoint = point;
            *stop = YES;
        }
    }];
    return unprocessedPoint;
}

- (FBPolygon *) createPolygonFromIntersections
{
    FBPolygon *polygon = [[[FBPolygon alloc] init] autorelease];
    
    FBPoint *firstPoint = [self findFirstUnprocessedIntersection];
    while (firstPoint != nil) {
        // Create a point list for this part of the polygon
        FBPointList *pointList = [[[FBPointList alloc]  init] autorelease];
        
        // First point is by definition and intersection point, so add it straight up
        FBPoint *currentPoint = firstPoint;
        [pointList addPoint:[[[FBPoint alloc] initWithLocation:currentPoint.location] autorelease]];
        currentPoint.visited = YES;
        
        do {
            if ( currentPoint.isEntry ) {
                do {
                    currentPoint = currentPoint.next != nil ? currentPoint.next : currentPoint.container.firstPoint;
                    if ( currentPoint.isVisited )
                        break;
                    [pointList addPoint:[[[FBPoint alloc] initWithLocation:currentPoint.location] autorelease]];
                    currentPoint.visited = YES;
                } while ( currentPoint != nil && !currentPoint.isIntersection );
            } else {
                do {
                    currentPoint = currentPoint.previous != nil ? currentPoint.previous : currentPoint.container.lastPoint;
                    if ( currentPoint.isVisited )
                        break;
                    [pointList addPoint:[[[FBPoint alloc] initWithLocation:currentPoint.location] autorelease]];
                    currentPoint.visited = YES;
                } while ( currentPoint != nil && !currentPoint.isIntersection );
            }
            currentPoint = currentPoint.neighbor;
        } while (currentPoint != nil && !currentPoint.isVisited);
        
        // Add this subpolygon
        [polygon addPointList:pointList];

        // Find the next intersection
        firstPoint = [self findFirstUnprocessedIntersection];
    }
    
    return polygon;    
}

- (void) removeIntersectionPoints
{
    for (FBPointList *pointList in _subpolygons)
        [pointList removeIntersectionPoints];
}

- (NSBezierPath *) bezierPath
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    for (FBPointList *pointList in _subpolygons) {
        __block BOOL firstPoint = YES;
        NSBezierPath *polygonPath = [NSBezierPath bezierPath];
        [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            if ( firstPoint ) {
                [polygonPath moveToPoint:point.location];
                firstPoint = NO;
            } else
                [polygonPath lineToPoint:point.location];
        }];
        
        [path appendBezierPath:[polygonPath fb_fitCurve:4 cornerAngleThreshold:M_PI / 6.0]];
    }
    
    return path;
}

@end
