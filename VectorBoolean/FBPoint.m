//
//  FBPoint.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBPoint.h"


@implementation FBPoint

@synthesize next=_next;
@synthesize previous=_previous;
@synthesize neighbor=_neighbor;
@synthesize location=_location;
@synthesize relativeDistance=_relativeDistance;
@synthesize intersection=_intersection;
@synthesize entry=_entry;

- (id) initWithLocation:(NSPoint)location
{
    self = [super init];
    
    if ( self != nil ) {
        _location = location;
    }
    
    return self;
}

@end

///////////////////////////////////////////////////////////////

@implementation FBPointList

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
    [self insertPoint:point after:_tail];
}

- (void) insertPoint:(FBPoint *)point after:(FBPoint *)location
{
    [_points addObject:point]; // add a ref to keep it around
    
    // Determine the true insert location for intersection points.
    if ( point.isIntersection ) {
        // If the next point is an intersection, and is closer to location
        //  the we should insert after that point.
        while ( location.next.isIntersection && location.next.relativeDistance < point.relativeDistance )
            location = location.next;
    }
    
    // Insert it into the list
    if ( _head == nil ) {
        // No points yet
        _head = point;
        _tail = point;
        point.previous = nil;
        point.next = nil;
    } else if ( location == nil ) {
        // Insert at the beginning
        point.previous = nil;
        point.next = _head;
        _head.previous = point;
        _head = point;
    } else if ( location == _tail ) {        
        // insert at the end
        point.next = nil;
        point.previous = _tail;
        _tail.next = point;
        _tail = point;
    } else {
        point.previous = location;
        point.next = location.next;
        location.next = point;
        point.next.previous = point;
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
