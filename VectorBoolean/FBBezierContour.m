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
#import "FBContourOverlap.h"
#import "FBDebug.h"
#import "Geometry.h"
#import "FBBezierIntersection.h"
#import "NSBezierPath+Utilities.h"

@interface FBBezierContour ()

- (FBContourEdge *) startEdge;
- (BOOL) contourAndSelfIntersectingContoursContainPoint:(NSPoint)point;
- (void) addSelfIntersectingContoursToArray:(NSMutableArray *)contours originalContour:(FBBezierContour *)originalContour;

@property (readonly) NSArray *selfIntersectingContours;

@end

@implementation FBBezierContour

@synthesize edges=_edges;
@synthesize inside=_inside;

+ (id) bezierContourWithCurve:(FBBezierCurve *)curve
{
    FBBezierContour *contour = [[[FBBezierContour alloc] init] autorelease];
    [contour addCurve:curve];
    return contour;
}

- (id)init
{
    self = [super init];
    if ( self != nil ) {
        _edges = [[NSMutableArray alloc] initWithCapacity:12];
        _overlaps = [[NSMutableArray alloc] initWithCapacity:12];
    }
    
    return self;
}

- (void)dealloc
{
    [_edges release];
    [_overlaps release];
    [_bezPathCache release];
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
	[_bezPathCache release];
	_bezPathCache = nil;
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

    [self addCurve:[curve reversedCurve]];
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
    
    NSRect totalBounds = NSZeroRect;    
    for (FBContourEdge *edge in _edges) {
        NSRect bounds = edge.curve.bounds;
        if ( NSEqualRects(totalBounds, NSZeroRect) )
            totalBounds = bounds;
        else
            totalBounds = FBUnionRect(totalBounds, bounds);
    }
    
    _bounds = totalBounds;

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
    FBBezierContour *testContour = [FBBezierContour bezierContourWithCurve:testCurve];
    FBContourEdge *testEdge = [testContour.edges objectAtIndex:0];
    
    NSUInteger intersectCount = [self numberOfIntersectionsWithRay:testEdge];
    return (intersectCount & 1) == 1;
}

- (NSUInteger) numberOfIntersectionsWithRay:(FBContourEdge *)testEdge
{
    return [[self intersectionsWithRay:testEdge] count];
}

- (NSArray *) intersectionsWithRay:(FBContourEdge *)testEdge
{
    FBBezierCurve *testCurve = testEdge.curve;
    NSMutableArray *allIntersections = [NSMutableArray array];
    
    // Count how many times we intersect with this particular contour
    for (FBContourEdge *edge in _edges) {
        // Check for intersections between our test ray and the rest of the bezier graph
        NSArray *intersections = [testCurve intersectionsWithBezierCurve:edge.curve];
        for (FBBezierIntersection *intersection in intersections) {
            // Make sure this is a proper crossing
            if ( ![testEdge crossesEdge:edge atIntersection:intersection] ) // don't count tangents
                continue;
            
            // Make sure we don't count the same intersection twice. This happens when the ray crosses at
            //  start or end of an edge.
            if ( intersection.isAtStartOfCurve2 && [allIntersections count] > 0 ) {
                FBBezierIntersection *previousIntersection = [allIntersections lastObject];
                FBContourEdge *previousEdge = edge.previous;
                if ( previousIntersection.isAtEndPointOfCurve2 && previousEdge.curve == previousIntersection.curve2 )
                    continue;
            } else if ( intersection.isAtEndPointOfCurve2 && [allIntersections count] > 0 ) {
                FBBezierIntersection *nextIntersection = [allIntersections objectAtIndex:0];
                FBContourEdge *nextEdge = edge.next;
                if ( nextIntersection.isAtStartOfCurve2 && nextEdge.curve == nextIntersection.curve2 )
                    continue;                
            }
            
            [allIntersections addObject:intersection];
        }            
    }
    return allIntersections;
}

- (FBContourEdge *) startEdge
{
    // When marking we need to start at a point that is clearly either inside or outside
    //  the other graph, otherwise we could mark the crossings exactly opposite of what
    //  they're supposed to be.
    if ( [self.edges count] == 0 )
        return nil;
    
    FBContourEdge *startEdge = [self.edges objectAtIndex:0];
    FBContourEdge *stopValue = startEdge;
    while ( startEdge.isStartShared ) {
        startEdge = startEdge.next;
        if ( startEdge == stopValue )
            break; // for safety. But if we're here, we could be hosed
    }
    return startEdge;
}

- (void) markCrossingsAsEntryOrExitWithContour:(FBBezierContour *)otherContour markInside:(BOOL)markInside
{
    // Go through and mark all the crossings with the given contour as "entry" or "exit". This 
    //  determines what part of ths contour is outputted. 
    
    // When marking we need to start at a point that is clearly either inside or outside
    //  the other graph, otherwise we could mark the crossings exactly opposite of what
    //  they're supposed to be.
    FBContourEdge *startEdge = [self startEdge];
    NSPoint startPoint = startEdge.curve.endPoint1;
        
    // Calculate the first entry value. We need to determine if the edge we're starting
    //  on is inside or outside the otherContour.
    BOOL contains = [otherContour contourAndSelfIntersectingContoursContainPoint:startPoint];
    BOOL isEntry = markInside ? !contains : contains;
    NSArray *otherContours = [otherContour.selfIntersectingContours arrayByAddingObject:otherContour];
    
    // Walk all the edges in this contour and mark the crossings
    FBContourEdge *edge = startEdge;
    do {
        // Mark all the crossings on this edge
        for (FBEdgeCrossing *crossing in edge.crossings) {
            // skip over other contours
            if ( crossing.isSelfCrossing || ![otherContours containsObject:crossing.counterpart.edge.contour] )
                continue;
            crossing.entry = isEntry;
            isEntry = !isEntry; // toggle.
        }
        
        edge = edge.next;
    } while ( edge != startEdge );
}

- (BOOL) contourAndSelfIntersectingContoursContainPoint:(NSPoint)point
{
    NSUInteger containerCount = 0;
    if ( [self containsPoint:point] )
        containerCount++;
    NSArray *intersectingContours = self.selfIntersectingContours;
    for (FBBezierContour *contour in intersectingContours) {
        if ( [contour containsPoint:point] )
            containerCount++;
    }
    return (containerCount & 1) != 0;
}

- (NSBezierPath*) bezierPath		// GPC: added
{
	if ( _bezPathCache == nil ) {
		NSBezierPath* path = [NSBezierPath bezierPath];
		BOOL firstPoint = YES;        
		
		for ( FBContourEdge *edge in self.edges ) {
			if ( firstPoint ) {
				[path moveToPoint:edge.curve.endPoint1];
				firstPoint = NO;
			}
			
			if ( edge.curve.isStraightLine )
				[path lineToPoint:edge.curve.endPoint2];
			else
				[path curveToPoint:edge.curve.endPoint2 controlPoint1:edge.curve.controlPoint1 controlPoint2:edge.curve.controlPoint2];
		}
		
		[path closePath];
		[path setWindingRule:NSEvenOddWindingRule];
		_bezPathCache = [path retain];
    }
	
    return _bezPathCache;
}


- (void) close
{
	// adds an element to connect first and last points on the contour
	if ( [_edges count] == 0 )
        return;
    
    FBContourEdge *first = [_edges objectAtIndex:0];
    FBContourEdge *last = [_edges lastObject];
    
    if ( !FBArePointsClose(first.curve.endPoint1, last.curve.endPoint2) )
        [self addCurve:[FBBezierCurve bezierCurveWithLineStartPoint:last.curve.endPoint2 endPoint:first.curve.endPoint1]];
}


- (FBBezierContour*) reversedContour	// GPC: added
{
	FBBezierContour *revContour = [[[self class] alloc] init];
	
	for ( FBContourEdge *edge in _edges )
		[revContour addReverseCurve:edge.curve];
	
	return [revContour autorelease];
}


- (FBContourDirection) direction
{
	NSPoint lastPoint = NSZeroPoint, currentPoint = NSZeroPoint;
	BOOL firstPoint = YES;
	CGFloat	a = 0.0;
	
	for ( FBContourEdge* edge in _edges ) {
		if ( firstPoint ) {
			lastPoint = edge.curve.endPoint1;
			firstPoint = NO;
		} else {
			currentPoint = edge.curve.endPoint2;
			a += ((lastPoint.x * currentPoint.y) - (currentPoint.x * lastPoint.y));
			lastPoint = currentPoint;
		}
	}

	return ( a >= 0 ) ? FBContourClockwise : FBContourAntiClockwise;
}


- (FBBezierContour *) contourMadeClockwiseIfNecessary
{
	FBContourDirection dir = [self direction];
	
	if( dir == FBContourClockwise )
		return self;
	
    return [self reversedContour];
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

- (NSArray *) selfIntersectingContours
{
    // Go and find all the unique contours that intersect this specific contour from our own graph
    NSMutableArray *contours = [NSMutableArray arrayWithCapacity:3];
    [self addSelfIntersectingContoursToArray:contours originalContour:self];
    return contours;
}

- (void) addSelfIntersectingContoursToArray:(NSMutableArray *)contours originalContour:(FBBezierContour *)originalContour
{
    for (FBContourEdge *edge in _edges) {
        NSArray *intersectingEdges = edge.selfIntersectingEdges;
        for (FBContourEdge *intersectingEdge in intersectingEdges) {
            if ( intersectingEdge.contour != originalContour && ![contours containsObject:intersectingEdge.contour] ) {
                [contours addObject:intersectingEdge.contour];
                [intersectingEdge.contour addSelfIntersectingContoursToArray:contours originalContour:originalContour];
            }
        }
    }
}

- (void) addOverlap:(FBContourOverlap *)overlap
{
    [_overlaps addObject:overlap];
}

- (void) removeAllOverlaps
{
    [_overlaps removeAllObjects];
}

- (BOOL) isEquivalent:(FBBezierContour *)other
{
    for (FBContourOverlap *overlap in _overlaps) {
        if ( [overlap isBetweenContour:self andContour:other] && [overlap isComplete] )
            return YES;
    }
    return NO;
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



- (NSBezierPath *) debugPathForIntersectionType:(NSInteger)itersectionType
{
	// returns a path consisting of small circles placed at the intersections that match <ti>
	// this allows the internal state of a contour to be rapidly visualized so that bugs with
	// boolean ops are easier to spot at a glance
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	for ( FBContourEdge* edge in _edges ) {
		for ( FBEdgeCrossing* crossing in [edge crossings] ) {
			switch ( itersectionType ) {
				default:	// match any
					break;
				
				case 1:		// looking for entries
					if ( !crossing.isEntry )
						continue;
					break;
					
				case 2:		// looking for exits
					if ( crossing.isEntry )
						continue;
					break;
			}
			
			// if the crossing is flagged as "entry", show a circle, otherwise a rectangle
			[path appendBezierPath:crossing.isEntry? [NSBezierPath circleAtPoint:crossing.location] : [NSBezierPath rectAtPoint:crossing.location]];
		}
	}
	
    // Add the start point and direction for marking
    FBContourEdge *startEdge = [self startEdge];
    NSPoint startEdgeTangent = FBNormalizePoint(FBSubtractPoint(startEdge.curve.controlPoint1, startEdge.curve.endPoint1));
    [path appendBezierPath:[NSBezierPath triangleAtPoint:startEdge.curve.endPoint1 direction:startEdgeTangent]];
    
	// add the contour's entire path to make it easy to see which one owns which crossings (these can be colour-coded when drawing the paths)
	[path appendBezierPath:[self bezierPath]];
	
	// if this countour is flagged as "inside", the debug path is shown dashed, otherwise solid
	if ( self.inside == FBContourInsideHole ) {
        CGFloat dashes[] = { 2, 3 };
		[path setLineDash:dashes count:2 phase:0];
    }
	
	return path;
}

@end
