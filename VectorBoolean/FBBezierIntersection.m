//
//  FBBezierIntersection.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierIntersection.h"
#import "FBBezierCurve.h"

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
    
    [super dealloc];
}

- (NSPoint) location
{
    [self computeCurve1];
    return _location;
}

- (BOOL) isTangent
{
    // TODO: compute if it's tangent
    return NO;
}

- (NSPoint) curve1ControlPoint1
{
    [self computeCurve1];
    return _curve1ControlPoint1;
}

- (NSPoint) curve1ControlPoint2
{
    [self computeCurve1];
    return _curve1ControlPoint2;
}

- (NSPoint) curve2ControlPoint1
{
    [self computeCurve2];
    return _curve2ControlPoint1;
}

- (NSPoint) curve2ControlPoint2
{
    [self computeCurve2];
    return _curve2ControlPoint2;
}

- (void) computeCurve1
{
    if ( !_needToComputeCurve1 )
        return;
    
    _location = [_curve1 pointAtParameter:_parameter1 controlPoint1:&_curve1ControlPoint1 controlPoint2:&_curve1ControlPoint2];
    
    _needToComputeCurve1 = NO;
}

- (void) computeCurve2
{
    if ( !_needToComputeCurve2 )
        return;
    
    [_curve2 pointAtParameter:_parameter2 controlPoint1:&_curve2ControlPoint1 controlPoint2:&_curve2ControlPoint2];
    
    _needToComputeCurve2 = NO;
}

@end
