//
//  Canvas.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Canvas : NSObject {
    NSMutableArray *_paths;
    BOOL _showPoints;
    BOOL _showIntersections;
}

- (void) addPath:(NSBezierPath *)path withColor:(NSColor *)color;
- (void) clear;

- (NSUInteger) numberOfPaths;
- (NSBezierPath *) pathAtIndex:(NSUInteger)index;

- (void) drawRect:(NSRect)dirtyRect;

@property BOOL showPoints;
@property BOOL showIntersections;

@end
