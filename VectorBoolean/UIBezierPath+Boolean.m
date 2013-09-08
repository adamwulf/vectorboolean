//
//  UIBezierPath+Boolean.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "UIBezierPath+Boolean.h"
#import "UIBezierPath+Utilities.h"
#import "FBBezierGraph.h"

@implementation UIBezierPath (Boolean)

- (UIBezierPath *) fb_union:(UIBezierPath *)path
{
    FBBezierGraph *thisGraph = [FBBezierGraph bezierGraphWithBezierPath:self];
    FBBezierGraph *otherGraph = [FBBezierGraph bezierGraphWithBezierPath:path];
    UIBezierPath *result = [[thisGraph unionWithBezierGraph:otherGraph] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (UIBezierPath *) fb_intersect:(UIBezierPath *)path
{
    FBBezierGraph *thisGraph = [FBBezierGraph bezierGraphWithBezierPath:self];
    FBBezierGraph *otherGraph = [FBBezierGraph bezierGraphWithBezierPath:path];
    UIBezierPath *result = [[thisGraph intersectWithBezierGraph:otherGraph] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (UIBezierPath *) fb_difference:(UIBezierPath *)path
{
    FBBezierGraph *thisGraph = [FBBezierGraph bezierGraphWithBezierPath:self];
    FBBezierGraph *otherGraph = [FBBezierGraph bezierGraphWithBezierPath:path];
    UIBezierPath *result = [[thisGraph differenceWithBezierGraph:otherGraph] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

- (UIBezierPath *) fb_xor:(UIBezierPath *)path
{
    FBBezierGraph *thisGraph = [FBBezierGraph bezierGraphWithBezierPath:self];
    FBBezierGraph *otherGraph = [FBBezierGraph bezierGraphWithBezierPath:path];
    UIBezierPath *result = [[thisGraph xorWithBezierGraph:otherGraph] bezierPath];
    [result fb_copyAttributesFrom:self];
    return result;
}

@end
