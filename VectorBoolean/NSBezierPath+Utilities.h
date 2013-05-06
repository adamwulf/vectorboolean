//
//  NSBezierPath+Utilities.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct NSBezierElement {
    NSBezierPathElement kind;
    NSPoint point;
    NSPoint controlPoints[2];
} NSBezierElement;

@interface NSBezierPath (FBUtilities)

- (NSPoint) fb_pointAtIndex:(NSUInteger)index;
- (NSBezierElement) fb_elementAtIndex:(NSUInteger)index;

- (NSBezierPath *) fb_subpathWithRange:(NSRange)range;

- (void) fb_copyAttributesFrom:(NSBezierPath *)path;
- (void) fb_appendPath:(NSBezierPath *)path;
- (void) fb_appendElement:(NSBezierElement)element;

+ (NSBezierPath *) circleAtPoint:(NSPoint)point;
+ (NSBezierPath *) rectAtPoint:(NSPoint)point;
+ (NSBezierPath *) triangleAtPoint:(NSPoint)point direction:(NSPoint)tangent;
+ (NSBezierPath *) smallCircleAtPoint:(NSPoint)point;
+ (NSBezierPath *) smallRectAtPoint:(NSPoint)point;

@end
