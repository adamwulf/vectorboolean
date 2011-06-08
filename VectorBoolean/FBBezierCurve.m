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
#import "FBBezierIntersection.h"

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

static BOOL FBRangeHasConverged(FBRange range, NSUInteger places)
{
    CGFloat factor = powf(10.0, places);
    NSInteger minimum = (NSInteger)(range.minimum * factor);
    NSInteger maxiumum = (NSInteger)(range.maximum * factor);
    return minimum == maxiumum;
}

static CGFloat FBRangeGetSize(FBRange range)
{
    return range.maximum - range.minimum;
}

static CGFloat FBRangeScaleNormalizedValue(FBRange range, CGFloat value)
{
    return (range.maximum - range.minimum) * value + range.minimum;
}

// The three points are a counter-clockwise turn if the return value is greater than 0,
//  clockwise if less than 0, or colinear if 0.
static CGFloat CounterClockwiseTurn(NSPoint point1, NSPoint point2, NSPoint point3)
{
    return (point2.x - point1.x) * (point3.y - point1.y) - (point2.y - point1.y) * (point3.x - point1.x);
}

static BOOL LineIntersectsHorizontalLine(NSPoint startPoint, NSPoint endPoint, CGFloat y, NSPoint *intersectPoint)
{
    // Do a quick test to see if y even falls on the startPoint,endPoint line
    if ( y < MIN(startPoint.y, endPoint.y) || y > MAX(startPoint.y, endPoint.y) )
        return NO;
    
    // There's an intersection here somewhere
    if ( startPoint.x == endPoint.x )
        *intersectPoint = NSMakePoint(startPoint.x, y);
    else {
        CGFloat slope = (endPoint.y - startPoint.y) / (endPoint.x - startPoint.x);
        *intersectPoint = NSMakePoint((y - startPoint.y) / slope + startPoint.x, y);
    }
    
    return YES;
}

@interface FBBezierCurve ()

- (FBNormalizedLine) fatLine;
- (FBRange) boundsOfFatLine:(FBNormalizedLine)line;
- (FBRange) clipWithFatLine:(FBNormalizedLine)fatLine bounds:(FBRange)bounds;
- (FBBezierCurve *) subcurveWithRange:(FBRange)range;
- (NSArray *) splitCurveAtParameter:(CGFloat)t;
- (NSArray *) convexHull;
- (FBBezierCurve *) bezierClipWithBezierCurve:(FBBezierCurve *)curve rangeOfOriginal:(FBRange *)originalRange;
- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve usRange:(FBRange *)usRange themRange:(FBRange *)themRange originalUs:(FBBezierCurve *)originalUs originalThem:(FBBezierCurve *)originalThem;

@property NSPoint endPoint1;
@property NSPoint controlPoint1;
@property NSPoint controlPoint2;
@property NSPoint endPoint2;

@end

@implementation FBBezierCurve

@synthesize endPoint1=_endPoint1;
@synthesize controlPoint1=_controlPoint1;
@synthesize controlPoint2=_controlPoint2;
@synthesize endPoint2=_endPoint2;

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
    FBRange usRange = FBRangeMake(0, 1);
    FBRange themRange = FBRangeMake(0, 1);
    return [self intersectionsWithBezierCurve:curve usRange:&usRange themRange:&themRange originalUs:self originalThem:curve];
}

- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve usRange:(FBRange *)usRange themRange:(FBRange *)themRange originalUs:(FBBezierCurve *)originalUs originalThem:(FBBezierCurve *)originalThem
{
    static const NSUInteger places = 6; // want precision to 6 decimal places
    static const NSUInteger maxIterations = 100;
    static const CGFloat minimumChangeNeeded = 0.20;
    
    FBBezierCurve *us = self;
    FBBezierCurve *them = curve;
    
    NSUInteger iterations = 0;
    while ( iterations < maxIterations && !FBRangeHasConverged(*usRange, places) && !FBRangeHasConverged(*themRange, places) ) {
        FBRange previousUsRange = *usRange;
        FBRange previousThemRange = *themRange;
        
        us = [us bezierClipWithBezierCurve:them rangeOfOriginal:usRange];
        them = [them bezierClipWithBezierCurve:us rangeOfOriginal:themRange];
        
        // See if either of curves ranges is reduced by less than 20%.
        CGFloat percentChangeInUs = (FBRangeGetSize(previousUsRange) - FBRangeGetSize(*usRange)) / FBRangeGetSize(previousUsRange);
        CGFloat percentChangeInThem = (FBRangeGetSize(previousThemRange) - FBRangeGetSize(*themRange)) / FBRangeGetSize(previousThemRange);
        if ( percentChangeInUs < minimumChangeNeeded || percentChangeInThem < minimumChangeNeeded ) {
            // We're not converging fast enough, likely because there are multiple intersections here. So
            //  divide and conquer. Divide the longer curve in half, and recurse
            if ( FBRangeGetSize(*usRange) > FBRangeGetSize(*themRange) ) {
                NSArray *splitCurves = [us splitCurveAtParameter:0.5]; // just split it in two
                FBRange usRange1 = FBRangeMake(usRange->minimum, usRange->minimum + FBRangeGetSize(*usRange) / 2.0);
                FBRange usRange2 = FBRangeMake(usRange->minimum + FBRangeGetSize(*usRange) / 2.0, usRange->maximum);
                NSArray *intersections1 = [[splitCurves objectAtIndex:0] intersectionsWithBezierCurve:them usRange:&usRange1 themRange:themRange originalUs:originalUs originalThem:originalThem];
                NSArray *intersections2 = [[splitCurves objectAtIndex:0] intersectionsWithBezierCurve:them usRange:&usRange2 themRange:themRange originalUs:originalUs originalThem:originalThem];
                return [intersections1 arrayByAddingObjectsFromArray:intersections2];
            } else {
                NSArray *splitCurves = [them splitCurveAtParameter:0.5];
                FBRange themRange1 = FBRangeMake(themRange->minimum, themRange->minimum + FBRangeGetSize(*themRange) / 2.0);
                FBRange themRange2 = FBRangeMake(themRange->minimum + FBRangeGetSize(*themRange) / 2.0, themRange->maximum);
                NSArray *intersections1 = [us intersectionsWithBezierCurve:[splitCurves objectAtIndex:0] usRange:usRange themRange:&themRange1 originalUs:originalUs originalThem:originalThem];
                NSArray *intersections2 = [us intersectionsWithBezierCurve:[splitCurves objectAtIndex:1] usRange:usRange themRange:&themRange2 originalUs:originalUs originalThem:originalThem];
                return [intersections1 arrayByAddingObjectsFromArray:intersections2];
            }
        }
        
        iterations++;
    }
        
    return [NSArray arrayWithObject:[FBBezierIntersection intersectionWithCurve1:originalUs parameter1:usRange->minimum curve2:originalThem parameter2:themRange->minimum]];
}

- (FBBezierCurve *) bezierClipWithBezierCurve:(FBBezierCurve *)curve rangeOfOriginal:(FBRange *)originalRange
{
    // Clip self with fat line from curve
    FBNormalizedLine fatLine = [curve fatLine];
    FBRange fatLineBounds = [curve boundsOfFatLine:fatLine];
    FBRange clippedRange = [self clipWithFatLine:fatLine bounds:fatLineBounds];
    
    // Map the newly clipped range onto the original range
    FBRange newRange = FBRangeMake(FBRangeScaleNormalizedValue(*originalRange, clippedRange.minimum), FBRangeScaleNormalizedValue(*originalRange, clippedRange.maximum));
    *originalRange = newRange;
    
    // Actually divide the curve
    return [self subcurveWithRange:clippedRange];
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

- (FBRange) clipWithFatLine:(FBNormalizedLine)fatLine bounds:(FBRange)bounds
{
    // First calculate bezier curve points distance from the fat line that's clipping us
    FBBezierCurve *distanceBezier = [FBBezierCurve bezierCurveWithEndPoint1:NSMakePoint(0, FBNormalizedLineDistanceFromPoint(fatLine, _endPoint1)) controlPoint1:NSMakePoint(1.0/3.0, FBNormalizedLineDistanceFromPoint(fatLine, _controlPoint1)) controlPoint2:NSMakePoint(2.0/3.0, FBNormalizedLineDistanceFromPoint(fatLine, _controlPoint2)) endPoint2:NSMakePoint(1.0, FBNormalizedLineDistanceFromPoint(fatLine, _endPoint2))];
    NSArray *convexHull = [distanceBezier convexHull];
    
    // Find intersections of convex hull with bounds
    FBRange range = FBRangeMake(1.0, 0.0);
    for (NSUInteger i = 0; i < [convexHull count]; i++) {
        NSUInteger indexOfNext = i < ([convexHull count] - 1) ? i + 1 : 0;
        NSPoint startPoint = [[convexHull objectAtIndex:i] pointValue];
        NSPoint endPoint = [[convexHull objectAtIndex:indexOfNext] pointValue];
        NSPoint intersectionPoint = NSZeroPoint;
        
        if ( LineIntersectsHorizontalLine(startPoint, endPoint, bounds.minimum, &intersectionPoint) ) {
            if ( intersectionPoint.x < range.minimum )
                range.minimum = intersectionPoint.x;
            if ( intersectionPoint.x > range.maximum )
                range.maximum = intersectionPoint.x;
        }
        if ( LineIntersectsHorizontalLine(startPoint, endPoint, bounds.maximum, &intersectionPoint) ) {
            if ( intersectionPoint.x < range.minimum )
                range.minimum = intersectionPoint.x;
            if ( intersectionPoint.x > range.maximum )
                range.maximum = intersectionPoint.x;
        }
    }
    return range;
}

- (FBBezierCurve *) subcurveWithRange:(FBRange)range
{
    NSArray *curves1 = [self splitCurveAtParameter:range.minimum];
    NSArray *curves2 = [self splitCurveAtParameter:range.maximum];
    
    FBBezierCurve *rightCurve = [curves1 objectAtIndex:1];
    FBBezierCurve *leftCurve = [curves2 objectAtIndex:0];
    
    return [FBBezierCurve bezierCurveWithEndPoint1:rightCurve.endPoint1 controlPoint1:rightCurve.controlPoint1 controlPoint2:leftCurve.controlPoint2 endPoint2:leftCurve.endPoint2];
}

- (NSPoint) pointAtParameter:(CGFloat)parameter controlPoint1:(NSPoint *)controlPoint1 controlPoint2:(NSPoint *)controlPoint2
{
    // Calculate a point on the bezier curve passed in, specifically the point at parameter.
    //  We could just plug parameter into the Q(t) formula shown in the fb_fitBezierInRange: comments.
    //  However, that method isn't numerically stable, meaning it amplifies any errors, which is bad
    //  seeing we're using floating point numbers with limited precision. Instead we'll use
    //  De Casteljau's algorithm.
    //
    // See: http://www.cs.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/de-casteljau.html
    //  for an explaination of De Casteljau's algorithm.
    
    // With this algorithm we start out with the points in the bezier path. 
    NSUInteger degree = 3; // We're a cubic bezier
    NSPoint points[4] = { _endPoint1, _controlPoint1, _controlPoint2, _endPoint2 };
    NSPoint tangents[2] = {};
    
    for (NSUInteger k = 1; k <= degree; k++) {
        for (NSUInteger i = 0; i <= (degree - k); i++) {
            points[i].x = (1.0 - parameter) * points[i].x + parameter * points[i + 1].x;
            points[i].y = (1.0 - parameter) * points[i].y + parameter * points[i + 1].y;            
        }
        
        // Save off the tangents
        if ( k == (degree - 1) ) {
            tangents[0] = points[0];
            tangents[1] = points[1];
        }
    }
    
    // The point in the curve at parameter ends up in points[0]
    *controlPoint1 = tangents[0];
    *controlPoint2 = tangents[1];
    return points[0];
}

- (NSArray *) splitCurveAtParameter:(CGFloat)parameter
{
    NSPoint controlPoint1 = NSZeroPoint;
    NSPoint controlPoint2 = NSZeroPoint;
    NSPoint intersectionPoint = [self pointAtParameter:parameter controlPoint1:&controlPoint1 controlPoint2:&controlPoint2];
    FBBezierCurve *leftCurve = [FBBezierCurve bezierCurveWithEndPoint1:_endPoint1 controlPoint1:_controlPoint1 controlPoint2:controlPoint1 endPoint2:intersectionPoint];
    FBBezierCurve *rightCurve = [FBBezierCurve bezierCurveWithEndPoint1:intersectionPoint controlPoint1:controlPoint2 controlPoint2:_controlPoint2 endPoint2:_endPoint2];
    return [NSArray arrayWithObjects:leftCurve, rightCurve, nil];
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
