//
//  FBContourEdge.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBBezierCurve;
@class FBBezierContour;
@class FBEdgeCrossing;

@interface FBContourEdge : NSObject {
    FBBezierCurve *_curve;
    NSMutableArray *_crossings;
    FBBezierContour *_contour;
    NSUInteger _index;
    BOOL _startShared;
    BOOL _stopShared;
}

- (id) initWithBezierCurve:(FBBezierCurve *)curve contour:(FBBezierContour *)contour;

@property (readonly) FBBezierCurve *curve;
@property (readonly) NSArray *crossings;
@property (readonly, assign) FBBezierContour *contour;
@property NSUInteger index;
@property (readonly) FBContourEdge *next;
@property (readonly) FBContourEdge *previous;
@property (readonly) FBEdgeCrossing *firstCrossing;
@property (readonly) FBEdgeCrossing *lastCrossing;

@property (getter = isStartShared) BOOL startShared;
@property (getter = isStopShared) BOOL stopShared;

- (void) addCrossing:(FBEdgeCrossing *)crossing;
- (void) removeCrossing:(FBEdgeCrossing *)crossing;
- (void) removeAllCrossings;
- (void) round;

@end
