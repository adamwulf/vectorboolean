//
//  UIBezierPath+Utilities.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct UIBezierElement {
    CGPathElementType kind;
    CGPoint point;
    CGPoint controlPoints[2];
} UIBezierElement;

@interface UIBezierPath (FBUtilities)

- (CGPoint) fb_pointAtIndex:(NSUInteger)index;
- (UIBezierElement) fb_elementAtIndex:(NSUInteger)index;

- (UIBezierPath *) fb_subpathWithRange:(NSRange)range;

- (void) fb_copyAttributesFrom:(UIBezierPath *)path;
- (void) fb_appendPath:(UIBezierPath *)path;
- (void) fb_appendElement:(UIBezierElement)element;

+ (UIBezierPath *) circleAtPoint:(CGPoint)point;
+ (UIBezierPath *) rectAtPoint:(CGPoint)point;
+ (UIBezierPath *) triangleAtPoint:(CGPoint)point direction:(CGPoint)tangent;
+ (UIBezierPath *) smallCircleAtPoint:(CGPoint)point;
+ (UIBezierPath *) smallRectAtPoint:(CGPoint)point;

@end
