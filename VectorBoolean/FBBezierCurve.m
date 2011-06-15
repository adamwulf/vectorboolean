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

static BOOL AreValuesClose(CGFloat value1, CGFloat value2)
{
    static const CGFloat FBPointClosenessThreshold = 1e-10;
    
    CGFloat delta = value1 - value2;    
    return (delta <= FBPointClosenessThreshold) && (delta >= -FBPointClosenessThreshold);
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

- (FBNormalizedLine) regularFatLineBounds:(FBRange *)range;
- (FBNormalizedLine) perpendicularFatLineBounds:(FBRange *)range;

- (FBRange) clipWithFatLine:(FBNormalizedLine)fatLine bounds:(FBRange)bounds;
- (FBBezierCurve *) subcurveWithRange:(FBRange)range;
- (NSArray *) splitCurveAtParameter:(CGFloat)t;
- (NSArray *) convexHull;
- (FBBezierCurve *) bezierClipWithBezierCurve:(FBBezierCurve *)curve original:(FBBezierCurve *)originalCurve rangeOfOriginal:(FBRange *)originalRange intersects:(BOOL *)intersects;
- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve usRange:(FBRange *)usRange themRange:(FBRange *)themRange originalUs:(FBBezierCurve *)originalUs originalThem:(FBBezierCurve *)originalThem;

@property (readonly, getter = isPoint) BOOL point;

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
                //  by the end points
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
    static const NSUInteger places = 6;
    static const NSUInteger maxIterations = 500;
    static const CGFloat minimumChangeNeeded = 0.20;
    
    FBBezierCurve *us = self;
    FBBezierCurve *them = curve;
    FBBezierCurve *previousUs = us;
    FBBezierCurve *previousThem = them;
    
    // Don't check for convergence until we actually see if we intersect or not. i.e. Make sure we go through at least once, otherwise the results
    //  don't mean anything
    NSUInteger iterations = 0;
    while ( iterations < maxIterations && ((iterations == 0) || (!FBRangeHasConverged(*usRange, places) && !FBRangeHasConverged(*themRange, places))) ) {
        FBRange previousUsRange = *usRange;
        FBRange previousThemRange = *themRange;
        
        BOOL intersects = NO;
        us = [us bezierClipWithBezierCurve:them.isPoint ? previousThem : them original:originalUs rangeOfOriginal:usRange intersects:&intersects];
        if ( !intersects )
            return [NSArray array];
        them = [them bezierClipWithBezierCurve:us.isPoint ? previousUs : us original:originalThem rangeOfOriginal:themRange intersects:&intersects];
        if ( !intersects )
            return [NSArray array];
        
        if ( us.isPoint || them.isPoint )
            break;
        
        // See if either of curves ranges is reduced by less than 20%.
        CGFloat percentChangeInUs = (FBRangeGetSize(previousUsRange) - FBRangeGetSize(*usRange)) / FBRangeGetSize(previousUsRange);
        CGFloat percentChangeInThem = (FBRangeGetSize(previousThemRange) - FBRangeGetSize(*themRange)) / FBRangeGetSize(previousThemRange);
        if ( percentChangeInUs < minimumChangeNeeded && percentChangeInThem < minimumChangeNeeded ) {
            // We're not converging fast enough, likely because there are multiple intersections here. So
            //  divide and conquer. Divide the longer curve in half, and recurse
            if ( FBRangeGetSize(*usRange) > FBRangeGetSize(*themRange) ) {
                FBRange usRange1 = FBRangeMake(usRange->minimum, (usRange->minimum + usRange->maximum) / 2.0);
                FBBezierCurve *us1 = [originalUs subcurveWithRange:usRange1];
                FBRange themRangeCopy1 = *themRange;

                FBRange usRange2 = FBRangeMake((usRange->minimum + usRange->maximum) / 2.0, usRange->maximum);
                FBBezierCurve *us2 = [originalUs subcurveWithRange:usRange2];
                FBRange themRangeCopy2 = *themRange;
                
                NSArray *intersections1 = [us1 intersectionsWithBezierCurve:them usRange:&usRange1 themRange:&themRangeCopy1 originalUs:originalUs originalThem:originalThem];
                NSArray *intersections2 = [us2 intersectionsWithBezierCurve:them usRange:&usRange2 themRange:&themRangeCopy2 originalUs:originalUs originalThem:originalThem];
                
                return [intersections1 arrayByAddingObjectsFromArray:intersections2];
            } else {
                FBRange themRange1 = FBRangeMake(themRange->minimum, (themRange->minimum + themRange->maximum) / 2.0);
                FBBezierCurve *them1 = [originalThem subcurveWithRange:themRange1];
                FBRange usRangeCopy1 = *usRange;

                FBRange themRange2 = FBRangeMake((themRange->minimum + themRange->maximum) / 2.0, themRange->maximum);
                FBBezierCurve *them2 = [originalThem subcurveWithRange:themRange2];
                FBRange usRangeCopy2 = *usRange;

                NSArray *intersections1 = [us intersectionsWithBezierCurve:them1 usRange:&usRangeCopy1 themRange:&themRange1 originalUs:originalUs originalThem:originalThem];
                NSArray *intersections2 = [us intersectionsWithBezierCurve:them2 usRange:&usRangeCopy2 themRange:&themRange2 originalUs:originalUs originalThem:originalThem];
                
                return [intersections1 arrayByAddingObjectsFromArray:intersections2];
            }
        }
        
        iterations++;
        previousUs = us;
        previousThem = them;
    }
        
    return [NSArray arrayWithObject:[FBBezierIntersection intersectionWithCurve1:originalUs parameter1:usRange->minimum curve2:originalThem parameter2:themRange->minimum]];
}

- (FBBezierCurve *) bezierClipWithBezierCurve:(FBBezierCurve *)curve original:(FBBezierCurve *)originalCurve rangeOfOriginal:(FBRange *)originalRange intersects:(BOOL *)intersects
{
    // Clip self with fat line from curve
    FBRange fatLineBounds = {};
    FBNormalizedLine fatLine = [curve regularFatLineBounds:&fatLineBounds];
    FBRange regularClippedRange = [self clipWithFatLine:fatLine bounds:fatLineBounds];
    if ( regularClippedRange.minimum == 1.0 && regularClippedRange.maximum == 0.0 ) {
        *intersects = NO;
        return self;
    }
    
    // Just in case the regular fat line isn't good enough, try the perpendicular one
    FBRange perpendicularLineBounds = {};
    FBNormalizedLine perpendicularLine = [curve perpendicularFatLineBounds:&perpendicularLineBounds];
    FBRange perpendicularClippedRange = [self clipWithFatLine:perpendicularLine bounds:perpendicularLineBounds];
    if ( perpendicularClippedRange.minimum == 1.0 && perpendicularClippedRange.maximum == 0.0 ) {
        *intersects = NO;
        return self;
    }
    
    // Combine to form Voltron
    FBRange clippedRange = FBRangeMake(MAX(regularClippedRange.minimum, perpendicularClippedRange.minimum), MIN(regularClippedRange.maximum, perpendicularClippedRange.maximum));    
    
    // Map the newly clipped range onto the original range
    FBRange newRange = FBRangeMake(FBRangeScaleNormalizedValue(*originalRange, clippedRange.minimum), FBRangeScaleNormalizedValue(*originalRange, clippedRange.maximum));
    *originalRange = newRange;
    *intersects = YES;
    
    // Actually divide the curve
    return [originalCurve subcurveWithRange:*originalRange];
}

- (FBNormalizedLine) regularFatLineBounds:(FBRange *)range
{
    FBNormalizedLine line = FBNormalizedLineMake(_endPoint1, _endPoint2);
    
    CGFloat controlPoint1Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint1);
    CGFloat controlPoint2Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint2);    
    CGFloat min = MIN(controlPoint1Distance, MIN(controlPoint2Distance, 0.0));
    CGFloat max = MAX(controlPoint1Distance, MAX(controlPoint2Distance, 0.0));
        
    *range = FBRangeMake(min, max);
    
    return line;
}

- (FBNormalizedLine) perpendicularFatLineBounds:(FBRange *)range
{
    NSPoint normal = FBLineNormal(_endPoint1, _endPoint2);
    NSPoint startPoint = FBLineMidpoint(_endPoint1, _endPoint2);
    NSPoint endPoint = FBAddPoint(startPoint, normal);
    FBNormalizedLine line = FBNormalizedLineMake(startPoint, endPoint);
    
    CGFloat controlPoint1Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint1);
    CGFloat controlPoint2Distance = FBNormalizedLineDistanceFromPoint(line, _controlPoint2);
    CGFloat point1Distance = FBNormalizedLineDistanceFromPoint(line, _endPoint1);
    CGFloat point2Distance = FBNormalizedLineDistanceFromPoint(line, _endPoint2);

    CGFloat min = MIN(controlPoint1Distance, MIN(controlPoint2Distance, MIN(point1Distance, point2Distance)));
    CGFloat max = MAX(controlPoint1Distance, MAX(controlPoint2Distance, MAX(point1Distance, point2Distance)));
    
    *range = FBRangeMake(min, max);
    
    return line;
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
        
        // We want to be able to refine t even if the convex hull lies completely inside the bounds. This
        //  also allows us to be able to use range of [1..0] as a sentinel value meaning the convex hull
        //  lies entirely outside of bounds, and the curves don't intersect.
        if ( startPoint.y < bounds.maximum && startPoint.y > bounds.minimum ) {
            if ( startPoint.x < range.minimum )
                range.minimum = startPoint.x;
            if ( startPoint.x > range.maximum )
                range.maximum = startPoint.x;
        }
    }
    return range;
}

- (FBBezierCurve *) subcurveWithRange:(FBRange)range
{
    NSArray *curves1 = [self splitCurveAtParameter:range.minimum];
    FBBezierCurve *upperCurve = [curves1 objectAtIndex:1];
    CGFloat adjustedMaximum = (range.maximum - range.minimum) / (1.0 - range.minimum);
    NSArray *curves2 = [upperCurve splitCurveAtParameter:adjustedMaximum];
    return [curves2 objectAtIndex:0];
}

- (NSPoint) pointAtParameter:(CGFloat)parameter leftBezierCurve:(FBBezierCurve **)leftBezierCurve rightBezierCurve:(FBBezierCurve **)rightBezierCurve
{    
    // Calculate a point on the bezier curve passed in, specifically the point at parameter.
    //  However, that method isn't numerically stable, meaning it amplifies any errors, which is bad
    //  seeing we're using floating point numbers with limited precision. Instead we'll use
    //  De Casteljau's algorithm.
    //
    // See: http://www.cs.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/de-casteljau.html
    //  for an explaination of De Casteljau's algorithm.
    
    // With this algorithm we start out with the points in the bezier path. 
    NSUInteger degree = 3; // We're a cubic bezier
    NSPoint points[4] = { _endPoint1, _controlPoint1, _controlPoint2, _endPoint2 };
    NSPoint leftCurve[4] = { _endPoint1, NSZeroPoint, NSZeroPoint, NSZeroPoint };
    NSPoint rightCurve[4] = { NSZeroPoint, NSZeroPoint, NSZeroPoint, _endPoint2 };
    
    for (NSUInteger k = 1; k <= degree; k++) {
        for (NSUInteger i = 0; i <= (degree - k); i++) {
            points[i].x = (1.0 - parameter) * points[i].x + parameter * points[i + 1].x;
            points[i].y = (1.0 - parameter) * points[i].y + parameter * points[i + 1].y;            
        }
        
        leftCurve[k] = points[0];
        rightCurve[degree - k] = points[degree - k];
    }
    
    // The point in the curve at parameter ends up in points[0]
    if ( leftBezierCurve != nil )
        *leftBezierCurve = [FBBezierCurve bezierCurveWithEndPoint1:leftCurve[0] controlPoint1:leftCurve[1] controlPoint2:leftCurve[2] endPoint2:leftCurve[3]];
    if ( rightBezierCurve != nil )
        *rightBezierCurve = [FBBezierCurve bezierCurveWithEndPoint1:rightCurve[0] controlPoint1:rightCurve[1] controlPoint2:rightCurve[2] endPoint2:rightCurve[3]];
    return points[0];
}

- (NSArray *) splitCurveAtParameter:(CGFloat)parameter
{
    FBBezierCurve *leftCurve = nil;
    FBBezierCurve *rightCurve = nil;
    [self pointAtParameter:parameter leftBezierCurve:&leftCurve rightBezierCurve:&rightCurve];
    return [NSArray arrayWithObjects:leftCurve, rightCurve, nil];
}

- (NSArray *) convexHull
{
    // This is the Graham-Scan algorithm: http://en.wikipedia.org/wiki/Graham_scan
    NSMutableArray *points = [NSMutableArray arrayWithObjects:[NSValue valueWithPoint:_endPoint1], [NSValue valueWithPoint:_controlPoint1], [NSValue valueWithPoint:_controlPoint2], [NSValue valueWithPoint:_endPoint2], nil];
    
    // Find point with lowest y value. If tied, the one with lowest x. Then swap the lowest value
    //  to the first index
    NSUInteger lowestIndex = 0;
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
        CGFloat distance1 = FBDistanceBetweenPoints(point1, lowestValue);
        CGFloat cosine1 = (point1.x - lowestValue.x) / distance1;
        CGFloat distance2 = FBDistanceBetweenPoints(point2, lowestValue);
        CGFloat cosine2 = (point2.x - lowestValue.x) / distance2;
        if ( AreValuesClose(cosine1, cosine2) ) {
            if ( distance1 < distance2 )
                return NSOrderedAscending;
            else if ( distance1 > distance2 )
                return NSOrderedDescending;
            return NSOrderedSame;
        }
        if ( cosine1 < cosine2 )
            return NSOrderedDescending;
        else if ( cosine1 > cosine2 )
            return NSOrderedAscending;
        return NSOrderedSame;
    }];
    
    NSUInteger numberOfConvexHullPoints = 2;
    for (NSUInteger i = 2; i < [points count]; i++) {
        CGFloat area = CounterClockwiseTurn([[points objectAtIndex:numberOfConvexHullPoints - 2] pointValue], [[points objectAtIndex:numberOfConvexHullPoints - 1] pointValue], [[points objectAtIndex:i] pointValue]);
        
        if ( area == 0.0 )
            numberOfConvexHullPoints--; // colinear is bad
        else if ( area < 0.0 ) {
            while (area <= 0.0 && numberOfConvexHullPoints > 2) {
                numberOfConvexHullPoints--;
                area = CounterClockwiseTurn([[points objectAtIndex:numberOfConvexHullPoints - 2] pointValue], [[points objectAtIndex:numberOfConvexHullPoints - 1] pointValue], [[points objectAtIndex:i] pointValue]);
            }
        }
                
        [points exchangeObjectAtIndex:numberOfConvexHullPoints withObjectAtIndex:i];
        numberOfConvexHullPoints++;
    }
    
    return [points subarrayWithRange:NSMakeRange(0, numberOfConvexHullPoints)];
}

- (BOOL) isPoint
{
    return AreValuesClose(_endPoint1.x, _endPoint2.x) && AreValuesClose(_endPoint1.y, _endPoint2.y);
}

@end
