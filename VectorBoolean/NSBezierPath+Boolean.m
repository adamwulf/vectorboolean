//
//  NSBezierPath+Boolean.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+Boolean.h"


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
