//
//  NSBezierPath+Boolean.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+Boolean.h"
#import "FBPolygon.h"
#import "NSBezierPath+Utilities.h"

@implementation NSBezierPath (Boolean)

- (NSBezierPath *) fb_union:(NSBezierPath *)path
{
    FBPolygon *thisPolygon = [[[FBPolygon alloc] initWithBezierPath:self] autorelease];
    FBPolygon *otherPolygon = [[[FBPolygon alloc] initWithBezierPath:path] autorelease];
    NSBezierPath *result = [[thisPolygon unionWithPolygon:otherPolygon] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (NSBezierPath *) fb_intersect:(NSBezierPath *)path
{
    FBPolygon *thisPolygon = [[[FBPolygon alloc] initWithBezierPath:self] autorelease];
    FBPolygon *otherPolygon = [[[FBPolygon alloc] initWithBezierPath:path] autorelease];
    NSBezierPath *result = [[thisPolygon intersectWithPolygon:otherPolygon] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (NSBezierPath *) fb_difference:(NSBezierPath *)path
{
    FBPolygon *thisPolygon = [[[FBPolygon alloc] initWithBezierPath:self] autorelease];
    FBPolygon *otherPolygon = [[[FBPolygon alloc] initWithBezierPath:path] autorelease];
    NSBezierPath *result = [[thisPolygon differenceWithPolygon:otherPolygon] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (NSBezierPath *) fb_xor:(NSBezierPath *)path
{
    FBPolygon *thisPolygon = [[[FBPolygon alloc] initWithBezierPath:self] autorelease];
    FBPolygon *otherPolygon = [[[FBPolygon alloc] initWithBezierPath:path] autorelease];
    NSBezierPath *result = [[thisPolygon xorWithPolygon:otherPolygon] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

@end
