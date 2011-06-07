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
}

+ (id) intersectionWithLocation:(NSPoint)location curve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve1ControlPoint1:(NSPoint)curve1ControlPoint1 curve1ControlPoint2:(NSPoint)curve1ControlPoint2 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2 curve2ControlPoint1:(NSPoint)curve2ControlPoint1 curve2ControlPoint2:(NSPoint)curve2ControlPoint2;
- (id) initWithLocation:(NSPoint)location curve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve1ControlPoint1:(NSPoint)curve1ControlPoint1 curve1ControlPoint2:(NSPoint)curve1ControlPoint2 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2 curve2ControlPoint1:(NSPoint)curve2ControlPoint1 curve2ControlPoint2:(NSPoint)curve2ControlPoint2;

@property NSPoint location;
@property (retain) FBBezierCurve *curve1;
@property CGFloat parameter1;
@property (retain) FBBezierCurve *curve2;
@property CGFloat parameter2;
@property (getter = isTangent) BOOL tangent;

@end
