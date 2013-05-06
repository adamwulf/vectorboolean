//
//  FBBezierContour.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBBezierCurve;
@class FBEdgeCrossing;
@class FBContourEdge;
@class FBContourOverlap;

typedef enum FBContourInside {
    FBContourInsideFilled,
    FBContourInsideHole
} FBContourInside;


typedef enum FBContourDirection
{
	FBContourClockwise,
	FBContourAntiClockwise
}
FBContourDirection;

// FBBezierContour represents a closed path of bezier curves (aka edges). Contours
//  can be filled or represent a hole in another contour.
@interface FBBezierContour : NSObject<NSCopying> {
    NSMutableArray*	_edges;
    NSRect			_bounds;
    FBContourInside _inside;
    NSMutableArray  *_overlaps;
	NSBezierPath*	_bezPathCache;	// GPC: added
}

+ (id) bezierContourWithCurve:(FBBezierCurve *)curve;

// Methods for building up the contour. The reverse forms flip points in the bezier curve before adding them
//  to the contour. The crossing to crossing methods assuming the crossings are on the same edge. One of
//  crossings can be nil, but not both.
- (void) addCurve:(FBBezierCurve *)curve;
- (void) addCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;
- (void) addReverseCurve:(FBBezierCurve *)curve;
- (void) addReverseCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;

- (NSArray *) intersectionsWithRay:(FBContourEdge *)testEdge;
- (NSUInteger) numberOfIntersectionsWithRay:(FBContourEdge *)testEdge;
- (BOOL) containsPoint:(NSPoint)point;
- (void) markCrossingsAsEntryOrExitWithContour:(FBBezierContour *)otherContour markInside:(BOOL)markInside;

- (NSBezierPath*)		bezierPath;		// GPC: added
- (void)				close;			// GPC: added

- (FBBezierContour*)	reversedContour;	// GPC: added
- (FBContourDirection)	direction;
- (FBBezierContour*)	contourMadeClockwiseIfNecessary;

- (void) addOverlap:(FBContourOverlap *)overlap;
- (void) removeAllOverlaps;
- (BOOL) isEquivalent:(FBBezierContour *)other;

@property (readonly) NSArray *edges;
@property (readonly) NSRect bounds;
@property (readonly) NSPoint firstPoint;
@property FBContourInside inside;
@property (readonly) NSArray *intersectingContours;


- (NSBezierPath*) debugPathForIntersectionType:(NSInteger) ti;

@end
