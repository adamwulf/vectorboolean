//
//  FBBezierIntersection.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierIntersection.h"
#import "FBBezierCurve.h"

@implementation FBBezierIntersection

@synthesize location=_location;
@synthesize curve1=_curve1;
@synthesize parameter1=_parameter1;
@synthesize curve2=_curve2;
@synthesize parameter2=_parameter2;
@synthesize tangent=_tangent;

+ (id) intersectionWithLocation:(NSPoint)location curve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve1ControlPoint1:(NSPoint)curve1ControlPoint1 curve1ControlPoint2:(NSPoint)curve1ControlPoint2 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2 curve2ControlPoint1:(NSPoint)curve2ControlPoint1 curve2ControlPoint2:(NSPoint)curve2ControlPoint2
{
    return [[[FBBezierIntersection alloc] initWithLocation:location curve1:curve1 parameter1:parameter1 curve1ControlPoint1:curve1ControlPoint1 curve1ControlPoint2:curve1ControlPoint2 curve2:curve2 parameter2:parameter2 curve2ControlPoint1:curve2ControlPoint1 curve2ControlPoint2:curve2ControlPoint2] autorelease];
}

- (id) initWithLocation:(NSPoint)location curve1:(FBBezierCurve *)curve1 parameter1:(CGFloat)parameter1 curve1ControlPoint1:(NSPoint)curve1ControlPoint1 curve1ControlPoint2:(NSPoint)curve1ControlPoint2 curve2:(FBBezierCurve *)curve2 parameter2:(CGFloat)parameter2 curve2ControlPoint1:(NSPoint)curve2ControlPoint1 curve2ControlPoint2:(NSPoint)curve2ControlPoint2;
{
    self = [super init];
    
    if ( self != nil ) {
        _location = location;
        _curve1 = [curve1 retain];
        _parameter1 = parameter1;
        _curve1ControlPoint1 = curve1ControlPoint1;
        _curve1ControlPoint2 = curve1ControlPoint2;
        _curve2 = [curve2 retain];
        _parameter2 = parameter2;
        _curve2ControlPoint1 = curve2ControlPoint1;
        _curve2ControlPoint2 = curve2ControlPoint2;
        
        // TODO: calculate tangent
    }
    
    return self;
}

- (void)dealloc
{
    [_curve1 release];
    [_curve2 release];
    
    [super dealloc];
}

@end
