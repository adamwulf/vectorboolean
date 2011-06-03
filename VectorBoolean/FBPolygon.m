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
