//
//  Geometry.m
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "Geometry.h"

static const CGFloat FBPointClosenessThreshold = 1e-10;


CGFloat FBDistanceBetweenPoints(NSPoint point1, NSPoint point2)
{
    CGFloat xDelta = point2.x - point1.x;
    CGFloat yDelta = point2.y - point1.y;
    return sqrtf(xDelta * xDelta + yDelta * yDelta);
}

CGFloat FBDistancePointToLine(NSPoint point, NSPoint lineStartPoint, NSPoint lineEndPoint)
{
    CGFloat lineLength = FBDistanceBetweenPoints(lineStartPoint, lineEndPoint);
    if ( lineLength == 0 )
        return 0;
    CGFloat u = ((point.x - lineStartPoint.x) * (lineEndPoint.x - lineStartPoint.x) + (point.y - lineStartPoint.y) * (lineEndPoint.y - lineStartPoint.y)) / (lineLength * lineLength);
    NSPoint intersectionPoint = NSMakePoint(lineStartPoint.x + u * (lineEndPoint.x - lineStartPoint.x), lineStartPoint.y + u * (lineEndPoint.y - lineStartPoint.y));
    return FBDistanceBetweenPoints(point, intersectionPoint);
}

NSPoint FBAddPoint(NSPoint point1, NSPoint point2)
{
    return NSMakePoint(point1.x + point2.x, point1.y + point2.y);
}

NSPoint FBUnitScalePoint(NSPoint point, CGFloat scale)
{
    NSPoint result = point;
    CGFloat length = FBPointLength(point);
    if ( length != 0.0 ) {
        result.x *= scale/length;
        result.y *= scale/length;
    }
    return result;
}

NSPoint FBScalePoint(NSPoint point, CGFloat scale)
{
    return NSMakePoint(point.x * scale, point.y * scale);
}

CGFloat FBDotMultiplyPoint(NSPoint point1, NSPoint point2)
{
    return point1.x * point2.x + point1.y * point2.y;
}

NSPoint FBSubtractPoint(NSPoint point1, NSPoint point2)
{
    return NSMakePoint(point1.x - point2.x, point1.y - point2.y);
}

CGFloat FBPointLength(NSPoint point)
{
    return sqrtf((point.x * point.x) + (point.y * point.y));
}

CGFloat FBPointSquaredLength(NSPoint point)
{
    return (point.x * point.x) + (point.y * point.y);
}

NSPoint FBNormalizePoint(NSPoint point)
{
    NSPoint result = point;
    CGFloat length = FBPointLength(point);
    if ( length != 0.0 ) {
        result.x /= length;
        result.y /= length;
    }
    return result;
}

NSPoint FBNegatePoint(NSPoint point)
{
    return NSMakePoint(-point.x, -point.y);
}

NSPoint FBRoundPoint(NSPoint point)
{
    NSPoint result = { roundf(point.x), roundf(point.y) };
    return result;
}

NSPoint FBLineNormal(NSPoint lineStart, NSPoint lineEnd)
{
    return FBNormalizePoint(NSMakePoint(-(lineEnd.y - lineStart.y), lineEnd.x - lineStart.x));
}

NSPoint FBLineMidpoint(NSPoint lineStart, NSPoint lineEnd)
{
    CGFloat distance = FBDistanceBetweenPoints(lineStart, lineEnd);
    NSPoint tangent = FBNormalizePoint(FBSubtractPoint(lineEnd, lineStart));
    return FBAddPoint(lineStart, FBUnitScalePoint(tangent, distance / 2.0));
}

BOOL FBArePointsClose(NSPoint point1, NSPoint point2)
{
    return FBArePointsCloseWithOptions(point1, point2, FBPointClosenessThreshold);
}

BOOL FBArePointsCloseWithOptions(NSPoint point1, NSPoint point2, CGFloat threshold)
{
    return FBAreValuesCloseWithOptions(point1.x, point2.x, threshold) && FBAreValuesCloseWithOptions(point1.y, point2.y, threshold);
}

BOOL FBAreValuesClose(CGFloat value1, CGFloat value2)
{
    return FBAreValuesCloseWithOptions(value1, value2, FBPointClosenessThreshold);
}

BOOL FBAreValuesCloseWithOptions(CGFloat value1, CGFloat value2, CGFloat threshold)
{
    CGFloat delta = value1 - value2;    
    return (delta <= threshold) && (delta >= -threshold);
}
