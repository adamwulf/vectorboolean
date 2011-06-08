//
//  FBBezierIntersection.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FBBezierCurve;

@interface FBBezierIntersection : NSObject {
    NSPoint _location;
    FBBezierCurve *_curve1;
    CGFloat _parameter1;
    NSPoint _curve1ControlPoint1;
    NSPoint _curve1ControlPoint2;
    FBBezierCurve *_curve2;
    CGFloat _parameter2;
    NSPoint _curve2ControlPoint1;
    NSPoint _curve2ControlPoint2;
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
@property (readonly) NSPoint curve1ControlPoint1;
@property (readonly) NSPoint curve1ControlPoint2;
@property (readonly) NSPoint curve2ControlPoint1;
@property (readonly) NSPoint curve2ControlPoint2;

@end
