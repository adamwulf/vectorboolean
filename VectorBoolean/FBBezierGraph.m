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
        value = atan2f(point.y, point.x);
    else if ( point.x < 0.0 ) {
        if ( point.y >= 0.0 )
            value = atan2f(point.y, point.x) + M_PI;
        else
            value = atan2f(point.y, point.x) - M_PI;
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

- (NSUInteger) numberOfCrossings;
- (void) removeDuplicateCrossings;
- (BOOL) doesEdge:(FBContourEdge *)edge1 crossEdge:(FBContourEdge *)edge2 atIntersection:(FBBezierIntersection *)intersection;
- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other;
- (BOOL) containsPoint:(NSPoint)point;
- (FBEdgeCrossing *) firstUnprocessedCrossing;
- (void) markCrossingsAsEntryOrExitWithBezierGraph:(FBBezierGraph *)otherGraph markInside:(BOOL)markInside;
- (FBBezierGraph *) bezierGraphFromIntersections;
- (void) removeCrossings;

- (void) addContour:(FBBezierContour *)contour;
- (void) addBezierGraph:(FBBezierGraph *)graph;
- (void) round;

@property (readonly) NSArray *contours;
@property (readonly) NSRect bounds;
@property (readonly) NSPoint testPoint;

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
    BOOL hasCrossings = [self insertCrossingsWithBezierGraph:graph];
    if ( !hasCrossings ) {
        // There are no crossings, which means one contains the other, or they're completely disjoint 
        BOOL subjectContainsClip = [self containsPoint:graph.testPoint];
        BOOL clipContainsSubject = [graph containsPoint:self.testPoint];
        
        // Clean up crossings so the graphs can be reused
        [self removeCrossings];
        [graph removeCrossings];
        
        if ( subjectContainsClip )
            return self; // union is the subject graph
        if ( clipContainsSubject )
            return graph; // union is the clip graph
        
        // Neither contains the other, which means we should just append them
        FBBezierGraph *result = [FBBezierGraph bezierGraph];
        [result addBezierGraph:self];
        [result addBezierGraph:graph];
        return result;
    }
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:NO];
    
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph
{
    BOOL hasCrossings = [self insertCrossingsWithBezierGraph:graph];
    if ( !hasCrossings ) {
        // There are no crossings, which means one contains the other, or they're completely disjoint 
        BOOL subjectContainsClip = [self containsPoint:graph.testPoint];
        BOOL clipContainsSubject = [graph containsPoint:self.testPoint];
        
        // Clean up crossings so the graphs can be reused
        [self removeCrossings];
        [graph removeCrossings];
        
        if ( subjectContainsClip )
            return graph; // intersection is the clip graph
        if ( clipContainsSubject )
            return self; // intersection is the subject (clip doesn't do anything)
        
        // Neither contains the other, which means the intersection is nil
        return [FBBezierGraph bezierGraph];
    }
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:YES];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph
{
    BOOL hasCrossings = [self insertCrossingsWithBezierGraph:graph];
    if ( !hasCrossings ) {
        // There are no crossings, which means one contains the other, or they're completely disjoint 
        BOOL subjectContainsClip = [self containsPoint:graph.testPoint];
        BOOL clipContainsSubject = [graph containsPoint:self.testPoint];
        
        // Clean up crossings so the graphs can be reused
        [self removeCrossings];
        [graph removeCrossings];
        
        if ( subjectContainsClip ) {
            // Clip punches a clean (non-intersecting) hole in subject
            FBBezierGraph *result = [FBBezierGraph bezierGraph];
            [result addBezierGraph:self];
            [result addBezierGraph:graph];
            return result;
        }
        
        if ( clipContainsSubject )
            // We're subtracting out everything
            return [FBBezierGraph bezierGraph];
        
        // No crossings, so nothing to subtract from subject
        return self;
    }
    
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round];
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
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

- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other
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

    return [self numberOfCrossings];
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

- (NSUInteger) numberOfCrossings
{
    NSUInteger count = 0;
    for (FBBezierContour *ourContour in self.contours)
        for (FBContourEdge *ourEdge in ourContour.edges)
            count += [ourEdge.crossings count];
    return count;
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

- (BOOL) containsPoint:(NSPoint)testPoint
{
    // Create a test line from our point to somewhere outside our graph. We'll see how many times the test
    //  line intersects edges of the graph. Based on the winding rule, if it's an odd number, we're inside
    //  the graph, if even, outside.
    NSPoint lineEndPoint = NSMakePoint(testPoint.x > NSMinX(self.bounds) ? NSMinX(self.bounds) - 10 : NSMaxX(self.bounds) + 10, testPoint.y); /* just move us outside the bounds of the graph */
    FBBezierCurve *testCurve = [FBBezierCurve bezierCurveWithLineStartPoint:testPoint endPoint:lineEndPoint];
    
    NSUInteger intersectCount = 0;
    for (FBBezierContour *contour in self.contours) {
        for (FBContourEdge *edge in contour.edges) {
            NSArray *intersections = [testCurve intersectionsWithBezierCurve:edge.curve];
            for (FBBezierIntersection *intersection in intersections) {
                if ( intersection.isTangent )
                    continue;
                intersectCount++;
            }
        }
    }
    
    return (intersectCount % 2) == 1;
}

- (void) markCrossingsAsEntryOrExitWithBezierGraph:(FBBezierGraph *)otherGraph markInside:(BOOL)markInside
{
    for (FBBezierContour *contour in _contours) {
        // When marking we need to start at a point that is clearly either inside or outside
        //  the other graph.
        FBContourEdge *startEdge = [contour.edges objectAtIndex:0];
        FBContourEdge *stopValue = startEdge;
        while ( startEdge.isStartShared ) {
            startEdge = startEdge.next;
            if ( startEdge == stopValue )
                break; // for safety
        }
        
        // Calculate the first entry value
        BOOL contains = [otherGraph containsPoint:startEdge.curve.endPoint1];
        BOOL isEntry = markInside ? !contains : contains;
        
        // Walk all the edges in this contour and mark the crossings
        FBContourEdge *edge = startEdge;
        do {
            // Mark all the crossings on this edge
            for (FBEdgeCrossing *crossing in edge.crossings) {
                crossing.entry = isEntry;
                isEntry = !isEntry; // toggle
            }

            edge = edge.next;
        } while ( edge != startEdge );        
    }
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

- (void) addBezierGraph:(FBBezierGraph *)graph
{
    for (FBBezierContour *contour in graph.contours)
        [self addContour:[[contour copy] autorelease]];
}

- (NSPoint) testPoint
{
    if ( [_contours count] == 0 )
        return NSZeroPoint;
    FBBezierContour *contour = [_contours objectAtIndex:0];
    return contour.testPoint;
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
