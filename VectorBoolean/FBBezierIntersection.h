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

@end
