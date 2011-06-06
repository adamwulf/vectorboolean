//
//  FBBezierCurve.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierCurve.h"
#import "NSBezierPath+Utilities.h"
#import "Geometry.h"

@implementation FBBezierCurve

+ (NSArray *) bezierCurvesFromBezierPath:(NSBezierPath *)path
{
    NSPoint lastPoint = NSZeroPoint;
    NSMutableArray *bezierCurves = [NSMutableArray arrayWithCapacity:[path elementCount]];
    
    for (NSUInteger i = 0; i < [path elementCount]; i++) {
        NSBezierElement element = [path fb_elementAtIndex:i];
        
        switch (element.kind) {
            case NSMoveToBezierPathElement:
                lastPoint = element.point;
                break;
                
            case NSLineToBezierPathElement: {
                // Convert lines to bezier curves as well. Just set control point to be in the line formed
                //  by the end points, 1/3 of the distance away from the end point.
                CGFloat distance = FBDistanceBetweenPoints(lastPoint, element.point);
                NSPoint leftTangent = FBNormalizePoint(FBSubtractPoint(element.point, lastPoint));
                NSPoint controlPoint1 = FBAddPoint(lastPoint, FBUnitScalePoint(leftTangent, distance / 3.0));
                NSPoint controlPoint2 = FBAddPoint(lastPoint, FBUnitScalePoint(leftTangent, 2.0 * distance / 3.0));
                [bezierCurves addObject:[FBBezierCurve bezierCurveWithEndPoint1:lastPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2 endPoint2:element.point]];
                
                lastPoint = element.point;
                break;
            }
                
            case NSCurveToBezierPathElement:
                [bezierCurves addObject:[FBBezierCurve bezierCurveWithEndPoint1:lastPoint controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1] endPoint2:element.point]];
                
                lastPoint = element.point;
                break;
                
            case NSClosePathBezierPathElement:
                lastPoint = NSZeroPoint;
                break;
        }
    }
    
    return bezierCurves;
}

+ (id) bezierCurveWithEndPoint1:(NSPoint)endPoint1 controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 endPoint2:(NSPoint)endPoint2
{
    return [[[FBBezierCurve alloc] initWithEndPoint1:endPoint1 controlPoint1:controlPoint1 controlPoint2:controlPoint2 endPoint2:endPoint2] autorelease];
}

- (id) initWithEndPoint1:(NSPoint)endPoint1 controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 endPoint2:(NSPoint)endPoint2
{
    self = [super init];
    
    if ( self != nil ) {
        _endPoint1 = endPoint1;
        _controlPoint1 = controlPoint1;
        _controlPoint2 = controlPoint2;
        _endPoint2 = endPoint2;
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve
{
    return [NSArray array];
}

@end
