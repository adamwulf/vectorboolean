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
}

@end
