//
//  Canvas.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "Canvas.h"


@implementation Canvas

- (id)init
{
    self = [super init];
    if (self) {
        _paths = [[NSMutableArray alloc] initWithCapacity:3];
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
}

@end
