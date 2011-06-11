//
//  Canvas.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "Canvas.h"
#import "NSBezierPath+Utilities.h"
#import "FBBezierCurve.h"
#import "FBBezierIntersection.h"

static NSRect BoxFrame(NSPoint point)
{
    return NSMakeRect(floorf(point.x - 2) - 0.5, floorf(point.y - 2) - 0.5, 5, 5);
}

@implementation Canvas

- (id)init
{
    self = [super init];
    if (self) {
        _paths = [[NSMutableArray alloc] initWithCapacity:3];
        _showPoints = YES;
        _showIntersections = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [_paths release];

    [super dealloc];
}

- (void) addPath:(NSBezierPath *)path withColor:(NSColor *)color
{
    NSDictionary *object = [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", color, @"color", nil];
    [_paths addObject:object];
}

- (NSUInteger) numberOfPaths
{
    return [_paths count];
}

- (NSBezierPath *) pathAtIndex:(NSUInteger)index
{
    NSDictionary *object = [_paths objectAtIndex:index];
    return [object objectForKey:@"path"];
}

- (void) clear
{
    [_paths removeAllObjects];
}

- (void) drawRect:(NSRect)dirtyRect
{
    // Draw on a background
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:dirtyRect];
    
    // Draw on the objects
    for (NSDictionary *object in _paths) {
        NSColor *color = [object objectForKey:@"color"];
        NSBezierPath *path = [object objectForKey:@"path"];
        [color set];
        [path fill];
    }    
    
    if ( _showPoints ) {
        for (NSDictionary *object in _paths) {
            NSBezierPath *path = [object objectForKey:@"path"];
            [NSBezierPath setDefaultLineWidth:1.0];
            [NSBezierPath setDefaultLineCapStyle:NSButtLineCapStyle];
            [NSBezierPath setDefaultLineJoinStyle:NSMiterLineJoinStyle];
            
            for (NSInteger i = 0; i < [path elementCount]; i++) {
                NSBezierElement element = [path fb_elementAtIndex:i];
                [[NSColor orangeColor] set];
                [NSBezierPath strokeRect:BoxFrame(element.point)];
                if ( element.kind == NSCurveToBezierPathElement ) {
                    [[NSColor blackColor] set];
                    [NSBezierPath strokeRect:BoxFrame(element.controlPoints[0])];                    
                    [NSBezierPath strokeRect:BoxFrame(element.controlPoints[1])];                    
                }
            }
        }
    }

    if ( _showIntersections && [_paths count] == 2 ) {
        [[NSColor greenColor] set];

        NSBezierPath *path1 = [[_paths objectAtIndex:0] objectForKey:@"path"];
        NSBezierPath *path2 = [[_paths objectAtIndex:1] objectForKey:@"path"];
        NSArray *curves1 = [FBBezierCurve bezierCurvesFromBezierPath:path1]; // rectangle
        NSArray *curves2 = [FBBezierCurve bezierCurvesFromBezierPath:path2]; // circle
        
#if 1
        FBBezierCurve *line = [curves1 objectAtIndex:2];
        FBBezierCurve *arc = [curves2 objectAtIndex:0];
        NSArray *intersections = [line intersectionsWithBezierCurve:arc];
        FBBezierIntersection *intersection = [intersections objectAtIndex:0];
        
        NSPoint curve1ControlPoint1 = NSZeroPoint;
        NSPoint curve1ControlPoint2 = NSZeroPoint;
        NSPoint curve1Intersection = [intersection.curve1 pointAtParameter:intersection.parameter1 controlPoint1:&curve1ControlPoint1 controlPoint2:&curve1ControlPoint2];

        NSPoint curve2ControlPoint1 = NSZeroPoint;
        NSPoint curve2ControlPoint2 = NSZeroPoint;
        NSPoint curve2Intersection = [intersection.curve2 pointAtParameter:intersection.parameter2 controlPoint1:&curve2ControlPoint1 controlPoint2:&curve2ControlPoint2];

        NSPoint calculatedIntersection = NSMakePoint(line.endPoint1.x + (line.endPoint2.x - line.endPoint1.x) * intersection.parameter1, line.endPoint1.y);
        CGFloat correctedParameter = (curve2Intersection.x - line.endPoint1.x) / (line.endPoint2.x - line.endPoint1.x);
        
        NSLog(@"intersections: %@, curve1 %f, %f, curve2 %f, %f, calculated %f, %f; t %f, corrected t: %f", intersections, 
              curve1Intersection.x, curve1Intersection.y,
              curve2Intersection.x, curve2Intersection.y,
              calculatedIntersection.x, calculatedIntersection.y,
              intersection.parameter1, correctedParameter);
#else
        for (FBBezierCurve *curve1 in curves1) {
            for (FBBezierCurve *curve2 in curves2) {
                NSArray *intersections = [curve1 intersectionsWithBezierCurve:curve2];
                for (FBBezierIntersection *intersection in intersections) {
                    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:BoxFrame(intersection.location)];
                    [circle stroke];
                }
            }
        }
#endif
    }
}

@end
