//
//  NSBezierPath+Boolean.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+Boolean.h"
#import "NSBezierPath+FitCurve.h"
#import "NSBezierPath+Utilities.h"

@interface FBPoint : NSObject {
    FBPoint *_next;
    FBPoint *_previous;
    FBPoint *_neighbor;
    NSPoint _location;
    BOOL _intersection;
    BOOL _entry;
    CGFloat _relativeDistance;
}

- (id) initWithLocation:(NSPoint)location;

@property (assign) FBPoint *next;
@property (assign) FBPoint *previous;
@property NSPoint location;

@end

@interface FBPolygon : NSObject {
    FBPoint *_head;
    FBPoint *_tail;
    NSMutableArray *_points;
}

- (void) addPoint:(FBPoint *)point;

- (void) enumeratePointsWithBlock:(void (^)(FBPoint *point, BOOL *stop))block;

@end

@interface NSBezierPath (BooleanPrivate)

- (NSArray *) fb_polygons;
- (NSBezierPath *) fb_bezierPathFromPolygons:(NSArray *)polygons;

@end

@implementation FBPoint

@synthesize next=_next;
@synthesize previous=_previous;
@synthesize location=_location;

- (id) initWithLocation:(NSPoint)location
{
    self = [super init];
    
    if ( self != nil ) {
        _location = location;
    }
    
    return self;
}

@end

@implementation FBPolygon

- (id) init
{
    self = [super init];
    
    if ( self != nil ) {
        _points = [[NSMutableArray alloc] initWithCapacity:20];
    }
    
    return self;
}

- (void) dealloc
{
    [_points release];
    
    [super dealloc];
}

- (void) addPoint:(FBPoint *)point
{
    [_points addObject:point]; // add a ref to keep it around
    
    if ( _head == nil ) {
        // No points yet
        _head = point;
        _tail = point;
        point.previous = nil;
        point.next = nil;
    } else {
        point.next = nil;
        point.previous = _tail;
        _tail.next = point;
        _tail = point;
    }
}

- (void) enumeratePointsWithBlock:(void (^)(FBPoint *point, BOOL *stop))block
{
    FBPoint *current = _head;
    BOOL stop = NO;
    while ( !stop && current != nil ) {
        block(current, &stop);
        
        current = current.next;
    }
}

@end

@implementation NSBezierPath (Boolean)

- (NSBezierPath *) fb_union:(NSBezierPath *)path
{
    return self;
}

- (NSBezierPath *) fb_intersect:(NSBezierPath *)path
{
    
    return self;
}

- (NSBezierPath *) fb_difference:(NSBezierPath *)path
{
    return self;
}

- (NSBezierPath *) fb_xor:(NSBezierPath *)path
{
    return self;
}

@end

@implementation NSBezierPath (BooleanPrivate)

- (NSArray *) fb_polygons
{
    NSMutableArray *polygons = [NSMutableArray arrayWithCapacity:2];
    FBPolygon *polygon = nil;
    
    NSBezierPath *flatPath = [self bezierPathByFlatteningPath];
    for (NSUInteger i = 0; i < [flatPath elementCount]; i++) {
        NSBezierElement element = [flatPath fb_elementAtIndex:i];
        if ( element.kind == NSMoveToBezierPathElement ) {
            polygon = [[[FBPolygon alloc] init] autorelease];
            [polygons addObject:polygon];
        }
        
        if ( element.kind == NSMoveToBezierPathElement || element.kind == NSLineToBezierPathElement ) 
            [polygon addPoint:[[[FBPoint alloc] initWithLocation:element.point] autorelease]];
    }
    
    return polygons;
}

- (NSBezierPath *) fb_bezierPathFromPolygons:(NSArray *)polygons
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path fb_copyAttributesFrom:self];
    
    for (FBPolygon *polygon in polygons) {
        __block BOOL firstPoint = YES;
        [polygon enumeratePointsWithBlock:^(FBPoint *point, BOOL *stop) {
            if ( firstPoint ) {
                [path moveToPoint:point.location];
                firstPoint = NO;
            } else
                [path lineToPoint:point.location];
        }];
    }
    
    return [path fb_fitCurve:2];
}

@end
