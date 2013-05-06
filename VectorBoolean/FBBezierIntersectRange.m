//
//  FBBezierIntersectRange.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 11/6/12.
//  Copyright (c) 2012 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierIntersectRange.h"
#import "FBBezierCurve.h"
#import "FBBezierIntersection.h"

extern const CGFloat FBParameterCloseThreshold;

@interface FBBezierIntersectRange () 

- (void) computeCurve1;
- (void) computeCurve2;

@end

@implementation FBBezierIntersectRange

@synthesize curve1=_curve1;
@synthesize parameterRange1=_parameterRange1;
@synthesize curve2=_curve2;
@synthesize parameterRange2=_parameterRange2;
@synthesize reversed=_reversed;

+ (id) intersectRangeWithCurve1:(FBBezierCurve *)curve1 parameterRange1:(FBRange)parameterRange1 curve2:(FBBezierCurve *)curve2 parameterRange2:(FBRange)parameterRange2 reversed:(BOOL)reversed
{
    return [[[FBBezierIntersectRange alloc] initWithCurve1:curve1 parameterRange1:parameterRange1 curve2:curve2 parameterRange2:parameterRange2 reversed:reversed] autorelease];
}

- (id) initWithCurve1:(FBBezierCurve *)curve1 parameterRange1:(FBRange)parameterRange1 curve2:(FBBezierCurve *)curve2 parameterRange2:(FBRange)parameterRange2 reversed:(BOOL)reversed
{
    self = [super init];
    if ( self != nil ) {
        _curve1 = [curve1 retain];
        _parameterRange1 = parameterRange1;
        _curve2 = [curve2 retain];
        _parameterRange2 = parameterRange2;
        _reversed = reversed;
        _needToComputeCurve1 = YES;
        _needToComputeCurve2 = YES;
    }
    return self;
}

- (void) dealloc
{
    [_curve1 release];
    [_curve2 release];
    [_curve1LeftBezier release];
    [_curve1MiddleBezier release];
    [_curve1RightBezier release];
    [_curve2LeftBezier release];
    [_curve2MiddleBezier release];
    [_curve2RightBezier release];

    [super dealloc];
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
    
    NSArray *curves = [_curve1 splitSubcurvesWithRange:_parameterRange1];
    if ( [curves objectAtIndex:0] != [NSNull null] )
        _curve1LeftBezier = [[curves objectAtIndex:0] retain];
    if ( [curves objectAtIndex:1] != [NSNull null] )
        _curve1MiddleBezier = [[curves objectAtIndex:1] retain];
    if ( [curves objectAtIndex:2] != [NSNull null] )
        _curve1RightBezier = [[curves objectAtIndex:2] retain];
        
    _needToComputeCurve1 = NO;
}

- (void) computeCurve2
{
    if ( !_needToComputeCurve2 )
        return;
    
    NSArray *curves = [_curve2 splitSubcurvesWithRange:_parameterRange2];
    if ( [curves objectAtIndex:0] != [NSNull null] )
        _curve2LeftBezier = [[curves objectAtIndex:0] retain];
    if ( [curves objectAtIndex:1] != [NSNull null] )
        _curve2MiddleBezier = [[curves objectAtIndex:1] retain];
    if ( [curves objectAtIndex:2] != [NSNull null] )
        _curve2RightBezier = [[curves objectAtIndex:2] retain];
    
    _needToComputeCurve2 = NO;
}

- (BOOL) isAtStartOfCurve1
{
    return FBAreValuesCloseWithOptions(_parameterRange1.minimum, 0.0, FBParameterCloseThreshold);
}

- (BOOL) isAtStopOfCurve1
{
    return FBAreValuesCloseWithOptions(_parameterRange1.maximum, 1.0, FBParameterCloseThreshold);
}

- (BOOL) isAtStartOfCurve2
{
    return FBAreValuesCloseWithOptions(_parameterRange2.minimum, 0.0, FBParameterCloseThreshold);
}

- (BOOL) isAtStopOfCurve2
{
    return FBAreValuesCloseWithOptions(_parameterRange2.maximum, 1.0, FBParameterCloseThreshold);
}

- (FBBezierIntersection *) middleIntersection
{
    return [FBBezierIntersection intersectionWithCurve1:_curve1 parameter1:(_parameterRange1.minimum + _parameterRange1.maximum) / 2.0 curve2:_curve2 parameter2:(_parameterRange2.minimum + _parameterRange2.maximum) / 2.0];    
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: param1 = (%f, %f), param2 = (%f, %f)>", 
            NSStringFromClass([self class]),
            self.parameterRange1.minimum, self.parameterRange1.maximum, self.parameterRange2.minimum, self.parameterRange2.maximum];
}


@end
