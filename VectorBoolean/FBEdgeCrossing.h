//
//  FBEdgeCrossing.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBBezierIntersection;
@class FBContourEdge;
@class FBBezierCurve;

// FBEdgeCrossing is used by the boolean operations code to hold data about
//  where two edges actually cross (as opposed to just intersect). The main
//  piece of data is the intersection, but it also holds a pointer to the
//  crossing's counterpart in the other FBBezierGraph
@interface FBEdgeCrossing : NSObject {
    FBBezierIntersection *_intersection;
    FBContourEdge *_edge;
    FBEdgeCrossing *_counterpart;
    BOOL _entry;
    BOOL _processed;
    NSUInteger _index;
}

+ (id) crossingWithIntersection:(FBBezierIntersection *)intersection;
- (id) initWithIntersection:(FBBezierIntersection *)intersection;

- (void) removeFromEdge;

@property (assign) FBContourEdge *edge;
@property (assign) FBEdgeCrossing *counterpart;
@property (readonly) CGFloat order;
@property (getter = isEntry) BOOL entry;
@property (getter = isProcessed) BOOL processed;
@property NSUInteger index;

// An easy way to iterate crossings. It doesn't wrap when it reaches the end.
@property (readonly) FBEdgeCrossing *next;
@property (readonly) FBEdgeCrossing *previous;

// These properties pass through to the underlying intersection
@property (readonly) CGFloat parameter;
@property (readonly) FBBezierCurve *curve;
@property (readonly) FBBezierCurve *leftCurve;
@property (readonly) FBBezierCurve *rightCurve;
@property (readonly, getter = isAtStart) BOOL atStart;
@property (readonly, getter = isAtEnd) BOOL atEnd;
@property (readonly) NSPoint location;

@end
