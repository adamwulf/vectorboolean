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
}

- (id) initWithBezierCurve:(FBBezierCurve *)curve contour:(FBBezierContour *)contour;

@property (readonly) FBBezierCurve *curve;

- (void) addCrossing:(FBEdgeCrossing *)crossing;

@end
