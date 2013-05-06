//
//  NSBezierPath+Utilities.m
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+Utilities.h"
#import "Geometry.h"

static const CGFloat FBDebugPointSize = 10.0;
static const CGFloat FBDebugSmallPointSize = 3.0;

@implementation NSBezierPath (FBUtilities)

- (NSPoint) fb_pointAtIndex:(NSUInteger)index
{
    return [self fb_elementAtIndex:index].point;
}

- (NSBezierElement) fb_elementAtIndex:(NSUInteger)index
{
    NSBezierElement element = {};
    NSPoint points[3] = {};
    element.kind = [self elementAtIndex:index associatedPoints:points];
    switch (element.kind) {
        case NSMoveToBezierPathElement:
        case NSLineToBezierPathElement:
        case NSClosePathBezierPathElement:
            element.point = points[0];
            break;
            
        case NSCurveToBezierPathElement:
            element.controlPoints[0] = points[0];
            element.controlPoints[1] = points[1];
            element.point = points[2];
            break;
    }
    return element;
}

- (NSBezierPath *) fb_subpathWithRange:(NSRange)range
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path fb_copyAttributesFrom:self];
    for (NSUInteger i = 0; i < range.length; i++) {
        NSBezierElement element = [self fb_elementAtIndex:range.location + i];
        if ( i == 0 )
            [path moveToPoint:element.point];
        else
            [path fb_appendElement:element];
    }
    return path;
}

- (void) fb_copyAttributesFrom:(NSBezierPath *)path
{
    [self setLineWidth:[path lineWidth]];
    [self setLineCapStyle:[path lineCapStyle]];
    [self setLineJoinStyle:[path lineJoinStyle]];
    [self setMiterLimit:[path miterLimit]];
    [self setFlatness:[path flatness]];
}

- (void) fb_appendPath:(NSBezierPath *)path
{
    NSBezierElement previousElement = [self elementCount] > 0 ? [self fb_elementAtIndex:[self elementCount] - 1] : (NSBezierElement){};
    for (NSUInteger i = 0; i < [path elementCount]; i++) {
        NSBezierElement element = [path fb_elementAtIndex:i];
        
        // If the first element is a move to where we left off, skip it
        if ( element.kind == NSMoveToBezierPathElement ) {
            if ( NSEqualPoints(element.point, previousElement.point) )
                continue;
            else
                element.kind = NSLineToBezierPathElement; // change it to a line to
        }
        
        [self fb_appendElement:element];
        previousElement = element;
    }
}

- (void) fb_appendElement:(NSBezierElement)element
{
    switch (element.kind) {
        case NSMoveToBezierPathElement:
            [self moveToPoint:element.point];
            break;
        case NSLineToBezierPathElement:
            [self lineToPoint:element.point];
            break;
        case NSCurveToBezierPathElement:
            [self curveToPoint:element.point controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1]];
            break;
        case NSClosePathBezierPathElement:
            [self closePath];
            break;
    }
}

+ (NSBezierPath *) circleAtPoint:(NSPoint)point
{
	NSRect rect = NSMakeRect(point.x - FBDebugPointSize * 0.5, point.y - FBDebugPointSize * 0.5, FBDebugPointSize, FBDebugPointSize);
		
	return [self bezierPathWithOvalInRect:rect];
}

+ (NSBezierPath *) rectAtPoint:(NSPoint)point
{
	NSRect rect = NSMakeRect(point.x - FBDebugPointSize * 0.5 * 1.3, point.y - FBDebugPointSize * 0.5 * 1.3, FBDebugPointSize * 1.3, FBDebugPointSize * 1.3);
		
	return [self bezierPathWithRect:rect];
}

+ (NSBezierPath *) smallCircleAtPoint:(NSPoint)point
{
	NSRect rect = NSMakeRect(point.x - FBDebugSmallPointSize * 0.5, point.y - FBDebugSmallPointSize * 0.5, FBDebugSmallPointSize, FBDebugSmallPointSize);
    
	return [self bezierPathWithOvalInRect:rect];
}

+ (NSBezierPath *) smallRectAtPoint:(NSPoint)point
{
	NSRect rect = NSMakeRect(point.x - FBDebugSmallPointSize * 0.5, point.y - FBDebugSmallPointSize * 0.5, FBDebugSmallPointSize, FBDebugSmallPointSize);
    
	return [self bezierPathWithRect:rect];
}

+ (NSBezierPath *) triangleAtPoint:(NSPoint)point direction:(NSPoint)tangent
{
    NSPoint endPoint = FBAddPoint(point, FBScalePoint(tangent, FBDebugPointSize * 1.5));
    NSPoint normal1 = FBLineNormal(point, endPoint);
    NSPoint normal2 = NSMakePoint(-normal1.x, -normal1.y);
    NSPoint basePoint1 = FBAddPoint(point, FBScalePoint(normal1, FBDebugPointSize * 0.5));
    NSPoint basePoint2 = FBAddPoint(point, FBScalePoint(normal2, FBDebugPointSize * 0.5));
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:basePoint1];
    [path lineToPoint:endPoint];
    [path lineToPoint:basePoint2];
    [path lineToPoint:basePoint1];
    [path closePath];
    return path;
}

@end
