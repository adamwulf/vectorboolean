//
//  FBPolygon.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBPolygon.h"
#import "NSBezierPath+FitCurve.h"
#import "NSBezierPath+Utilities.h"
#import "FBPoint.h"
#import "Geometry.h"

inline static NSPoint ComputeNormal(NSPoint lineStart, NSPoint lineEnd)
{
    return FBNormalizePoint(NSMakePoint(-(lineEnd.y - lineStart.y), lineEnd.x - lineStart.x));
}

inline static BOOL LinesIntersect(NSPoint line1Start, NSPoint line1End, NSPoint line2Start, NSPoint line2End, NSPoint *intersectPoint, CGFloat *relativeDistance1, CGFloat *relativeDistance2)
{
    // Based on Cyrus-Beck line clipping algorithm described in Computer Graphics: Principles and Practice by Foley, van Dam, et al
    //  Chapter 3, pp 117-119
    
    // Assume the line formed by line1Start, line1End is represented by the parametric function
    //  P(t) = line1Start + (line1End - line1Start) * t
    // Where t ranges from [0..1], and P(0) == line1Start and P(1) == line1End
    //
    // Assume N is a unit vector perpendicular to (line2Start, line2End), i.e. its normal.
    //  If we create a line from line2Start (the "arbitrary point" described in the book) to the intersection
    //  of line1 and line2 (called P(t)), that line will be colinear to line2, and thus perpendicular to the normal 
    //  as well. Thus, we can say
    //
    //  normal * (P(t) - line2Start) = 0
    //
    //  We can think substitute in our original defintion of P(t) to get
    //
    //  normal * ((line1Start + (line1End - line1Start) * t) - line2Start) = 0
    //
    //  Simplify:
    //
    //  normal * (line1Start - line2Start) + normal * (line1End - line1Start) * t
    //
    //  Solve for t:
    //
    //  t = (normal * (line1Start - line2Start)) / -(normal * (line1End - line1Start))
    //
    //  After solving for t, we can plug it back into P(t) to calculate the intersection point
    //  of the two lines. However, if t is outside the range [0..1] then it's not on the line
    //  segment defined by line1, so there's no intersection.
    
    NSPoint normal = ComputeNormal(line2End, line2Start);
    CGFloat denominator = FBDotMultiplyPoint(normal, FBSubtractPoint(line1End, line1Start));
    
    // If the dot product of the normal and line1 is 0, that means they are perpendicular. We already know
    //  the normal is perpendicular to line2, so if they are both perpendicular to the normal, they are
    //  parallel, and don't intersect. Also, divide by zero is bad.
    if ( denominator == 0.0 )
        return NO;
    
    CGFloat t = FBDotMultiplyPoint(normal, FBSubtractPoint(line1Start, line2Start)) / -denominator;
    
    if ( t < 0.0 || t > 1.0 )
        return NO; // No intersection on the line1 segment we care about
    
    NSPoint intersectionPoint = FBAddPoint(line1Start, FBScalePoint(FBSubtractPoint(line1End, line1Start), t));
    
    // We know the intersectionPoint lies on the line segment (line1Start, line1End) because t is in the range
    //  [0..1]. But does it lie on the line segment (line2Start, line2End)? Do a simple bounds check.
    if ( intersectionPoint.x < MIN(line2Start.x, line2End.x) || intersectionPoint.x > MAX(line2Start.x, line2End.x) || intersectionPoint.y < MIN(line2Start.y, line2End.y) || intersectionPoint.y > MAX(line2Start.y, line2End.y) )
        return NO;
    
    // We have an intersection for sure now. Fill in the out parameters
    *intersectPoint = intersectionPoint;
    *relativeDistance1 = FBDistanceBetweenPoints(line1Start, intersectionPoint) / FBDistanceBetweenPoints(line1Start, line1End);
    *relativeDistance2 = FBDistanceBetweenPoints(line2Start, intersectionPoint) / FBDistanceBetweenPoints(line2Start, line2End);
    
    return YES;
}

@interface FBPolygon ()

- (NSMutableArray *) insertIntersectionPointsWith:(FBPolygon *)otherPolygon;
- (void) enumeratePointsWithBlock:(void (^)(FBPointList *pointList, FBPoint *point, BOOL *stop))block;

@end

@implementation FBPolygon

- (id)init
{
    self = [super init];
    if (self != nil) {
        _subpolygons = [[NSMutableArray alloc] initWithCapacity:2];
    }
    
    return self;
}

- (id) initWithBezierPath:(NSBezierPath *)bezier
{
    self = [self init];
    
    if ( self != nil ) {
        // Normally there will only be one point list. However if the polygon has a hole,
        //  or has been cut in half completely (from a previous operation, perhaps), then
        //  there will be multiple. We use move to ops as a flag that we're starting a new
        //  point list.
        FBPointList *pointList = nil;
        NSBezierPath *flatPath = [bezier bezierPathByFlatteningPath];
        for (NSUInteger i = 0; i < [flatPath elementCount]; i++) {
            NSBezierElement element = [flatPath fb_elementAtIndex:i];
            if ( element.kind == NSMoveToBezierPathElement ) {
                pointList = [[[FBPointList alloc] init] autorelease];
                [_subpolygons addObject:pointList];
            }
            
            if ( element.kind == NSMoveToBezierPathElement || element.kind == NSLineToBezierPathElement ) 
                [pointList addPoint:[[[FBPoint alloc] initWithLocation:element.point] autorelease]];
        }        
    }
    
    return self;
}


- (void)dealloc
{
    [_subpolygons release];
    
    [super dealloc];
}

- (FBPolygon *) unionWithPolygon:(FBPolygon *)polygon
{
    return self; // TODO: implement
}

- (FBPolygon *) intersectWithPolygon:(FBPolygon *)polygon
{
    return self; // TODO: implement
}

- (FBPolygon *) differenceWithPolygon:(FBPolygon *)polygon
{
    return self; // TODO: implement
}

- (FBPolygon *) xorWithPolygon:(FBPolygon *)polygon
{
    FBPolygon *allParts = [self unionWithPolygon:polygon];
    FBPolygon *intersectingParts = [self intersectWithPolygon:polygon];
    return [allParts differenceWithPolygon:intersectingParts];
}

- (void) enumeratePointsWithBlock:(void (^)(FBPointList *pointList, FBPoint *point, BOOL *stop))block
{
    __block BOOL shouldStop = NO;
    for (FBPointList *pointList in _subpolygons) {
        [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            block(pointList, point, &shouldStop);
            if ( shouldStop )
                *stop = YES;
        }];
        if ( shouldStop )
            break;
    }
}

- (NSMutableArray *) insertIntersectionPointsWith:(FBPolygon *)clipPolygon
{
    NSMutableArray *intersectionPoints = [NSMutableArray arrayWithCapacity:20];
    
    [self enumeratePointsWithBlock:^(FBPointList *subjectPointList, FBPoint *subjectPoint, BOOL *subjectStop) {
        // Skip over intersection points
        if ( subjectPoint.isIntersection )
            return;
        
        [clipPolygon enumeratePointsWithBlock:^(FBPointList *clipPointList, FBPoint *clipPoint, BOOL *stop) {
            // Skip over intersection points
            if ( clipPoint.isIntersection )
                return;
            
            // First determine if the two line segments intersect
            CGFloat subjectDistance = 0.0;
            CGFloat clipDistance = 0.0;
            NSPoint intersectLocation = NSZeroPoint;
            BOOL linesIntersect = subjectPoint.next != nil && clipPoint.next != nil && LinesIntersect(subjectPoint.location, subjectPoint.next.location, clipPoint.location, clipPoint.next.location, &intersectLocation, &subjectDistance, &clipDistance);
            
            // If the line segments don't intersect, we're done here
            if ( !linesIntersect )
                return; // continue
                
            // Create an intersection point for each polygon
            FBPoint *subjectIntersectPoint = [[[FBPoint alloc] initWithLocation:intersectLocation] autorelease];
            FBPoint *clipIntersectPoint = [[[FBPoint alloc] initWithLocation:intersectLocation] autorelease];
            subjectIntersectPoint.intersection = YES;
            subjectIntersectPoint.relativeDistance = subjectDistance;
            subjectIntersectPoint.neighbor = clipIntersectPoint;
            clipIntersectPoint.intersection = YES;
            clipIntersectPoint.relativeDistance = clipDistance;
            clipIntersectPoint.neighbor = subjectIntersectPoint;
            
            // Insert the intersect points in their proper place (will we immediately hit them next?)
            [subjectPointList insertPoint:subjectIntersectPoint after:subjectPoint];
            [clipPointList insertPoint:clipIntersectPoint after:clipPoint];
            
            [intersectionPoints addObject:subjectIntersectPoint];
            [intersectionPoints addObject:clipIntersectPoint];            
        }];
    }];
        
    return intersectionPoints;
}

- (NSBezierPath *) bezierPath
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    for (FBPointList *pointList in _subpolygons) {
        __block BOOL firstPoint = YES;
        NSBezierPath *polygonPath = [NSBezierPath bezierPath];
        [pointList enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            if ( firstPoint ) {
                [polygonPath moveToPoint:point.location];
                firstPoint = NO;
            } else
                [polygonPath lineToPoint:point.location];
        }];
        [path appendBezierPath:[polygonPath fb_fitCurve:2]];
    }
    
    return path;
}

@end
