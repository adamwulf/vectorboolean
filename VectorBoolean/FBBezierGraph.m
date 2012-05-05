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

//////////////////////////////////////////////////////////////////////////
// Helper methods for angles
//
static const CGFloat FB2PI = 2.0 * M_PI;

// Normalize the angle between 0 and 2pi
static CGFloat NormalizeAngle(CGFloat value)
{
    while ( value < 0.0 )
        value += FB2PI;
    while ( value >= FB2PI )
        value -= FB2PI;
    return value;
}

// Compute the polar angle from the cartesian point
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

//////////////////////////////////////////////////////////////////////////
// Angle Range structure provides a simple way to store angle ranges
//  and determine if a specific angle falls within. 
//
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

//////////////////////////////////////////////////////////////////////////
// FBBezierGraph
//
// The main point of this class is to perform boolean operations. The algorithm
//  used here is a modified and expanded version of the algorithm presented
//  in "Efficient clipping of arbitrary polygons" by Günther Greiner and Kai Hormann.
//  http://www.inf.usi.ch/hormann/papers/Greiner.1998.ECO.pdf
//  That algorithm assumes polygons, not curves, and only considers one contour intersecting
//  one other contour. My algorithm uses bezier curves (not polygons) and handles
//  multiple contours intersecting other contours.
//

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
        // A bezier graph is made up of contours, which are closed paths of curves. Anytime we
        //  see a move to in the NSBezierPath, that's a new contour.
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
                    // [MO] skip degenerate line segments
                    if (!NSEqualPoints(element.point, lastPoint)) {
                        // Convert lines to bezier curves as well. Just set control point to be in the line formed
                        //  by the end points
                        [contour addCurve:[FBBezierCurve bezierCurveWithLineStartPoint:lastPoint endPoint:element.point]];
                        
                        lastPoint = element.point;
                    }
                    break;
                }
                    
                case NSCurveToBezierPathElement:
                    [contour addCurve:[FBBezierCurve bezierCurveWithEndPoint1:lastPoint controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1] endPoint2:element.point]];
                    
                    lastPoint = element.point;
                    break;
                    
                case NSClosePathBezierPathElement:
                    // [MO] attempt to close the bezier contour by
                    // mapping closepaths to equivalent lineto operations,
                    // though as with our NSLineToBezierPathElement processing,
                    // we check so as not to add degenerate line segments which 
                    // blow up the clipping code.
                    
                    if ([[contour edges] count]) {
                        FBContourEdge *firstEdge = [[contour edges] objectAtIndex:0];
                        NSPoint        firstPoint = [[firstEdge curve] endPoint1];
                        
                        // Skip degenerate line segments
                        if (!CGPointEqualToPoint(lastPoint, firstPoint)) {
                            [contour addCurve:[FBBezierCurve bezierCurveWithLineStartPoint:lastPoint endPoint:firstPoint]];
                        }
                    }
                    lastPoint = CGPointZero;
                    break;
            }
        }
        
        // Go through and mark each contour if its a hole or filled region
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

////////////////////////////////////////////////////////////////////////
// Boolean operations
//
// The three main boolean operations (union, intersect, difference) follow
//  much the same algorithm. First, the places where the two graphs cross 
//  (not just intersect) are marked on the graph with FBEdgeCrossing objects.
//  Next, we decide which sections of the two graphs should appear in the final
//  result. (There are only two kind of sections: those inside of the other graph,
//  and those outside.) We do this by walking all the crossings we created
//  and marking them as entering a section that should appear in the final result,
//  or as exiting the final result. We then walk all the crossings again, and
//  actually output the final result of the graphs that intersect.
//
//  The last part of each boolean operation deals with what do with contours
//  in each graph that don't intersect any other contours.
//
// The exclusive or boolean op is implemented in terms of union, intersect,
//  and difference. More specifically it subtracts the intersection of both
//  graphs from the union of both graphs.
//

- (FBBezierGraph *) unionWithBezierGraph:(FBBezierGraph *)graph
{
    // First insert FBEdgeCrossings into both graphs where the graphs
    //  cross.
    [self insertCrossingsWithBezierGraph:graph];
    
    // Handle the parts of the graphs that intersect first. Mark the parts
    //  of the graphs that are outside the other for the final result.
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:NO];

    // Walk the crossings and actually compute the final result for the intersecting parts
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round]; // decimal values make things messy, so round in case the result is used as input elsewhere, like XOR
    
    // Finally, process the contours that don't cross anything else. They're either
    //  completely contained in another contour, or disjoint.
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    // Since we're doing a union, assume all the non-crossing contours are in, and remove
    //  by exception when they're contained by another contour.
    NSMutableArray *finalNonintersectingContours = [[ourNonintersectingContours mutableCopy] autorelease];
    [finalNonintersectingContours addObjectsFromArray:theirNonintersectinContours];
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        // If the other graph contains our contour, it's redundant and we can just remove it
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( clipContainsSubject )
            [finalNonintersectingContours removeObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        // If we contain this contour, it's redundant and we can just remove it
        BOOL subjectContainsClip = [self containsContour:theirContour];
        if ( subjectContainsClip )
            [finalNonintersectingContours removeObject:theirContour];
    }

    // Append the final nonintersecting contours
    for (FBBezierContour *contour in finalNonintersectingContours)
        [result addContour:contour];
    
    // Clean up crossings so the graphs can be reused, e.g. XOR will reuse graphs.
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph
{
    // First insert FBEdgeCrossings into both graphs where the graphs cross.
    [self insertCrossingsWithBezierGraph:graph];
    
    // Handle the parts of the graphs that intersect first. Mark the parts
    //  of the graphs that are inside the other for the final result.
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:YES];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    // Walk the crossings and actually compute the final result for the intersecting parts
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round]; // decimal values make things messy, so round in case the result is used as input elsewhere, like XOR
    
    // Finally, process the contours that don't cross anything else. They're either
    //  completely contained in another contour, or disjoint.
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    // Since we're doing an intersect, assume that most of these non-crossing contours shouldn't be in
    //  the final result.
    NSMutableArray *finalNonintersectingContours = [NSMutableArray arrayWithCapacity:[ourNonintersectingContours count] + [theirNonintersectinContours count]];
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        // If their graph contains ourContour, then the two graphs intersect (logical AND) at ourContour, so
        //  add it to the final result.
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( clipContainsSubject )
            [finalNonintersectingContours addObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        // If we contain theirContour, then the two graphs intersect (logical AND) at theirContour,
        //  so add it to the final result.
        BOOL subjectContainsClip = [self containsContour:theirContour];
        if ( subjectContainsClip )
            [finalNonintersectingContours addObject:theirContour];
    }
    
    // Append the final nonintersecting contours
    for (FBBezierContour *contour in finalNonintersectingContours)
        [result addContour:contour];
    
    // Clean up crossings so the graphs can be reused, e.g. XOR will reuse graphs.
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph
{
    // First insert FBEdgeCrossings into both graphs where the graphs cross.
    [self insertCrossingsWithBezierGraph:graph];
    
    // Handle the parts of the graphs that intersect first. We're subtracting
    //  graph from outselves. Mark the outside parts of ourselves, and the inside
    //  parts of them for the final result.
    [self markCrossingsAsEntryOrExitWithBezierGraph:graph markInside:NO];
    [graph markCrossingsAsEntryOrExitWithBezierGraph:self markInside:YES];
    
    // Walk the crossings and actually compute the final result for the intersecting parts
    FBBezierGraph *result = [self bezierGraphFromIntersections];
    [result round]; // decimal values make things messy, so round in case the result is used as input elsewhere, like XOR
    
    // Finally, process the contours that don't cross anything else. They're either
    //  completely contained in another contour, or disjoint.
    NSArray *ourNonintersectingContours = [self nonintersectingContours];
    NSArray *theirNonintersectinContours = [graph nonintersectingContours];
    // We're doing an subtraction, so assume none of the contours should be in the final result
    NSMutableArray *finalNonintersectingContours = [NSMutableArray arrayWithCapacity:[ourNonintersectingContours count] + [theirNonintersectinContours count]];
    for (FBBezierContour *ourContour in ourNonintersectingContours) {
        // If ourContour isn't subtracted away (contained by) the other graph, it should stick around,
        //  so add it to our final result.
        BOOL clipContainsSubject = [graph containsContour:ourContour];
        if ( !clipContainsSubject )
            [finalNonintersectingContours addObject:ourContour];
    }
    for (FBBezierContour *theirContour in theirNonintersectinContours) {
        // If our graph contains theirContour, then add theirContour as a hole.
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
    // Walk each contour in ourself and mark the crossings with each intersecting contour as entering
    //  or exiting the final contour.
    for (FBBezierContour *contour in self.contours) {
        NSArray *intersectingContours = contour.intersectingContours;
        for (FBBezierContour *otherContour in intersectingContours) {
            // If the other contour is a hole, that's a special case where we flip marking inside/outside.
            //  For example, if we're doing a union, we'd normally mark the outside of contours. But
            //  if we're unioning with a hole, we want to cut into that hole so we mark the inside instead
            //  of outside.
            if ( otherContour.inside == FBContourInsideHole )
                [contour markCrossingsAsEntryOrExitWithContour:otherContour markInside:!markInside];
            else
                [contour markCrossingsAsEntryOrExitWithContour:otherContour markInside:markInside];
        }
    }
}

- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph
{
    // XOR is done by combing union (OR), intersect (AND) and difference. Specifically
    //  we compute the union of the two graphs, the intersect of them, then subtract
    //  the intersect from the union.
    // Note that we reuse the resulting graphs, which is why it is important that operations
    //  clean up any crossings when their done, otherwise they could interfere with subsequent
    //  operations.
    FBBezierGraph *allParts = [self unionWithBezierGraph:graph];
    FBBezierGraph *intersectingParts = [self intersectWithBezierGraph:graph];
    return [allParts differenceWithBezierGraph:intersectingParts];
}

- (NSBezierPath *) bezierPath
{
    // Convert this graph into a bezier path. This is straightforward, each contour
    //  starting with a move to and each subsequent edge being translated by doing
    //  a curve to.
    // Be sure to mark the winding rule as even odd, or interior contours (holes)
    //  won't get filled/left alone properly.
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
    // Round off all end and control points to integral values
    for (FBBezierContour *contour in _contours)
        [contour round];
}

- (void) insertCrossingsWithBezierGraph:(FBBezierGraph *)other
{
    // Find all intersections and, if they cross the other graph, create crossings for them, and insert
    //  them into each graph's edges.
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            for (FBBezierContour *theirContour in other.contours) {
                for (FBContourEdge *theirEdge in theirContour.edges) {
                    // Find all intersections between these two edges (curves)
                    NSArray *intersections = [ourEdge.curve intersectionsWithBezierCurve:theirEdge.curve];
                    for (FBBezierIntersection *intersection in intersections) {
                        // If this intersection happens at one of the ends of the edges, then mark
                        //  that on the edge. We do this here because not all intersections create
                        //  crossings, but we still need to know when the intersections fall on end points
                        //  later on in the algorithm.
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

                        // Add crossings to both graphs for this intersection, and point them at each other
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
 
    // Remove duplicate crossings that can happen at end points of edges
    [self removeDuplicateCrossings];
    [other removeDuplicateCrossings];
}

- (void) removeDuplicateCrossings
{
    // Find any duplicate crossings. These will happen at the endpoints of edges. 
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            NSArray *crossings = [[ourEdge.crossings copy] autorelease];
            for (FBEdgeCrossing *crossing in crossings) {
                if ( crossing.isAtStart && crossing.edge.previous.lastCrossing.isAtEnd ) {
                    // Found a duplicate. Remove this crossing and its counterpart
                    FBEdgeCrossing *counterpart = crossing.counterpart;
                    [crossing removeFromEdge];
                    [counterpart removeFromEdge];
                }
                if ( crossing.isAtEnd && crossing.edge.next.firstCrossing.isAtStart ) {
                    // Found a duplicate. Remove this crossing and its counterpart
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
    //  angles of edge1 split the angles of edge2 (i.e. they alternate when sorted), then the edges cross. If
    //  any of the angles are equal or if the angles group up, then the edges don't cross.
    
    // Calculate the four tangents: The two tangents moving away from the intersection point on edge1, the two tangents
    //  moving away from the intersection point on edge2.
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

    // Calculate angles for the tangents
    CGFloat edge1Angles[] = { PolarAngle(edge1Tangents[0]), PolarAngle(edge1Tangents[1]) };
    CGFloat edge2Angles[] = { PolarAngle(edge2Tangents[0]), PolarAngle(edge2Tangents[1]) };
    
    // Count how many times edge2 angles appear between the edge1 angles
    FBAngleRange range1 = FBAngleRangeMake(edge1Angles[0], edge1Angles[1]);
    NSUInteger rangeCount1 = 0;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[0]) )
        rangeCount1++;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[1]) )
        rangeCount1++;
    
    // Count how many times edge1 angles appear between the edge2 angles
    FBAngleRange range2 = FBAngleRangeMake(edge1Angles[1], edge1Angles[0]);
    NSUInteger rangeCount2 = 0;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[0]) )
        rangeCount2++;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[1]) )
        rangeCount2++;

    // If each pair of angles split the other two, then the edges cross.
    return rangeCount1 == 1 && rangeCount2 == 1;
}

- (NSRect) bounds
{
    // Compute the bounds of the graph by unioning together the bounds of the individual contours
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
    // Determine if this contour, which should reside in this graph, is a filled region or
    //  a hole. Determine this by casting a ray from one edges of the contour to the outside of
    //  the entire graph. Count how many times the ray intersects a contour in the graph. If it's
    //  an odd number, the test contour resides inside of filled region, meaning it must be a hole.
    //  Otherwise it's "outside" of the graph and creates a filled region.
    
    // Create the line from the first point in the contour to outside the graph
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
                if ( intersection.isTangent ) // don't count tangents
                    continue;
                intersectCount++;
            }
        }
    }

    return (intersectCount % 2) == 1 ? FBContourInsideHole : FBContourInsideFilled;
}


- (BOOL) containsContour:(FBBezierContour *)testContour
{
    // Determine if the test contour is inside a filled region of self or not. We do this by
    //  see which, if any, of our contours contains the test contour. If one does, we contain
    //  it only if the contour is filled (a hole would mean the test contour outside of us).
    FBBezierContour *container = [self containerForContour:testContour];
    return container != nil && container.inside == FBContourInsideFilled;
}

- (FBBezierContour *) containerForContour:(FBBezierContour *)testContour
{
    // Determine the container, if any, for the test contour. We do this by casting a ray from one end of the graph to the other,
    //  and recording the intersections before and after the test contour. If the ray intersects with a contour an odd number of 
    //  times on one side, we know it contains the test contour. After determine which contours contain the test contour, we simply
    //  pick the closest one to test contour.
    //
    // Things get a bit more complicated though. If contour shares and edge the test contour, then it can be impossible to determine
    //  whom contains whom. Or if we hit the test contour at a location where edges joint together (i.e. end points).
    //  For this reason, we sit in a loop passing both horizontal and vertical rays through the graph until we can eliminate the number
    //  of potentially enclosing contours down to 1 or 0. Most times the first ray will find the correct answer, but in some degenerate
    //  cases it will take a few iterations.
    
    static const CGFloat FBRayOverlap = 10.0;
    
    // In the beginning all our contours are possible containers for the test contour.
    NSMutableArray *containers = [[_contours mutableCopy] autorelease];
    
    // Each time through the loop we split the test contour into any increasing amount of pieces
    //  (halves, thirds, quarters, etc) and send a ray along the boundaries. In order to increase
    //  our changes of eliminate all but 1 of the contours, we do both horizontal and vertical rays.
    NSUInteger count = MAX(ceilf(NSWidth(testContour.bounds)), ceilf(NSHeight(testContour.bounds)));
    for (NSUInteger fraction = 2; fraction <= count; fraction++) {
        BOOL didEliminate = NO;
        
        // Send the horizontal rays through the test contour and (possibly) through parts of the graph
        CGFloat verticalSpacing = NSHeight(testContour.bounds) / (CGFloat)fraction;
        for (CGFloat y = NSMinY(testContour.bounds) + verticalSpacing; y < NSMaxY(testContour.bounds); y += verticalSpacing) {
            // Construct a line that will reach outside both ends of both the test contour and graph
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(MIN(NSMinX(self.bounds), NSMinX(testContour.bounds)) - FBRayOverlap, y) endPoint:NSMakePoint(MAX(NSMaxX(self.bounds), NSMaxX(testContour.bounds)) + FBRayOverlap, y)];
            // Eliminate any contours that aren't containers. It's possible for this method to fail, so check the return
            BOOL eliminated = [self eliminateContainers:containers thatDontContainContour:testContour usingRay:ray];
            if ( eliminated )
                didEliminate = YES;
        }

        // Send the vertical rays through the test contour and (possibly) through parts of the graph
        CGFloat horizontalSpacing = NSWidth(testContour.bounds) / (CGFloat)fraction;
        for (CGFloat x = NSMinX(testContour.bounds) + horizontalSpacing; x < NSMaxX(testContour.bounds); x += horizontalSpacing) {
            // Construct a line that will reach outside both ends of both the test contour and graph
            FBBezierCurve *ray = [FBBezierCurve bezierCurveWithLineStartPoint:NSMakePoint(x, MIN(NSMinY(self.bounds), NSMinY(testContour.bounds)) - FBRayOverlap) endPoint:NSMakePoint(x, MAX(NSMaxY(self.bounds), NSMaxY(testContour.bounds)) + FBRayOverlap)];
            // Eliminate any contours that aren't containers. It's possible for this method to fail, so check the return
            BOOL eliminated = [self eliminateContainers:containers thatDontContainContour:testContour usingRay:ray];
            if ( eliminated )
                didEliminate = YES;
        }
        
        // If we've eliminated all the contours, then nothing contains the test contour, and we're done
        if ( [containers count] == 0 )
            return nil;
        // We were able to eliminate someone, and we're down to one, so we're done. If the eliminateContainers: method
        //  failed, we can't make any assumptions about the contains, so just let it go again.
        if ( didEliminate && [containers count] == 1 )
            return [containers objectAtIndex:0];
    }

    // This is a curious case, because by now we've sent rays that went through every integral cordinate of the test contour.
    //  Despite that eliminateContainers: failed each time, meaning one container has a shared edge for each ray test. It is likely
    //  that contour is equal (the same) as the test contour. Return nil, because if it is equal, it doesn't contain.
    return nil;
}

- (BOOL) findBoundsOfContour:(FBBezierContour *)testContour onRay:(FBBezierCurve *)ray minimum:(NSPoint *)testMinimum maximum:(NSPoint *)testMaximum
{
    // Find the bounds of test contour that lie on ray. Simply intersect the ray with test contour. For a horizontal ray, the minimum is the point
    //  with the lowest x value, the maximum with the highest x value. For a vertical ray, use the high and low y values.
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    // First find all the intersections with the ray
    NSMutableArray *rayIntersections = [NSMutableArray arrayWithCapacity:9];
    for (FBContourEdge *edge in testContour.edges)
        [rayIntersections addObjectsFromArray:[ray intersectionsWithBezierCurve:edge.curve]];
    if ( [rayIntersections count] == 0 )
        return NO; // shouldn't happen
    
    // Next go through and find the lowest and highest
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
    // Find intersections where the ray intersects the possible containers, before the minimum point, or after the maximum point. Store these
    //  as FBEdgeCrossings in the out parameters.
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line

    // Walk through each possible container, one at a time and see where it intersects
    NSMutableArray *ambiguousCrossings = [NSMutableArray arrayWithCapacity:10];
    for (FBBezierContour *container in containers) {
        for (FBContourEdge *containerEdge in container.edges) {
            // See where the ray intersects this particular edge
            NSArray *intersections = [ray intersectionsWithBezierCurve:containerEdge.curve];
            for (FBBezierIntersection *intersection in intersections) {
                if ( intersection.isTangent )
                    continue; // tangents don't count
                
                // If the ray intersects one of the contours at a joint (end point), then we won't be able
                //  to make any accurate conclusions, so bail now, and say we failed.
                if ( intersection.isAtEndPointOfCurve2 )
                    return NO;
                
                // If the point likes inside the min and max bounds specified, just skip over it. We only want to remember
                //  the intersections that fall on or outside of the min and max.
                if ( horizontalRay && intersection.location.x < testMaximum.x && intersection.location.x > testMinimum.x )
                    continue;
                else if ( !horizontalRay && intersection.location.y < testMaximum.y && intersection.location.y > testMinimum.y )
                    continue;
                
                // Creat a crossing for it so we know what edge it is associated with. Don't insert it into a graph or anything though.
                FBEdgeCrossing *crossing = [FBEdgeCrossing crossingWithIntersection:intersection];
                crossing.edge = containerEdge;
                
                // Special case if the bounds are just a point, and this crossing is on that point. In that case
                //  it could fall on either side, and we'll need to do some special processing on it later. For now,
                //  remember it, and move on to the next intersection.
                if ( NSEqualPoints(testMaximum, testMinimum) && NSEqualPoints(testMaximum, intersection.location) ) {
                    [ambiguousCrossings addObject:crossing];
                    continue;
                }
                
                // This crossing falls outse the bounds, so add it to the appropriate array
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
    
    // Handle any intersects that are ambigious. i.e. the min and max are one point, and the intersection is on that point.
    for (FBEdgeCrossing *ambiguousCrossing in ambiguousCrossings) {
        // See how many times the given contour crosses on each side. Add the ambigious crossing to the side that has less,
        //  in hopes of balancing it out.
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
    // Count how many times a contour appears in a crossings array
    NSUInteger count = 0;
    for (FBEdgeCrossing *crossing in crossings) {
        if ( crossing.edge.contour == contour )
            count++;
    }
    return count;
}

- (NSArray *) minimumCrossings:(NSArray *)crossings onRay:(FBBezierCurve *)ray
{
    // Find the crossings with the minimum x or y values. If it's a horizontal ray
    //  pick the minimum x values, if vertical, minimum y values. It's possible
    //  to return more than one crossing if they share the minimum value.
    
    if ( [crossings count] == 0 )
        return [NSArray array];
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    // Start with the first crossing as the minimum value to compare all others with
    NSMutableArray *minimums = [NSMutableArray arrayWithCapacity:[crossings count]];
    FBEdgeCrossing *firstCrossing = [crossings objectAtIndex:0];
    NSPoint minimum = firstCrossing.location;
    for (FBEdgeCrossing *crossing in crossings) {
        // If the current value is less than the minimum, replace it. If it is equal
        //  to the minimum value, add it to the array.
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
    // Find the crossings with the maximum x or y values. If it's a horizontal ray
    //  pick the maximum x values, if vertical, maximum y values. It's possible
    //  to return more than one crossing if they share the maximum value.

    if ( [crossings count] == 0 )
        return [NSArray array];
    
    BOOL horizontalRay = ray.endPoint1.y == ray.endPoint2.y; // ray has to be a vertical or horizontal line
    
    // Start with the first crossing as the maximum value to compare all others with
    NSMutableArray *maximums = [NSMutableArray arrayWithCapacity:[crossings count]];
    FBEdgeCrossing *firstCrossing = [crossings objectAtIndex:0];
    NSPoint maximum = firstCrossing.location;
    for (FBEdgeCrossing *crossing in crossings) {
        // If the current value is greater than the maximum, replace it. If it is equal
        //  to the maximum value, add it to the array.
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
    // This method attempts to eliminate all or all but one of the containers that might contain test contour, using the ray specified.
    
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
    
    // Remove containers that appear an even number of times on either side, because by the even/odd rule
    //  they can't contain test contour.
    [self removeContoursThatDontContain:crossingsBeforeMinimum];
    [self removeContoursThatDontContain:crossingsAfterMaximum];
    
    // Find the container(s) that are the closest to the test contour, while still being outside it
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
    // Determine all the unique contours in the array of crossings
    NSMutableArray *contours = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBEdgeCrossing *crossing in crossings) {
        if ( ![contours containsObject:crossing.edge.contour] )
            [contours addObject:crossing.edge.contour];
    }
    return contours;
}

- (void) removeContourCrossings:(NSMutableArray *)crossings1 thatDontAppearIn:(NSMutableArray *)crossings2
{
    // If a contour appears in crossings1, but not crossings2, remove all the associated crossings from 
    //  crossings1.
    
    NSMutableArray *containersToRemove = [NSMutableArray arrayWithCapacity:[crossings1 count]];
    for (FBEdgeCrossing *crossingToTest in crossings1) {
        FBBezierContour *containerToTest = crossingToTest.edge.contour;
        // See if this contour exists in the other array
        BOOL existsInOther = NO;
        for (FBEdgeCrossing *crossing in crossings2) {
            if ( crossing.edge.contour == containerToTest ) {
                existsInOther = YES;
                break;
            }
        }
        // If it doesn't exist in our counterpart, mark it for death
        if ( !existsInOther )
            [containersToRemove addObject:containerToTest];
    }
    [self removeCrossings:crossings1 forContours:containersToRemove];
}

- (void) removeContoursThatDontContain:(NSMutableArray *)crossings
{
    // Remove contours that cross the ray an even number of times. By the even/odd rule this means
    //  they can't contain the test contour.
    NSMutableArray *containersToRemove = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBEdgeCrossing *crossingToTest in crossings) {
        // For this contour, count how many times it appears in the crossings array
        FBBezierContour *containerToTest = crossingToTest.edge.contour;
        NSUInteger count = 0;
        for (FBEdgeCrossing *crossing in crossings) {
            if ( crossing.edge.contour == containerToTest )
                count++;
        }
        // If it's not an odd number of times, it doesn't contain the test contour, so mark it for death
        if ( (count % 2) != 1 )
            [containersToRemove addObject:containerToTest];
    }
    [self removeCrossings:crossings forContours:containersToRemove];
}

- (void) removeCrossings:(NSMutableArray *)crossings forContours:(NSArray *)containersToRemove
{
    // A helper method that goes through and removes all the crossings that appear on the specified
    //  contours.
    
    // First walk through and identify which crossings to remove
    NSMutableArray *crossingsToRemove = [NSMutableArray arrayWithCapacity:[crossings count]];
    for (FBBezierContour *contour in containersToRemove) {
        for (FBEdgeCrossing *crossing in crossings) {
            if ( crossing.edge.contour == contour )
                [crossingsToRemove addObject:crossing];
        }
    }
    // Now walk through and remove the crossings
    for (FBEdgeCrossing *crossing in crossingsToRemove)
        [crossings removeObject:crossing];
}

- (FBEdgeCrossing *) firstUnprocessedCrossing
{
    // Find the first crossing in our graph that has yet to be processed by the bezierGraphFromIntersections
    //  method.
    
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
    // This method walks the current graph, starting at the crossings, and outputs the final contours
    //  of the parts of the graph that actually intersect. The general algorithm is: start an crossing
    //  we haven't seen before. If it's marked as entry, start outputing edges moving forward (i.e. using edge.next)
    //  until another crossing is hit. (If a crossing is marked as exit, start outputting edges move backwards, using
    //  edge.previous.) Once the next crossing is hit, switch to the crossing's counter part in the other graph,
    //  and process it in the same way. Continue this until we reach a crossing that's been processed.
    
    FBBezierGraph *result = [FBBezierGraph bezierGraph];
    
    // Find the first crossing to start one
    FBEdgeCrossing *crossing = [self firstUnprocessedCrossing];
    while ( crossing != nil ) {
        // This is the start of a contour, so create one
        FBBezierContour *contour = [[[FBBezierContour alloc] init] autorelease];
        [result addContour:contour];
        
        // Keep going until we run into a crossing we've seen before.
        while ( !crossing.isProcessed ) {
            crossing.processed = YES; // ...and we've just seen this one
            
            if ( crossing.isEntry ) {
                // Keep going to next until meet a crossing
                [contour addCurveFrom:crossing to:crossing.next];
                if ( crossing.next == nil ) {
                    // We hit the end of the edge without finding another crossing, so go find the next crossing
                    FBContourEdge *edge = crossing.edge.next;
                    while ( [edge.crossings count] == 0 ) {
                        // output this edge whole
                        [contour addCurve:edge.curve];
                        
                        edge = edge.next;
                    }
                    // We have an edge that has at least one crossing
                    crossing = edge.firstCrossing;
                    [contour addCurveFrom:nil to:crossing]; // add the curve up to the crossing
                } else
                    crossing = crossing.next; // this edge has a crossing, so just move to it
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
                    // We have an edge that has at least one edge
                    crossing = edge.lastCrossing;
                    [contour addReverseCurveFrom:crossing to:nil]; // add the curve up to the crossing
                } else
                    crossing = crossing.previous;
            }
            
            // Switch over to counterpart in the other graph
            crossing.processed = YES;
            crossing = crossing.counterpart;
        }
        
        // See if there's another contour that we need to handle
        crossing = [self firstUnprocessedCrossing];
    }
    
    return result;
}

- (void) removeCrossings
{
    // Crossings only make sense for the intersection between two specific graphs. In order for this
    //  graph to be usable in the future, remove all the crossings
    for (FBBezierContour *contour in _contours)
        for (FBContourEdge *edge in contour.edges)
            [edge removeAllCrossings];
}

- (void) addContour:(FBBezierContour *)contour
{
    // Add a contour to ouselves, and force the bounds to be recalculated
    [_contours addObject:contour];
    _bounds = NSZeroRect;
}

- (NSArray *) nonintersectingContours
{
    // Find all the contours that have no crossings on them.
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
