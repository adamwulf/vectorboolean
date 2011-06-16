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

@interface FBBezierContour : NSObject {
    NSMutableArray *_edges;
    NSRect _bounds;
}

- (void) addCurve:(FBBezierCurve *)curve;
- (void) addCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;
- (void) addReverseCurve:(FBBezierCurve *)curve;
- (void) addReverseCurveFrom:(FBEdgeCrossing *)startCrossing to:(FBEdgeCrossing *)endCrossing;

@property (readonly) NSArray *edges;
@property (readonly) NSRect bounds;
@property (readonly) NSPoint firstPoint;

@end
