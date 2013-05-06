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
    return sqrt(xDelta * xDelta + yDelta * yDelta);
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
    return sqrt((point.x * point.x) + (point.y * point.y));
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
    NSPoint result = { round(point.x), round(point.y) };
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

NSPoint FBRectGetTopLeft(NSRect rect)
{
    return NSMakePoint(NSMinX(rect), NSMinY(rect));
}

NSPoint FBRectGetTopRight(NSRect rect)
{
    return NSMakePoint(NSMaxX(rect), NSMinY(rect));
}

NSPoint FBRectGetBottomLeft(NSRect rect)
{
    return NSMakePoint(NSMinX(rect), NSMaxY(rect));
}

NSPoint FBRectGetBottomRight(NSRect rect)
{
    return NSMakePoint(NSMaxX(rect), NSMaxY(rect));
}

void FBExpandBoundsByPoint(NSPoint *topLeft, NSPoint *bottomRight, NSPoint point)
{
    if ( point.x < topLeft->x )
        topLeft->x = point.x;
    if ( point.x > bottomRight->x )
        bottomRight->x = point.x;
    if ( point.y < topLeft->y )
        topLeft->y = point.y;
    if ( point.y > bottomRight->y )
        bottomRight->y = point.y;
}

NSRect FBUnionRect(NSRect rect1, NSRect rect2)
{
    NSPoint topLeft = FBRectGetTopLeft(rect1);
    NSPoint bottomRight = FBRectGetBottomRight(rect1);
    FBExpandBoundsByPoint(&topLeft, &bottomRight, FBRectGetTopLeft(rect2));
    FBExpandBoundsByPoint(&topLeft, &bottomRight, FBRectGetTopRight(rect2));
    FBExpandBoundsByPoint(&topLeft, &bottomRight, FBRectGetBottomRight(rect2));
    FBExpandBoundsByPoint(&topLeft, &bottomRight, FBRectGetBottomLeft(rect2));    
    return NSMakeRect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
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

//////////////////////////////////////////////////////////////////////////
// Helper methods for angles
//
static const CGFloat FB2PI = 2.0 * M_PI;

// Normalize the angle between 0 and 2pi
CGFloat NormalizeAngle(CGFloat value)
{
    while ( value < 0.0 )
        value += FB2PI;
    while ( value >= FB2PI )
        value -= FB2PI;
    return value;
}

// Compute the polar angle from the cartesian point
CGFloat PolarAngle(NSPoint point)
{
    CGFloat value = 0.0;
    if ( point.x > 0.0 )
        value = atan(point.y / point.x);
    else if ( point.x < 0.0 ) {
        if ( point.y >= 0.0 )
            value = atan(point.y / point.x) + M_PI;
        else
            value = atan(point.y / point.x) - M_PI;
    } else {
        if ( point.y > 0.0 )
            value =  M_PI_2;
        else if ( point.y < 0.0 )
            value =  -M_PI_2;
        else
            value = 0.0;
    }
    return NormalizeAngle(value);
}


FBAngleRange FBAngleRangeMake(CGFloat minimum, CGFloat maximum)
{
    FBAngleRange range = { minimum, maximum };
    return range;
}

BOOL FBAngleRangeContainsAngle(FBAngleRange range, CGFloat angle)
{
    if ( range.minimum <= range.maximum )
        return angle > range.minimum && angle < range.maximum;
    
    // The range wraps around 0. See if the angle falls in the first half
    if ( angle > range.minimum && angle <= FB2PI )
        return YES;
    
    return angle >= 0.0 && angle < range.maximum;
}

//////////////////////////////////////////////////////////////////////////////////
// Parameter ranges
//
FBRange FBRangeMake(CGFloat minimum, CGFloat maximum)
{
    FBRange range = { minimum, maximum };
    return range;
}

BOOL FBRangeHasConverged(FBRange range, NSUInteger places)
{
    CGFloat factor = pow(10.0, places);
    NSInteger minimum = (NSInteger)(range.minimum * factor);
    NSInteger maxiumum = (NSInteger)(range.maximum * factor);
    return minimum == maxiumum;
}

CGFloat FBRangeGetSize(FBRange range)
{
    return range.maximum - range.minimum;
}

CGFloat FBRangeAverage(FBRange range)
{
    return (range.minimum + range.maximum) / 2.0;
}

CGFloat FBRangeScaleNormalizedValue(FBRange range, CGFloat value)
{
    return (range.maximum - range.minimum) * value + range.minimum;
}


BOOL FBTangentsCross(NSPoint edge1Tangents[2], NSPoint edge2Tangents[2])
{    
    // Calculate angles for the tangents
    CGFloat edge1Angles[] = { PolarAngle(edge1Tangents[0]), PolarAngle(edge1Tangents[1]) };
    CGFloat edge2Angles[] = { PolarAngle(edge2Tangents[0]), PolarAngle(edge2Tangents[1]) };
    
    // Count how many times edge2 angles appear between the self angles
    FBAngleRange range1 = FBAngleRangeMake(edge1Angles[0], edge1Angles[1]);
    NSUInteger rangeCount1 = 0;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[0]) )
        rangeCount1++;
    if ( FBAngleRangeContainsAngle(range1, edge2Angles[1]) )
        rangeCount1++;
    
    // Count how many times self angles appear between the edge2 angles
    FBAngleRange range2 = FBAngleRangeMake(edge1Angles[1], edge1Angles[0]);
    NSUInteger rangeCount2 = 0;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[0]) )
        rangeCount2++;
    if ( FBAngleRangeContainsAngle(range2, edge2Angles[1]) )
        rangeCount2++;
    
    // If each pair of angles split the other two, then the edges cross.
    return rangeCount1 == 1 && rangeCount2 == 1;
}
