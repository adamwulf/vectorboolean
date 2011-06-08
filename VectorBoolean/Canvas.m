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
        NSArray *curves1 = [FBBezierCurve bezierCurvesFromBezierPath:path1];
        NSArray *curves2 = [FBBezierCurve bezierCurvesFromBezierPath:path2];
        
        for (FBBezierCurve *curve1 in curves1) {
            for (FBBezierCurve *curve2 in curves2) {
                NSArray *intersections = [curve1 intersectionsWithBezierCurve:curve2];
                for (FBBezierIntersection *intersection in intersections) {
                    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:BoxFrame(intersection.location)];
                    [circle stroke];
                }
            }
        }
    }
}

@end
