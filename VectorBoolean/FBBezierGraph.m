//
//  FBBezierGraph.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierGraph.h"
#import "FBBezierCurve.h"
#import "NSBezierPath+Utilities.h"
#import "FBBezierContour.h"
#import "FBContourEdge.h"
#import "FBBezierIntersection.h"
#import "FBEdgeCrossing.h"

@interface FBBezierGraph ()

- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other;

@property (readonly) NSArray *contours;

@end

@implementation FBBezierGraph

@synthesize contours=_contours;

+ (id) bezierGraphWithBezierPath:(NSBezierPath *)path
{
    return [[[FBBezierGraph alloc] initWithBezierPath:path] autorelease];
}

- (id) initWithBezierPath:(NSBezierPath *)path
{
    self = [super init];
    
    if ( self != nil ) {
        NSPoint lastPoint = NSZeroPoint;
        _contours = [[NSMutableArray alloc] initWithCapacity:2];
            
        FBBezierContour *contour = nil;
        for (NSUInteger i = 0; i < [path elementCount]; i++) {
            NSBezierElement element = [path fb_elementAtIndex:i];
            
            switch (element.kind) {
                case NSMoveToBezierPathElement:
                    // Start a new contour
                    contour = [[[FBBezierContour alloc] init] autorelease];
                    [_contours addObject:contour];
                    
                    lastPoint = element.point;
                    break;
                    
                case NSLineToBezierPathElement: {
                    // Convert lines to bezier curves as well. Just set control point to be in the line formed
                    //  by the end points
                    [contour addCurve:[FBBezierCurve bezierCurveWithLineStartPoint:lastPoint endPoint:element.point]];
                    
                    lastPoint = element.point;
                    break;
                }
                    
                case NSCurveToBezierPathElement:
                    [contour addCurve:[FBBezierCurve bezierCurveWithEndPoint1:lastPoint controlPoint1:element.controlPoints[0] controlPoint2:element.controlPoints[1] endPoint2:element.point]];
                    
                    lastPoint = element.point;
                    break;
                    
                case NSClosePathBezierPathElement:
                    lastPoint = NSZeroPoint;
                    break;
            }
        }
    }
    
    return self;
}

- (void)dealloc
{
    [_contours release];
    
    [super dealloc];
}

- (FBBezierGraph *) unionWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
}

- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
}

- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
}

- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph
{
    return self; // TODO: implement
}

- (NSBezierPath *) bezierPath
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    for (FBBezierContour *contour in _contours) {
        BOOL firstPoint = YES;        
        for (FBContourEdge *edge in contour.edges) {
            if ( firstPoint ) {
                [path moveToPoint:edge.curve.endPoint1];
                firstPoint = NO;
            }
            
            [path curveToPoint:edge.curve.endPoint2 controlPoint1:edge.curve.controlPoint1 controlPoint2:edge.curve.controlPoint2];
        }
    }
    
    return path;
}

- (BOOL) insertCrossingsWithBezierGraph:(FBBezierGraph *)other
{
    BOOL hasIntersection = NO;
    
    for (FBBezierContour *ourContour in self.contours) {
        for (FBContourEdge *ourEdge in ourContour.edges) {
            for (FBBezierContour *theirContour in other.contours) {
                for (FBContourEdge *theirEdge in theirContour.edges) {
                    NSArray *intersections = [ourEdge.curve intersectionsWithBezierCurve:theirEdge.curve];
                    for (FBBezierIntersection *intersection in intersections) {
                        FBEdgeCrossing *ourCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];
                        FBEdgeCrossing *theirCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];

                        ourCrossing.counterpart = theirCrossing;
                        theirCrossing.counterpart = ourCrossing;
                        
                        [ourEdge addCrossing:ourCrossing];
                        [theirEdge addCrossing:theirCrossing];
                        
                        hasIntersection = YES;
                    }
                }
            }
            
        }
    }
 
    return hasIntersection;
}

@end
