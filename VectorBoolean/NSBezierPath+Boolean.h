//
//  NSBezierPath+Boolean.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath (Boolean)

- (NSBezierPath *) fb_union:(NSBezierPath *)path;
- (NSBezierPath *) fb_intersect:(NSBezierPath *)path;
- (NSBezierPath *) fb_difference:(NSBezierPath *)path;
- (NSBezierPath *) fb_xor:(NSBezierPath *)path;

@end
