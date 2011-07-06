//
//  FBBezierIntersection.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FBBezierCurve;

// FBBezierIntersection stores where two bezier curves intersect. Initially it just stores
//  the curves and the parameter values where they intersect. It can lazily compute
//  the 2D point where they intersect, the left and right parts of the curves relative to
//  the intersection point, if the intersection is tangent. 
@interface FBBezierIntersection : NSObject {
    NSPoint _location;
    FBBezierCurve *_curve1;
    CGFloat _parameter1;
    FBBezierCurve *_curve1LeftBezier;
    FBBezierCurve *_curve1RightBezier;
    FBBezierCurve *_curve2;
    CGFloat _parameter2;
    FBBezierCurve *_curve2LeftBezier;
    FBBezierCurve *_curve2RightBezier;    
    BOOL _tangent;
    BOOL _needToComputeCurve1;
    BOOL _needToComputeCurve2;
}

+ (id) intersectionWithCurve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2;
- (id) initWithCurve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2;

@property (readonly) NSPoint location;
@property (readonly, retain) FBBezierCurve *curve1;
@property (readonly) CGFloat parameter1;
@property (readonly, retain) FBBezierCurve *curve2;
@property (readonly) CGFloat parameter2;
@property (readonly, getter = isTangent) BOOL tangent;
@property (readonly) FBBezierCurve *curve1LeftBezier;
@property (readonly) FBBezierCurve *curve1RightBezier;
@property (readonly) FBBezierCurve *curve2LeftBezier;
@property (readonly) FBBezierCurve *curve2RightBezier;

// Intersections at the end points of curves have to be handled carefully, so here
//  are some convience methods to determine if that's the case.
@property (readonly, getter = isAtStartOfCurve1) BOOL atStartOfCurve1;
@property (readonly, getter = isAtStopOfCurve1) BOOL atStopOfCurve1;
@property (readonly, getter = isAtStartOfCurve2) BOOL atStartOfCurve2;
@property (readonly, getter = isAtStopOfCurve2) BOOL atStopOfCurve2;

@property (readonly, getter = isAtEndPointOfCurve1) BOOL atEndPointOfCurve1;
@property (readonly, getter = isAtEndPointOfCurve2) BOOL atEndPointOfCurve2;
@property (readonly, getter = isAtEndPointOfCurve) BOOL atEndPointOfCurve;

@end
