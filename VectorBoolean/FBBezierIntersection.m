//
//  FBBezierIntersection.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierIntersection.h"
#import "FBBezierCurve.h"
#import "Geometry.h"

@interface FBBezierIntersection ()

- (void) computeCurve1;
- (void) computeCurve2;

@end

@implementation FBBezierIntersection

@synthesize curve1=_curve1;
@synthesize parameter1=_parameter1;
@synthesize curve2=_curve2;
@synthesize parameter2=_parameter2;

+ (id) intersectionWithCurve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2
{
    return [[[FBBezierIntersection alloc] initWithCurve1:curve1 parameter1:parameter1 curve2:curve2 parameter2:parameter2] autorelease];
}

- (id) initWithCurve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2
{
    self = [super init];
    
    if ( self != nil ) {
        _curve1 = [curve1 retain];
        _parameter1 = parameter1;
        _curve2 = [curve2 retain];
        _parameter2 = parameter2;
        _needToComputeCurve1 = YES;
        _needToComputeCurve2 = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [_curve1 release];
    [_curve2 release];
    [_curve1LeftBezier release];
    [_curve1RightBezier release];
    [_curve2LeftBezier release];
    [_curve2RightBezier release];
    
    [super dealloc];
}

- (NSPoint) location
{
    [self computeCurve1];
    return _location;
}

- (BOOL) isTangent
{
    [self computeCurve1];
    [self computeCurve2];

    static const CGFloat FBPointCloseThreshold = 1e-7;
    
    NSPoint curve1LeftTangent = FBNormalizePoint(FBSubtractPoint(_curve1LeftBezier.controlPoint2, _curve1LeftBezier.endPoint2));
    NSPoint curve1RightTangent = FBNormalizePoint(FBSubtractPoint(_curve1RightBezier.controlPoint1, _curve1RightBezier.endPoint1));
    NSPoint curve2LeftTangent = FBNormalizePoint(FBSubtractPoint(_curve2LeftBezier.controlPoint2, _curve2LeftBezier.endPoint2));
    NSPoint curve2RightTangent = FBNormalizePoint(FBSubtractPoint(_curve2RightBezier.controlPoint1, _curve2RightBezier.endPoint1));
        
    return FBArePointsCloseWithOptions(curve1LeftTangent, curve2LeftTangent, FBPointCloseThreshold) || FBArePointsCloseWithOptions(curve1LeftTangent, curve2RightTangent, FBPointCloseThreshold) || FBArePointsCloseWithOptions(curve1RightTangent, curve2LeftTangent, FBPointCloseThreshold) || FBArePointsCloseWithOptions(curve1RightTangent, curve2RightTangent, FBPointCloseThreshold);
}

- (FBBezierCurve *) curve1LeftBezier
{
    [self computeCurve1];
    return _curve1LeftBezier;
}

- (FBBezierCurve *) curve1RightBezier
{
    [self computeCurve1];
    return _curve1RightBezier;
}

- (FBBezierCurve *) curve2LeftBezier
{
    [self computeCurve2];
    return _curve2LeftBezier;
}

- (FBBezierCurve *) curve2RightBezier
{
    [self computeCurve2];
    return _curve2RightBezier;
}

- (void) computeCurve1
{
    if ( !_needToComputeCurve1 )
        return;
    
    _location = [_curve1 pointAtParameter:_parameter1 leftBezierCurve:&_curve1LeftBezier rightBezierCurve:&_curve1RightBezier];
    [_curve1LeftBezier retain];
    [_curve1RightBezier retain];
    
    _needToComputeCurve1 = NO;
}

- (void) computeCurve2
{
    if ( !_needToComputeCurve2 )
        return;
    
    [_curve2 pointAtParameter:_parameter2 leftBezierCurve:&_curve2LeftBezier rightBezierCurve:&_curve2RightBezier];
    [_curve2LeftBezier retain];
    [_curve2RightBezier retain];
    
    _needToComputeCurve2 = NO;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: location = (%f, %f), isTangent = %d>", 
            NSStringFromClass([self class]),
            self.location.x, self.location.y,
            (int)self.isTangent];
}

@end
