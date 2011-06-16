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

@interface FBEdgeCrossing : NSObject {
    FBBezierIntersection *_intersection;
    FBContourEdge *_edge;
    FBEdgeCrossing *_counterpart;
    BOOL _entry;
}

+ (id) crossingWithIntersection:(FBBezierIntersection *)intersection;
- (id) initWithIntersection:(FBBezierIntersection *)intersection;

@property (assign) FBContourEdge *edge;
@property (assign) FBEdgeCrossing *counterpart;
@property (readonly) CGFloat order;
@property (getter = isEntry) BOOL entry;

@end
