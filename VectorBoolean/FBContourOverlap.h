//
//  FBContourOverlap.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 11/7/12.
//  Copyright (c) 2012 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBBezierContour, FBContourEdge, FBBezierIntersectRange;

@interface FBEdgeOverlap : NSObject {
    FBContourEdge *_edge1;
    FBContourEdge *_edge2;
    FBBezierIntersectRange *_range;
}

@end

@interface FBEdgeOverlapRun : NSObject {
    NSMutableArray *_overlaps;
}

- (BOOL) isCrossing;
- (void) addCrossings;

@end

@interface FBContourOverlap : NSObject {
    NSMutableArray *_runs;
}

+ (id) contourOverlap;

@property (readonly) NSArray *runs;
@property (readonly) FBBezierContour *contour1;
@property (readonly) FBBezierContour *contour2;

- (void) addOverlap:(FBBezierIntersectRange *)range forEdge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2;

- (void) reset;

- (BOOL) isComplete;

- (BOOL) isBetweenContour:(FBBezierContour *)contour1 andContour:(FBBezierContour *)contour2;

@end
