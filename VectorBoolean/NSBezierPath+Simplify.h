//
//  NSBezierPath+Simplify.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/27/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSBezierPath (Simplify)

- (NSBezierPath *) fb_simplify:(CGFloat)threshold;

@end
