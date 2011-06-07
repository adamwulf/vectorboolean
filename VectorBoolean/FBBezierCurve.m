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

typedef struct FBNormalizedLine {
    CGFloat a; // * x +
    CGFloat b; // * y +
    CGFloat c; // constant
} FBNormalizedLine;

// Create a normalized line such that computing the distance from it is quick.
//  See:    http://softsurfer.com/Archive/algorithm_0102/algorithm_0102.htm#Distance%20to%20an%20Infinite%20Line
//          http://www.cs.mtu.edu/~shene/COURSES/cs3621/NOTES/geometry/basic.html
//
static FBNormalizedLine FBNormalizedLineMake(NSPoint point1, NSPoint point2)
{
    FBNormalizedLine line = { point1.y - point2.y, point2.x - point1.x, point1.x * point2.y - point2.x * point1.y };
    CGFloat distance = sqrtf(line.b * line.b + line.a * line.a);
    line.a /= distance;
    line.b /= distance;
    line.c /= distance;
    return line;
}

static CGFloat FBNormalizedLineDistanceFromPoint(FBNormalizedLine line, NSPoint point)
{
    return line.a * point.x + line.b * point.y + line.c;
}


typedef struct FBRange {
    CGFloat minimum;
    CGFloat maximum;
} FBRange;

static FBRange FBRangeMake(CGFloat minimum, CGFloat maximum)
{
    FBRange range = { minimum, maximum };
    return range;
}

// The three points are a counter-clockwise turn if the return value is greater than 0,
//  clockwise if less than 0, or colinear if 0.
static CGFloat CounterClockwiseTurn(NSPoint point1, NSPoint point2, NSPoint point3)
{
    return (point2.x - point1.x) * (point3.y - point1.y) - (point2.y - point1.y) * (point3.x - point1.x);
}

@interface FBBezierCurve ()

- (FBNormalizedLine) fatLine;
- (FBRange) boundsOfFatLine:(FBNormalizedLine)line;

@end

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
    
    // Iterate 3 times
        // Eliminate range of self that doesn't intersect with curve
            // Calculate normal fat line
            
        // If didn't eliminate at least 20%, split the large curve in two, and try again
    
        // Eliminate range of curve that doesn't intersect with self
    
    
    return [NSArray array];
}

- (FBNormalizedLine) fatLine
{
    return FBNormalizedLineMake(_endPoint1, _endPoint2);
}

- (FBRange) boundsOfFatLine:(FBNormalizedLine)line
{
    CGFloat controlPoint1Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint1);
    CGFloat controlPoint2Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint2);
    
    if ( controlPoint1Distance * controlPoint2Distance > 0 )
        return FBRangeMake(3.0 * MIN(0.0, MIN(controlPoint1Distance, controlPoint2Distance)) / 4.0, 3.0 * MAX(0, MAX(controlPoint1Distance, controlPoint2Distance)) / 4.0);
    
    return FBRangeMake(4.0 * MIN(0.0, MIN(controlPoint1Distance, controlPoint2Distance)) / 9.0, 4.0 * MAX(0, MAX(controlPoint1Distance, controlPoint2Distance)) / 9.0);    
}

- (NSArray *) convexHull
{
    // This is the Graham-Scan algorithm: http://en.wikipedia.org/wiki/Graham_scan
    NSMutableArray *points = [NSMutableArray arrayWithObjects:[NSValue valueWithPoint:_endPoint1], [NSValue valueWithPoint:_controlPoint1], [NSValue valueWithPoint:_controlPoint2], [NSValue valueWithPoint:_endPoint2], nil];
    
    // Find point with lowest y value. If tied, the one with lowest x. Then swap the lowest value
    //  to the first index
    NSUInteger lowestIndex = NSNotFound;
    NSPoint lowestValue = [[points objectAtIndex:0] pointValue];
    for (NSUInteger i = 0; i < [points count]; i++) {
        NSPoint point = [[points objectAtIndex:i] pointValue];
        if ( point.y < lowestValue.y || (point.y == lowestValue.y && point.x < lowestValue.x) ) {
            lowestIndex = i;
            lowestValue = point;
        }
    }
    [points exchangeObjectAtIndex:0 withObjectAtIndex:lowestIndex];

    // Sort the points based on the angle they form with the x-axis
    [points sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSPoint point1 = [obj1 pointValue];
        NSPoint point2 = [obj2 pointValue];
        
        // Our pivot value (lowestValue, at index 0) should stay at the lowest
        if ( NSEqualPoints(lowestValue, point1) )
            return NSOrderedAscending;
        if ( NSEqualPoints(lowestValue, point2) )
            return NSOrderedDescending;
        
        // We want to sort by the angle, so that the angles increase as we go along in the array.
        //  However, the cosine is cheaper to calculate, although it decreases in value as the angle
        //  increases (in the domain we care about). 
        CGFloat cosine1 = (point1.x - lowestValue.x) / FBDistanceBetweenPoints(point1, lowestValue);
        CGFloat cosine2 = (point2.x - lowestValue.x) / FBDistanceBetweenPoints(point2, lowestValue);
        if ( cosine1 < cosine2 )
            return NSOrderedDescending;
        else if ( cosine1 > cosine2 )
            return NSOrderedAscending;
        return NSOrderedSame;
    }];
    
    // Insert a sentinel point 
    [points insertObject:[points objectAtIndex:[points count] - 1] atIndex:0];

    NSUInteger numberOfConvexHullPoints = 2;
    for (NSUInteger i = 3; i < [points count]; i++) {
        while ( CounterClockwiseTurn([[points objectAtIndex:numberOfConvexHullPoints - 1] pointValue], [[points objectAtIndex:numberOfConvexHullPoints] pointValue], [[points objectAtIndex:i] pointValue]) <= 0 ) {
            if ( numberOfConvexHullPoints == 2 ) {
                [points exchangeObjectAtIndex:numberOfConvexHullPoints withObjectAtIndex:i];
                i++;
            } else
                numberOfConvexHullPoints--;
        }
        
        numberOfConvexHullPoints++;
        [points exchangeObjectAtIndex:numberOfConvexHullPoints withObjectAtIndex:i];
    }
    
    return [points subarrayWithRange:NSMakeRange(0, numberOfConvexHullPoints)];
}

@end
