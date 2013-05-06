//
//  FBBezierIntersectRange.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 11/6/12.
//  Copyright (c) 2012 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Geometry.h"

@class FBBezierCurve, FBBezierIntersection;

@interface FBBezierIntersectRange : NSObject {
    FBBezierCurve *_curve1;
    FBRange _parameterRange1;
    FBBezierCurve *_curve1LeftBezier;
    FBBezierCurve *_curve1MiddleBezier;
    FBBezierCurve *_curve1RightBezier;
    BOOL _needToComputeCurve1;
    
    FBBezierCurve *_curve2;
    FBRange _parameterRange2;
    BOOL _reversed;
    FBBezierCurve *_curve2LeftBezier;
    FBBezierCurve *_curve2MiddleBezier;
    FBBezierCurve *_curve2RightBezier;
    BOOL _needToComputeCurve2;
}

+ (id) intersectRangeWithCurve1:(FBBezierCurve *)curve1 parameterRange1:(FBRange)parameterRange1 curve2:(FBBezierCurve *)curve2 parameterRange2:(FBRange)parameterRange2 reversed:(BOOL)reversed;
- (id) initWithCurve1:(FBBezierCurve *)curve1 parameterRange1:(FBRange)parameterRange1 curve2:(FBBezierCurve *)curve2 parameterRange2:(FBRange)parameterRange2 reversed:(BOOL)reversed;

@property (readonly, retain) FBBezierCurve *curve1;
@property (readonly) FBRange parameterRange1;
@property (readonly) FBBezierCurve *curve1LeftBezier;
@property (readonly) FBBezierCurve *curve1RightBezier;

@property (readonly, retain) FBBezierCurve *curve2;
@property (readonly) FBRange parameterRange2;
@property (readonly) BOOL reversed;
@property (readonly) FBBezierCurve *curve2LeftBezier;
@property (readonly) FBBezierCurve *curve2RightBezier;

@property (readonly) FBBezierIntersection *middleIntersection;

@property (readonly, getter = isAtStartOfCurve1) BOOL atStartOfCurve1;
@property (readonly, getter = isAtStopOfCurve1) BOOL atStopOfCurve1;
@property (readonly, getter = isAtStartOfCurve2) BOOL atStartOfCurve2;
@property (readonly, getter = isAtStopOfCurve2) BOOL atStopOfCurve2;

@end
