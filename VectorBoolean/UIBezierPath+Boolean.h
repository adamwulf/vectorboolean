//
//  UIBezierPath+Boolean.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UIBezierPath (Boolean)

- (UIBezierPath *) fb_union:(UIBezierPath *)path;
- (UIBezierPath *) fb_intersect:(UIBezierPath *)path;
- (UIBezierPath *) fb_difference:(UIBezierPath *)path;
- (UIBezierPath *) fb_xor:(UIBezierPath *)path;

@end
