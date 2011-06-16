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

@interface FBBezierGraph ()

- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other;
- (BOOL) containsPoint:(NSPoint)point;
- (FBEdgeCrossing *) firstUnprocessedCrossing;
- (void) markCrossingsAsEntryOrExitWithBezierGraph:(FBBezierGraph *)otherGraph markInside:(BOOL)markInside;
- (FBBezierGraph *) bezierGraphFromIntersections;
- (void) removeCrossings;

- (void) addContour:(FBBezierContour *)contour;
- (void) addBezierGraph:(FBBezierGraph *)graph;

@property (readonly) NSArray *contours;
@property (readonly) NSRect bounds;
@property (readonly) NSPoint firstPoint;

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
        BOOL subjectContainsClip = [self containsPoint:graph.firstPoint];
        BOOL clipContainsSubject = [graph containsPoint:self.firstPoint];
        
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
        BOOL subjectContainsClip = [self containsPoint:graph.firstPoint];
        BOOL clipContainsSubject = [graph containsPoint:self.firstPoint];
        
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
    
    // Clean up crossings so the graphs can be reused
    [self removeCrossings];
    [graph removeCrossings];
    
    return result;
}

- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
}

- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
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

- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other
{
    BOOL hasIntersection = NO;
    
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            for (FBBezierContour *theirContour in other.contours) {
                for (FBContourEdge *theirEdge in theirContour.edges) {
                    NSArray *intersections = [ourEdge.curve intersectionsWithBezierCurve:theirEdge.curve];
                    for (FBBezierIntersection *intersection in intersections) {
                        // Don't insert tangents since we don't want to split on them
                        if ( intersection.isTangent )
                            continue;
                        
                        FBEdgeCrossing *ourCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];
                        FBEdgeCrossing *theirCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];

                        ourCrossing.counterpart = theirCrossing;
                        theirCrossing.counterpart = ourCrossing;
                        
                        [ourEdge addCrossing:ourCrossing];
                        [theirEdge addCrossing:theirCrossing];
                        
                        hasIntersection = YES;
                    }
                }
            }
            
        }
    }
 
    return hasIntersection;
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
        FBContourEdge *firstEdge = nil;
        BOOL isEntry = NO;
        for (FBContourEdge *edge in contour.edges) {
            // Handle the first edge special case
            if ( firstEdge == nil ) {
                firstEdge = edge;
                BOOL contains = [otherGraph containsPoint:firstEdge.curve.endPoint1];
                isEntry = markInside ? !contains : contains;
            }
            
            // Mark all the crossings on this edge
            for (FBEdgeCrossing *crossing in edge.crossings) {
                crossing.entry = isEntry;
                isEntry = !isEntry; // toggle
            }
        }
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

- (NSPoint) firstPoint
{
    if ( [_contours count] == 0 )
        return NSZeroPoint;
    FBBezierContour *contour = [_contours objectAtIndex:0];
    return contour.firstPoint;
}
@end
