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
