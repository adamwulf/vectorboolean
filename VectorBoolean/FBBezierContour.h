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

typedef enum FBContourInside {
    FBContourInsideFilled,
    FBContourInsideHole
} FBContourInside;

@interface FBBezierContour : NSObject<NSCopying> {
    NSMutableArray *_edges;
    NSRect _bounds;
    FBContourInside _inside;
}

- (void) addCurve:(FBBezierCurve *)curve;
- (void) addCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;
- (void) addReverseCurve:(FBBezierCurve *)curve;
- (void) addReverseCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;

- (BOOL) containsPoint:(NSPoint)point;

- (void) round;

@property (readonly) NSArray *edges;
@property (readonly) NSRect bounds;
@property (readonly) NSPoint testPoint;
@property (readonly) NSPoint firstPoint;
@property FBContourInside inside;
@property (readonly) NSArray *intersectingContours;

@end
