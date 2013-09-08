//
//  UIBezierPath+Utilities.m
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "UIBezierPath+Utilities.h"
#import "Geometry.h"
#import "DrawKit-iOS.h"

static const CGFloat FBDebugPointSize = 10.0;
static const CGFloat FBDebugSmallPointSize = 3.0;

@implementation UIBezierPath (FBUtilities)

- (CGPoint) fb_pointAtIndex:(NSUInteger)index
{
    return [self fb_elementAtIndex:index].point;
}

- (UIBezierElement) fb_elementAtIndex:(NSUInteger)index
{
    UIBezierElement element = {};
    CGPoint points[3] = {};
    element.kind = [self elementAtIndex:index associatedPoints:points].type;
    switch (element.kind) {
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
        case kCGPathElementCloseSubpath:
            element.point = points[0];
            break;
            
        case kCGPathElementAddCurveToPoint:
            element.controlPoints[0] = points[0];
            element.controlPoints[1] = points[1];
            element.point = points[2];
            break;
        default:
            break;
    }
    return element;
}

- (UIBezierPath *) fb_subpathWithRange:(NSRange)range
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path fb_copyAttributesFrom:self];
    for (NSUInteger i = 0; i < range.length; i++) {
        UIBezierElement element = [self fb_elementAtIndex:range.location + i];
        if ( i == 0 )
            [path moveToPoint:element.point];
        else
            [path fb_appendElement:element];
    }
    return path;
}

- (void) fb_copyAttributesFrom:(UIBezierPath *)path
{
    [self setLineWidth:[path lineWidth]];
    [self setLineCapStyle:[path lineCapStyle]];
    [self setLineJoinStyle:[path lineJoinStyle]];
    [self setMiterLimit:[path miterLimit]];
    [self setFlatness:[path flatness]];
}

- (void) fb_appendPath:(UIBezierPath *)path
{
    UIBezierElement previousElement = [self elementCount] > 0 ? [self fb_elementAtIndex:[self elementCount] - 1] : (UIBezierElement){};
    for (NSUInteger i = 0; i < [path elementCount]; i++) {
        UIBezierElement element = [path fb_elementAtIndex:i];
        
        // If the first element is a move to where we left off, skip it
        if ( element.kind == kCGPathElementMoveToPoint ) {
            if ( CGPointEqualToPoint(element.point, previousElement.point) )
                continue;
            else
                element.kind = kCGPathElementAddLineToPoint; // change it to a line to
        }
        
        [self fb_appendElement:element];
        previousElement = element;
    }
}

- (void) fb_appendElement:(UIBezierElement)element
{
    switch (element.kind) {
        case kCGPathElementMoveToPoint:
            [self moveToPoint:element.point];
            break;
        case kCGPathElementAddLineToPoint:
            [self addLineToPoint:element.point];
            break;
        case kCGPathElementAddCurveToPoint:
            [self addCurveToPoint:element.point controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1]];
            break;
        case kCGPathElementCloseSubpath:
            [self closePath];
            break;
        default:
            break;
    }
}

+ (UIBezierPath *) circleAtPoint:(CGPoint)point
{
	CGRect rect = CGRectMake(point.x - FBDebugPointSize * 0.5, point.y - FBDebugPointSize * 0.5, FBDebugPointSize, FBDebugPointSize);
		
	return [self bezierPathWithOvalInRect:rect];
}

+ (UIBezierPath *) rectAtPoint:(CGPoint)point
{
	CGRect rect = CGRectMake(point.x - FBDebugPointSize * 0.5 * 1.3, point.y - FBDebugPointSize * 0.5 * 1.3, FBDebugPointSize * 1.3, FBDebugPointSize * 1.3);
		
	return [self bezierPathWithRect:rect];
}

+ (UIBezierPath *) smallCircleAtPoint:(CGPoint)point
{
	CGRect rect = CGRectMake(point.x - FBDebugSmallPointSize * 0.5, point.y - FBDebugSmallPointSize * 0.5, FBDebugSmallPointSize, FBDebugSmallPointSize);
    
	return [self bezierPathWithOvalInRect:rect];
}

+ (UIBezierPath *) smallRectAtPoint:(CGPoint)point
{
	CGRect rect = CGRectMake(point.x - FBDebugSmallPointSize * 0.5, point.y - FBDebugSmallPointSize * 0.5, FBDebugSmallPointSize, FBDebugSmallPointSize);
    
	return [self bezierPathWithRect:rect];
}

+ (UIBezierPath *) triangleAtPoint:(CGPoint)point direction:(CGPoint)tangent
{
    CGPoint endPoint = FBAddPoint(point, FBScalePoint(tangent, FBDebugPointSize * 1.5));
    CGPoint normal1 = FBLineNormal(point, endPoint);
    CGPoint normal2 = CGPointMake(-normal1.x, -normal1.y);
    CGPoint basePoint1 = FBAddPoint(point, FBScalePoint(normal1, FBDebugPointSize * 0.5));
    CGPoint basePoint2 = FBAddPoint(point, FBScalePoint(normal2, FBDebugPointSize * 0.5));
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:basePoint1];
    [path addLineToPoint:endPoint];
    [path addLineToPoint:basePoint2];
    [path addLineToPoint:basePoint1];
    [path closePath];
    return path;
}

@end
