//
//  FBBezierGraph.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierGraph.h"
#import "FBBezierCurve.h"
#import "NSBezierPath+Utilities.h"
#import "FBBezierContour.h"
#import "FBContourEdge.h"
#import "FBBezierIntersection.h"
#import "FBEdgeCrossing.h"
#import "FBDebug.h"
#import "Geometry.h"
#import <math.h>

static const CGFloat FB2PI = 2.0 * M_PI;

static CGFloat NormalizeAngle(CGFloat value)
{
    while ( value < 0.0 )
        value += FB2PI;
    while ( value >= FB2PI )
        value -= FB2PI;
    return value;
}

static CGFloat PolarAngle(NSPoint point)
{
    CGFloat value = 0.0;
    if ( point.x > 0.0 )
        value = atanf(point.y / point.x);
    else if ( point.x < 0.0 ) {
        if ( point.y >= 0.0 )
            value = atanf(point.y / point.x) + M_PI;
        else
            value = atanf(point.y / point.x) - M_PI;
    } else {
        if ( point.y > 0.0 )
            value =  M_PI_2;
        else if ( point.y < 0.0 )
            value =  -M_PI_2;
        else
            value = 0.0;
    }
    return NormalizeAngle(value);
}

typedef struct FBAngleRange {
    CGFloat minimum;
    CGFloat maximum;
} FBAngleRange;

static FBAngleRange FBAngleRangeMake(CGFloat minimum, CGFloat maximum)
{
    FBAngleRange range = { minimum, maximum };
    return range;
}

static BOOL FBAngleRangeContainsAngle(FBAngleRange range, CGFloat angle)
{
    if ( range.minimum <= range.maximum )
        return angle > range.minimum && angle < range.maximum;
    
    // The range wraps around 0. See if the angle falls in the first half
    if ( angle > range.minimum && angle <= FB2PI )
        return YES;
    
    return angle >= 0.0 && angle < range.maximum;
}

@interface FBBezierGraph ()

- (void) removeDuplicateCrossings;
- (BOOL) doesEdge:(FBContourEdge *)edge1 crossEdge:(FBContourEdge *)edge2 atIntersection:(FBBezierIntersection *)intersection;
- (void) insertCrossingsWithBezierGraph:(FBBezierGraph *)other;
- (FBEdgeCrossing *) firstUnprocessedCrossing;
- (void) markCrossingsAsEntryOrExitWithBezierGraph:(FBBezierGraph *)otherGraph markInside:(BOOL)markInside;
- (FBBezierGraph *) bezierGraphFromIntersections;
- (void) removeCrossings;

- (void) addContour:(FBBezierContour *)contour;
- (void) round;
- (FBContourInside) contourInsides:(FBBezierContour *)contour;

- (NSArray *) nonintersectingContours;
- (BOOL) containsContour:(FBBezierContour *)contour;
- (FBBezierContour *) containerForContour:(FBBezierContour *)testContour;
- (BOOL) eliminateContainers:(NSMutableArray *)containers thatDontContainContour:(FBBezierContour *)testContour usingRay:(FBBezierCurve *)ray;
- (BOOL) findBoundsOfContour:(FBBezierContour *)testContour onRay:(FBBezierCurve *)ray minimum:(NSPoint *)testMinimum maximum:(NSPoint *)testMaximum;
- (void) removeContoursThatDontContain:(NSMutableArray *)crossings;
- (BOOL) findCrossingsOnContainers:(NSArray *)containers onRay:(FBBezierCurve *)ray beforeMinimum:(NSPoint)testMinimum afterMaximum:(NSPoint)testMaximum crossingsBefore:(NSMutableArray *)crossingsBeforeMinimum crossingsAfter:(NSMutableArray *)crossingsAfterMaximum;
- (void) removeCrossings:(NSMutableArray *)crossings forContours:(NSArray *)containersToRemove;
- (void) removeContourCrossings:(NSMutableArray *)crossings1 thatDontAppearIn:(NSMutableArray *)crossings2;
- (NSArray *) minimumCrossings:(NSArray *)crossings onRay:(FBBezierCurve *)ray;
- (NSArray *) maximumCrossings:(NSArray *)crossings onRay:(FBBezierCurve *)ray;
- (NSArray *) contoursFromCrossings:(NSArray *)crossings;
- (NSUInteger) numberOfTimesContour:(FBBezierContour *)contour appearsInCrossings:(NSArray *)crossings;

@property (readonly) NSArray *contours;
@property (readonly) NSRect bounds;

@end

@implementation FBBezierGraph

@synthesize contours=_contours;

+ (id) bezierGraphWithBezierPath:(NSBezierPath *)path
{
    return [[[FBBezierGraph alloc] initWithBezierPath:path] autorelease];
}

+ (id) bezierGraph
{
    return [[[FBBezierGraph alloc] init] autorelease];
}

- (id) initWithBezierPath:(NSBezierPath *)path
{
    self = [super init];
    
    if ( self != nil ) {
        NSPoint lastPoint = NSZeroPoint;
        _contours = [[NSMutableArray alloc] initWithCapacity:2];
            
        FBBezierContour *contour = nil;
        for (NSUInteger i = 0; i < [path elementCount]; i++) {
            NSBezierElement element = [path fb_elementAtIndex:i];
            
            switch (element.kind) {
                case NSMoveToBezierPathElement:
                    // Start a new contour
                    contour = [[[FBBezierContour alloc] init] autorelease];
                    [self addContour:contour];
                    
                    lastPoint = element.point;
                    break;
                    
                case NSLineToBezierPathElement: {
                    // Convert lines to bezier curves as well. Just set control point to be in the line formed
                    //  by the end points
                    [contour addCurve:[FBBezierCurve bezierCurveWithLineStartPoint:lastPoint endPoint:element.point]];
                    
                    lastPoint = element.point;
                    break;
                }
                    
                case NSCurveToBezierPathElement:
                    [contour addCurve:[FBBezierCurve bezierCurveWithEndPoint1:lastPoint controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1] endPoint2:element.point]];
                    
                    lastPoint = element.point;
                    break;
                    
                case NSClosePathBezierPathElement:
                    lastPoint = NSZeroPoint;
                    break;
            }
        }
        
        for (contour in _contours)
            contour.inside = [self contourInsides:contour];
    }
    
    return self;
}

- (id) init
{
    self = [super init];
    
    if ( self != nil ) {
        _contours = [[NSMutableArray alloc] initWithCapacity:2];
    }
    
    return self;
}

- (void)dealloc
{
    [_contours release];
    
    [super dealloc];
}

- (FBBezierGraph *) unionWithBezierGraph:(FBBezierGraph *)graph
{
    [self insertCrossingsWithBezierGraph:graph];
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:NO];

    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    NSMutableArray *finalNonintersectingContours = [[ourNonintersectingContours mutableCopy] autorelease];
    [finalNonintersectingContours addObjectsFromArray:theirNonintersectinContours];
    // There are no crossings, which means one contains the other, or they're completely disjoint 
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( clipContainsSubject )
            [finalNonintersectingContours removeObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        BOOL subjectContainsClip = [self containsContour:theirContour];
        if ( subjectContainsClip )
            [finalNonintersectingContours removeObject:theirContour];
    }

    // Append the final nonintersecting contours
    for (FBBezierContour *contour in finalNonintersectingContours)
        [result addContour:contour];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph
{
    [self insertCrossingsWithBezierGraph:graph];
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:YES];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    NSMutableArray *finalNonintersectingContours = [NSMutableArray arrayWithCapacity:[ourNonintersectingContours count] + [theirNonintersectinContours count]];
    // There are no crossings, which means one contains the other, or they're completely disjoint 
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( clipContainsSubject )
            [finalNonintersectingContours addObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        BOOL subjectContainsClip = [self containsContour:theirContour];
        if ( subjectContainsClip )
            [finalNonintersectingContours addObject:theirContour];
    }
    
    // Append the final nonintersecting contours
    for (FBBezierContour *contour in finalNonintersectingContours)
        [result addContour:contour];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph
{
    [self insertCrossingsWithBezierGraph:graph];
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    NSMutableArray *finalNonintersectingContours = [NSMutableArray arrayWithCapacity:[ourNonintersectingContours count] + [theirNonintersectinContours count]];
    // There are no crossings, which means one contains the other, or they're completely disjoint 
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( !clipContainsSubject )
            [finalNonintersectingContours addObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        BOOL subjectContainsClip = [self containsContour:theirContour];
        if ( subjectContainsClip )
            [finalNonintersectingContours addObject:theirContour]; // add it as a hole
    }
    
    // Append the final nonintersecting contours
    for (FBBezierContour *contour in finalNonintersectingContours)
        [result addContour:contour];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;  
}

- (void) markCrossingsAsEntryOrExitWithBezierGraph:(FBBezierGraph *)otherGraph markInside:(BOOL)markInside
{
    for (FBBezierContour *contour in self.contours) {
        NSArray *intersectingContours = contour.intersectingContours;
        for (FBBezierContour *otherContour in intersectingContours) {
            if ( otherContour.inside == FBContourInsideHole )
                [contour markCrossingsAsEntryOrExitWithContour:otherContour markInside:!markInside];
            else
                [contour markCrossingsAsEntryOrExitWithContour:otherContour markInside:markInside];
        }
    }
}

- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph
{
    FBBezierGraph *allParts = [self unionWithBezierGraph:graph];
    FBBezierGraph *intersectingParts = [self intersectWithBezierGraph:graph];
    return [allParts differenceWithBezierGraph:intersectingParts];
}

- (NSBezierPath *) bezierPath
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setWindingRule:NSEvenOddWindingRule];

    for (FBBezierContour *contour in _contours) {
        BOOL firstPoint = YES;        
        for (FBContourEdge *edge in contour.edges) {
            if ( firstPoint ) {
                [path moveToPoint:edge.curve.endPoint1];
                firstPoint = NO;
            }
            
            [path curveToPoint:edge.curve.endPoint2 controlPoint1:edge.curve.controlPoint1 controlPoint2:edge.curve.controlPoint2];
        }
    }
    
    return path;
}

- (void) round
{
    for (FBBezierContour *contour in _contours)
        [contour round];
}

- (void) insertCrossingsWithBezierGraph:(FBBezierGraph *)other
{
    // Find all intersections and, if they cross the other graph, create crossings for them
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            for (FBBezierContour *theirContour in other.contours) {
                for (FBContourEdge *theirEdge in theirContour.edges) {
                    NSArray *intersections = [ourEdge.curve intersectionsWithBezierCurve:theirEdge.curve];
                    for (FBBezierIntersection *intersection in intersections) {
                        // Mark shared points
                        if ( intersection.isAtStartOfCurve1 ) {
                            ourEdge.startShared = YES;
                            ourEdge.previous.stopShared = YES;
                        } else if ( intersection.isAtStopOfCurve1 ) {
                            ourEdge.stopShared = YES;
                            ourEdge.next.startShared = YES;
                        }
                        if ( intersection.isAtStartOfCurve2 ) {
                            theirEdge.startShared = YES;
                            theirEdge.previous.stopShared = YES;
                        } else if ( intersection.isAtStopOfCurve2 ) {
                            theirEdge.stopShared = YES;
                            theirEdge.next.startShared = YES;
                        }

                        // Don't add a crossing unless one edge actually crosses the other
                        if ( ![self doesEdge:ourEdge crossEdge:theirEdge atIntersection:intersection] )
                            continue;

                        FBEdgeCrossing *ourCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];
                        FBEdgeCrossing *theirCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];

                        ourCrossing.counterpart = theirCrossing;
                        theirCrossing.counterpart = ourCrossing;
                        
                        [ourEdge addCrossing:ourCrossing];
                        [theirEdge addCrossing:theirCrossing];
                    }
                }
            }
            
        }
    }
 
    [self removeDuplicateCrossings];
    [other removeDuplicateCrossings];
}

- (void) removeDuplicateCrossings
{
    // Find any duplicate crossings. These will happen at the endpoints of edges
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            NSArray *crossings = [[ourEdge.crossings copy] autorelease];
            for (FBEdgeCrossing *crossing in crossings) {
                if ( crossing.isAtStart && crossing.edge.previous.lastCrossing.isAtEnd ) {
                    FBEdgeCrossing *counterpart = crossing.counterpart;
                    [crossing removeFromEdge];
                    [counterpart removeFromEdge];
                }
                if ( crossing.isAtEnd && crossing.edge.next.firstCrossing.isAtStart ) {
                    FBEdgeCrossing *counterpart = crossing.edge.next.firstCrossing.counterpart;
                    [crossing.edge.next.firstCrossing removeFromEdge];
                    [counterpart removeFromEdge];
                }
            }
        }
    }
}

- (BOOL) doesEdge:(FBContourEdge *)edge1 crossEdge:(FBContourEdge *)edge2 atIntersection:(FBBezierIntersection *)intersection
{
    // Handle the main case first
    if ( !intersection.isAtEndPointOfCurve )
        return YES;
    if ( intersection.isTangent )
        return NO;
    
    // The intersection happens at the end of one of the edges, meaning we'll have to look at the next
    //  edge in sequence to see if it crosses or not
    
    // Calculate the four tangents
    NSPoint edge1Tangents[] = { NSZeroPoint, NSZeroPoint };
    NSPoint edge2Tangents[] = { NSZeroPoint, NSZeroPoint };
    if ( intersection.isAtStartOfCurve1 ) {
        FBContourEdge *otherEdge1 = edge1.previous;
        edge1Tangents[0] = FBSubtractPoint(otherEdge1.curve.controlPoint2, otherEdge1.curve.endPoint2);
        edge1Tangents[1] = FBSubtractPoint(edge1.curve.controlPoint1, edge1.curve.endPoint1);
    } else if ( intersection.isAtStopOfCurve1 ) {
        FBContourEdge *otherEdge1 = edge1.next;
        edge1Tangents[0] = FBSubtractPoint(edge1.curve.controlPoint2, edge1.curve.endPoint2);
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

    // Calculate angles between the tangents
    CGFloat edge1Angles[] = { PolarAngle(edge1Tangents[0]), PolarAngle(edge1Tangents[1]) };
    CGFloat edge2Angles[] = { PolarAngle(edge2Tangents[0]), PolarAngle(edge2Tangents[1]) };
    
    // Count how many times edge2 angles are between edge1 angles
    FBAngleRange range1 = FBAngleRangeMake(edge1Angles[0], edge1Angles[1]);
    NSUInteger rangeCount1 = 0;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[0]) )
        rangeCount1++;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[1]) )
        rangeCount1++;
    
    FBAngleRange range2 = FBAngleRangeMake(edge1Angles[1], edge1Angles[0]);
    NSUInteger rangeCount2 = 0;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[0]) )
        rangeCount2++;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[1]) )
        rangeCount2++;

    return rangeCount1 == 1 && rangeCount2 == 1;
}

- (NSRect) bounds
{
    if ( !NSEqualRects(_bounds, NSZeroRect) )
        return _bounds;
    if ( [_contours count] == 0 )
        return NSZeroRect;
    
    for (FBBezierContour *contour in _contours)
        _bounds = NSUnionRect(_bounds, contour.bounds);
    
    return _bounds;
}

- (FBContourInside) contourInsides:(FBBezierContour *)testContour
{
    NSPoint testPoint = testContour.firstPoint;
    NSPoint lineEndPoint = NSMakePoint(testPoint.x > NSMinX(self.bounds) ? NSMinX(self.bounds) - 10 : NSMaxX(self.bounds) + 10, testPoint.y); /* just move us outside the bounds of the graph */
    FBBezierCurve *testCurve = [FBBezierCurve bezierCurveWithLineStartPoint:testPoint endPoint:lineEndPoint];

    NSUInteger intersectCount = 0;
    for (FBBezierContour *contour in self.contours) {
        if ( contour == testContour )
            continue; // don't test self intersections
        for (FBContourEdge *edge in contour.edges) {
            NSArray *intersections = [testCurve intersectionsWithBezierCurve:edge.curve];
            for (FBBezierIntersection *intersection in intersections) {
                if ( intersection.isTangent )
                    continue;
                intersectCount++;
            }
        }
    }

    return (intersectCount % 2) == 1 ? FBContourInsideHole : FBContourInsideFilled;
}

- (BOOL) containsContour:(FBBezierContour *)testContour
{
    FBBezierContour *container = [self containerForContour:testContour];
    return container != nil && container.inside == FBContourInsideFilled;
}

- (FBBezierContour *) containerForContour:(FBBezierContour *)testContour
{
    static const CGFloat FBRayOverlap = 10.0;
    
    NSMutableArray *containers = [[_contours mutableCopy] autorelease];
    
    NSUInteger count = MAX(ceilf(NSWidth(testContour.bounds)), ceilf(NSHeight(testContour.bounds)));
    for (NSUInteger fraction = 2; fraction <= count; fraction++) {
        BOOL didEliminate = NO;
        
        CGFloat verticalSpacing = NSHeight(testContour.bounds) / (CGFloat)fraction;
        for (CGFloat y = NSMinY(testContour.bounds) + verticalSpacing; y < NSMaxY(testContour.bounds); y += verticalSpacing) {
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(MIN(NSMinX(self.bounds), NSMinX(testContour.bounds)) - FBRayOverlap, y) endPoint:NSMakePoint(MAX(NSMaxX(self.bounds), NSMaxX(testContour.bounds)) + FBRayOverlap, y)];
            BOOL eliminated = [self eliminateContainers:containers thatDontContainContour:testContour usingRay:ray];
            if ( eliminated )
                didEliminate = YES;
        }
        
        CGFloat horizontalSpacing = NSWidth(testContour.bounds) / (CGFloat)fraction;
        for (CGFloat x = NSMinX(testContour.bounds) + horizontalSpacing; x < NSMaxX(testContour.bounds); x += horizontalSpacing) {
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(x, MIN(NSMinY(self.bounds), NSMinY(testContour.bounds)) - FBRayOverlap) endPoint:NSMakePoint(x, MAX(NSMaxY(self.bounds), NSMaxY(testContour.bounds)) + FBRayOverlap)];
            BOOL eliminated = [self eliminateContainers:containers thatDontContainContour:testContour usingRay:ray];
            if ( eliminated )
                didEliminate = YES;
        }
        
        if ( [containers count] == 0 )
            return nil;
        if ( didEliminate && [containers count] == 1 )
            return [containers objectAtIndex:0];
    }

    return nil;
}

- (BOOL) findBoundsOfContour:(FBBezierContour *)testContour onRay:(FBBezierCurve *)ray minimum:(NSPoint *)testMinimum maximum:(NSPoint *)testMaximum
{
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    // First determine the exterior bounds of testContour on the given ray
    NSMutableArray *rayIntersections = [NSMutableArray arrayWithCapacity:9];
    for (FBContourEdge *edge in testContour.edges)
        [rayIntersections addObjectsFromArray:[ray intersectionsWithBezierCurve:edge.curve]];
    if ( [rayIntersections count] == 0 )
        return NO; // shouldn't happen
    FBBezierIntersection *firstRayIntersection = [rayIntersections objectAtIndex:0];
    *testMinimum = firstRayIntersection.location;
    *testMaximum = *testMinimum;    
    for (FBBezierIntersection *intersection in rayIntersections) {
        if ( horizontalRay ) {
            if ( intersection.location.x < testMinimum->x )
                *testMinimum = intersection.location;
            if ( intersection.location.x > testMaximum->x )
                *testMaximum = intersection.location;
        } else {
            if ( intersection.location.y < testMinimum->y )
                *testMinimum = intersection.location;
            if ( intersection.location.y > testMaximum->y )
                *testMaximum = intersection.location;            
        }
    }
    return YES;
}

- (BOOL) findCrossingsOnContainers:(NSArray *)containers onRay:(FBBezierCurve *)ray beforeMinimum:(NSPoint)testMinimum afterMaximum:(NSPoint)testMaximum crossingsBefore:(NSMutableArray *)crossingsBeforeMinimum crossingsAfter:(NSMutableArray *)crossingsAfterMaximum
{
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line

    NSMutableArray *ambiguousCrossings = [NSMutableArray arrayWithCapacity:10];
    for (FBBezierContour *container in containers) {
        for (FBContourEdge *containerEdge in container.edges) {
            NSArray *intersections = [ray intersectionsWithBezierCurve:containerEdge.curve];
            for (FBBezierIntersection *intersection in intersections) {
                if ( intersection.isTangent )
                    continue;
                
                if ( intersection.isAtEndPointOfCurve2 )
                    return NO;
                
                // only examine those intersections outside of or on testContour
                if ( horizontalRay && intersection.location.x < testMaximum.x && intersection.location.x > testMinimum.x )
                    continue;
                else if ( !horizontalRay && intersection.location.y < testMaximum.y && intersection.location.y > testMinimum.y )
                    continue;
                
                FBEdgeCrossing *crossing = [FBEdgeCrossing crossingWithIntersection:intersection];
                crossing.edge = containerEdge;
                
                // Special case if the bounds are just a point, and this crossing is on that point
                if ( NSEqualPoints(testMaximum, testMinimum) && NSEqualPoints(testMaximum, intersection.location) ) {
                    [ambiguousCrossings addObject:crossing];
                    continue;
                }
                
                if ( horizontalRay && intersection.location.x <= testMinimum.x )
                    [crossingsBeforeMinimum addObject:crossing];
                else if ( !horizontalRay && intersection.location.y <= testMinimum.y )
                    [crossingsBeforeMinimum addObject:crossing];
                if ( horizontalRay && intersection.location.x >= testMaximum.x )
                    [crossingsAfterMaximum addObject:crossing];
                else if ( !horizontalRay && intersection.location.y >= testMaximum.y )
                    [crossingsAfterMaximum addObject:crossing];
            }
        }
    }
    
    for (FBEdgeCrossing *ambiguousCrossing in ambiguousCrossings) {
        NSUInteger numberOfTimesContourAppearsBefore = [self numberOfTimesContour:ambiguousCrossing.edge.contour appearsInCrossings:crossingsBeforeMinimum];
        NSUInteger numberOfTimesContourAppearsAfter = [self numberOfTimesContour:ambiguousCrossing.edge.contour appearsInCrossings:crossingsAfterMaximum];
        if ( numberOfTimesContourAppearsBefore < numberOfTimesContourAppearsAfter )
            [crossingsBeforeMinimum addObject:ambiguousCrossing];
        else
            [crossingsAfterMaximum addObject:ambiguousCrossing];            
    }
    
    return YES;
}

- (NSUInteger) numberOfTimesContour:(FBBezierContour *)contour appearsInCrossings:(NSArray *)crossings
{
    NSUInteger count = 0;
    for (FBEdgeCrossing *crossing in crossings) {
        if ( crossing.edge.contour == contour )
            count++;
    }
    return count;
}

- (NSArray *) minimumCrossings:(NSArray *)crossings onRay:(FBBezierCurve *)ray
{
    if ( [crossings count] == 0 )
        return [NSArray array];
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    NSMutableArray *minimums = [NSMutableArray arrayWithCapacity:[crossings count]];
    FBEdgeCrossing *firstCrossing = [crossings objectAtIndex:0];
    NSPoint minimum = firstCrossing.location;
    for (FBEdgeCrossing *crossing in crossings) {
        if ( horizontalRay ) {
            if ( crossing.location.x < minimum.x ) {
                minimum = crossing.location;
                [minimums removeAllObjects];
                [minimums addObject:crossing];
            } else if ( crossing.location.x == minimum.x ) 
                [minimums addObject:crossing];                
        } else {
            if ( crossing.location.y < minimum.y ) {
                minimum = crossing.location;
                [minimums removeAllObjects];
                [minimums addObject:crossing];
            } else if ( crossing.location.y == minimum.y ) 
                [minimums addObject:crossing];
        }
    }
    
    return minimums;
}

- (NSArray *) maximumCrossings:(NSArray *)crossings onRay:(FBBezierCurve *)ray
{
    if ( [crossings count] == 0 )
        return [NSArray array];
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    NSMutableArray *maximums = [NSMutableArray arrayWithCapacity:[crossings count]];
    FBEdgeCrossing *firstCrossing = [crossings objectAtIndex:0];
    NSPoint maximum = firstCrossing.location;
    for (FBEdgeCrossing *crossing in crossings) {
        if ( horizontalRay ) {
            if ( crossing.location.x > maximum.x ) {
                maximum = crossing.location;
                [maximums removeAllObjects];
                [maximums addObject:crossing];
            } else if ( crossing.location.x == maximum.x ) 
                [maximums addObject:crossing];                
        } else {
            if ( crossing.location.y > maximum.y ) {
                maximum = crossing.location;
                [maximums removeAllObjects];
                [maximums addObject:crossing];
            } else if ( crossing.location.y == maximum.y ) 
                [maximums addObject:crossing];
        }
    }
    
    return maximums;
}

- (BOOL) eliminateContainers:(NSMutableArray *)containers thatDontContainContour:(FBBezierContour *)testContour usingRay:(FBBezierCurve *)ray
{    
    // First determine the exterior bounds of testContour on the given ray
    NSPoint testMinimum = NSZeroPoint;
    NSPoint testMaximum = NSZeroPoint;    
    BOOL foundBounds = [self findBoundsOfContour:testContour onRay:ray minimum:&testMinimum maximum:&testMaximum];
    if ( !foundBounds)
        return NO;
    
    // Find all the containers on either side of the otherContour
    NSMutableArray *crossingsBeforeMinimum = [NSMutableArray arrayWithCapacity:[containers count]];
    NSMutableArray *crossingsAfterMaximum = [NSMutableArray arrayWithCapacity:[containers count]];
    BOOL foundCrossings = [self findCrossingsOnContainers:containers onRay:ray beforeMinimum:testMinimum afterMaximum:testMaximum crossingsBefore:crossingsBeforeMinimum crossingsAfter:crossingsAfterMaximum];
    if ( !foundCrossings )
        return NO;
    
    // Remove containers that appear an even number of times on either side
    [self removeContoursThatDontContain:crossingsBeforeMinimum];
    [self removeContoursThatDontContain:crossingsAfterMaximum];
    
    // Find the container(s) that are the closest
    [crossingsBeforeMinimum setArray:[self maximumCrossings:crossingsBeforeMinimum onRay:ray]];
    [crossingsAfterMaximum setArray:[self minimumCrossings:crossingsAfterMaximum onRay:ray]];
    
    // Remove containers that appear only on one side
    [self removeContourCrossings:crossingsBeforeMinimum thatDontAppearIn:crossingsAfterMaximum];
    [self removeContourCrossings:crossingsAfterMaximum thatDontAppearIn:crossingsBeforeMinimum];
    
    // Although crossingsBeforeMinimum and crossingsAfterMaximum contain different crossings, they should contain the same
    //  contours, so just pick one to pull the contours from
    [containers setArray:[self contoursFromCrossings:crossingsBeforeMinimum]];
    
    return YES;
}

- (NSArray *) contoursFromCrossings:(NSArray *)crossings
{
    NSMutableArray *contours = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBEdgeCrossing *crossing in crossings) {
        if ( ![contours containsObject:crossing.edge.contour] )
            [contours addObject:crossing.edge.contour];
    }
    return contours;
}

- (void) removeContourCrossings:(NSMutableArray *)crossings1 thatDontAppearIn:(NSMutableArray *)crossings2
{
    NSMutableArray *containersToRemove = [NSMutableArray arrayWithCapacity:[crossings1 count]];
    for (FBEdgeCrossing *crossingToTest in crossings1) {
        FBBezierContour *containerToTest = crossingToTest.edge.contour;
        BOOL existsInOther = NO;
        for (FBEdgeCrossing *crossing in crossings2) {
            if ( crossing.edge.contour == containerToTest ) {
                existsInOther = YES;
                break;
            }
        }
        if ( !existsInOther )
            [containersToRemove addObject:containerToTest];
    }
    [self removeCrossings:crossings1 forContours:containersToRemove];
}

- (void) removeContoursThatDontContain:(NSMutableArray *)crossings
{
    NSMutableArray *containersToRemove = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBEdgeCrossing *crossingToTest in crossings) {
        FBBezierContour *containerToTest = crossingToTest.edge.contour;
        NSUInteger count = 0;
        for (FBEdgeCrossing *crossing in crossings) {
            if ( crossing.edge.contour == containerToTest )
                count++;
        }
        if ( (count % 2) != 1 )
            [containersToRemove addObject:containerToTest];
    }
    [self removeCrossings:crossings forContours:containersToRemove];
}

- (void) removeCrossings:(NSMutableArray *)crossings forContours:(NSArray *)containersToRemove
{
    NSMutableArray *crossingsToRemove = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBBezierContour *contour in containersToRemove) {
        for (FBEdgeCrossing *crossing in crossings) {
            if ( crossing.edge.contour == contour )
                [crossingsToRemove addObject:crossing];
        }
    }
    for (FBEdgeCrossing *crossing in crossingsToRemove)
        [crossings removeObject:crossing];
}

- (FBEdgeCrossing *) firstUnprocessedCrossing
{
    for (FBBezierContour *contour in _contours) {
        for (FBContourEdge *edge in contour.edges) {
            for (FBEdgeCrossing *crossing in edge.crossings) {
               if ( !crossing.isProcessed )
                   return crossing;
            }
        }
    }
    return nil;
}

- (FBBezierGraph *) bezierGraphFromIntersections
{
    FBBezierGraph *result = [FBBezierGraph bezierGraph];
    
    FBEdgeCrossing *crossing = [self firstUnprocessedCrossing];
    while ( crossing != nil ) {
        
        // This is the start of a contour
        FBBezierContour *contour = [[[FBBezierContour alloc] init] autorelease];
        [result addContour:contour];
        
        // keep going until run into processed crossing
        while ( !crossing.isProcessed ) {
            crossing.processed = YES;
            
            if ( crossing.isEntry ) {
                // Keep going to next until meet a crossing
                [contour addCurveFrom:crossing to:crossing.next];
                if ( crossing.next == nil ) {
                    // we hit the end of the edge without finding another crossing, so go find the next crossing
                    FBContourEdge *edge = crossing.edge.next;
                    while ( [edge.crossings count] == 0 ) {
                        // output this edge whole
                        [contour addCurve:edge.curve];
                        
                        edge = edge.next;
                    }
                    // We have an edge that has at least one intersection
                    crossing = edge.firstCrossing;
                    [contour addCurveFrom:nil to:crossing];
                } else
                    crossing = crossing.next;
            } else {
                // Keep going to previous until meet a crossing
                [contour addReverseCurveFrom:crossing.previous to:crossing];
                if ( crossing.previous == nil ) {
                    // we hit the end of the edge without finding another crossing, so go find the previous crossing
                    FBContourEdge *edge = crossing.edge.previous;
                    while ( [edge.crossings count] == 0 ) {
                        // output this edge whole
                        [contour addReverseCurve:edge.curve];
                        
                        edge = edge.previous;
                    }
                    // We have an edge that has at least one intersection
                    crossing = edge.lastCrossing;
                    [contour addReverseCurveFrom:crossing to:nil];
                } else
                    crossing = crossing.previous;
            }
            
            // Switch over to counterpart
            crossing.processed = YES;
            crossing = crossing.counterpart;
        }
        
        // See if there's another contour
        crossing = [self firstUnprocessedCrossing];
    }
    
    return result;
}

- (void) removeCrossings
{
    for (FBBezierContour *contour in _contours)
        for (FBContourEdge *edge in contour.edges)
            [edge removeAllCrossings];
}

- (void) addContour:(FBBezierContour *)contour
{
    [_contours addObject:contour];
    _bounds = NSZeroRect;
}

- (NSArray *) nonintersectingContours
{
    NSMutableArray *contours = [NSMutableArray arrayWithCapacity:[_contours count]];
    for (FBBezierContour *contour in self.contours) {
        if ( [contour.intersectingContours count] == 0 )
            [contours addObject:contour];
    }
    return contours;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: bounds = (%f, %f)(%f, %f) contours = %@>", 
            NSStringFromClass([self class]), 
            NSMinX(self.bounds), NSMinY(self.bounds),
            NSWidth(self.bounds), NSHeight(self.bounds),
            FBArrayDescription(_contours)];
}

@end
