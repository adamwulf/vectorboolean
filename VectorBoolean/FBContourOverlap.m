//
//  FBContourOverlap.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 11/7/12.
//  Copyright (c) 2012 Fortunate Bear, LLC. All rights reserved.
//

#import "FBContourOverlap.h"
#import "FBContourEdge.h"
#import "FBBezierIntersectRange.h"
#import "FBBezierCurve.h"
#import "FBEdgeCrossing.h"
#import "FBDebug.h"

@interface FBEdgeOverlap ()

+ (id) overlapWithRange:(FBBezierIntersectRange *)range edge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2;
- (id) initWithRange:(FBBezierIntersectRange *)range edge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2;

@property (readonly) FBContourEdge *edge1;
@property (readonly) FBContourEdge *edge2;
@property (readonly) FBBezierIntersectRange *range;

- (BOOL) fitsBefore:(FBEdgeOverlap *)nextOverlap;
- (BOOL) fitsAfter:(FBEdgeOverlap *)previousOverlap;

- (void) addMiddleCrossing;

@end

@interface FBEdgeOverlapRun ()

+ (id) overlapRun;

- (BOOL) insertOverlap:(FBEdgeOverlap *)overlap;

- (BOOL) isComplete;

@property (readonly) FBBezierContour *contour1;
@property (readonly) FBBezierContour *contour2;

@end

static NSPoint FBComputeTangentFromRightOffset(FBBezierCurve *curve, CGFloat offset)
{
    if ( offset == 0.0 )
        return FBSubtractPoint(curve.controlPoint2, curve.endPoint2);
    CGFloat time = 1.0 - (offset / [curve length]);
    FBBezierCurve *leftCurve = nil;
    [curve pointAtParameter:time leftBezierCurve:&leftCurve rightBezierCurve:nil];
    return FBSubtractPoint(leftCurve.controlPoint2, leftCurve.endPoint2);
}

static NSPoint FBComputeTangentFromLeftOffset(FBBezierCurve *curve, CGFloat offset)
{
    if ( offset == 0.0 )
        return FBSubtractPoint(curve.controlPoint1, curve.endPoint1);
    CGFloat time = offset / [curve length];
    FBBezierCurve *rightCurve = nil;
    [curve pointAtParameter:time leftBezierCurve:nil rightBezierCurve:&rightCurve];
    return FBSubtractPoint(rightCurve.controlPoint1, rightCurve.endPoint1);
}

static void FBComputeEdge1Tangents(FBEdgeOverlap *firstOverlap, FBEdgeOverlap *lastOverlap, CGFloat offset, NSPoint edge1Tangents[2])
{
    // edge1Tangents are firstOverlap.range1.minimum going to previous and lastOverlap.range1.maximum going to next
    if ( firstOverlap.range.isAtStartOfCurve1 ) {
        FBContourEdge *otherEdge1 = firstOverlap.edge1.previous;
        edge1Tangents[0] = FBComputeTangentFromRightOffset(otherEdge1.curve, offset);
    } else
        edge1Tangents[0] = FBComputeTangentFromRightOffset(firstOverlap.range.curve1LeftBezier, offset);
    if ( lastOverlap.range.isAtStopOfCurve1 ) {
        FBContourEdge *otherEdge1 = lastOverlap.edge1.next;
        edge1Tangents[1] = FBComputeTangentFromLeftOffset(otherEdge1.curve, offset);
    } else
        edge1Tangents[1] = FBComputeTangentFromLeftOffset(lastOverlap.range.curve1RightBezier, offset);
}

static void FBComputeEdge2Tangents(FBEdgeOverlap *firstOverlap, FBEdgeOverlap *lastOverlap, CGFloat offset, NSPoint edge2Tangents[2])
{
    // edge2Tangents are firstOverlap.range2.minimum going to previous and lastOverlap.range2.maximum going to next
    //  unless reversed, then
    // edge2Tangents are firstOverlap.range2.maximum going to next and lastOverlap.range2.minimum going to previous
    if ( !firstOverlap.range.reversed ) {
        if ( firstOverlap.range.isAtStartOfCurve2 ) {
            FBContourEdge *otherEdge2 = firstOverlap.edge2.previous;
            edge2Tangents[0] = FBComputeTangentFromRightOffset(otherEdge2.curve, offset);
        } else
            edge2Tangents[0] = FBComputeTangentFromRightOffset(firstOverlap.range.curve2LeftBezier, offset);
        if ( lastOverlap.range.isAtStopOfCurve2 ) {
            FBContourEdge *otherEdge2 = lastOverlap.edge2.next;
            edge2Tangents[1] = FBComputeTangentFromLeftOffset(otherEdge2.curve, offset);
        } else
            edge2Tangents[1] = FBComputeTangentFromLeftOffset(lastOverlap.range.curve2RightBezier, offset);
    } else {
        if ( firstOverlap.range.isAtStopOfCurve2 ) {
            FBContourEdge *otherEdge2 = firstOverlap.edge2.next;
            edge2Tangents[0] = FBComputeTangentFromLeftOffset(otherEdge2.curve, offset);
        } else
            edge2Tangents[0] = FBComputeTangentFromLeftOffset(firstOverlap.range.curve2RightBezier, offset);
        if ( lastOverlap.range.isAtStartOfCurve2 ) {
            FBContourEdge *otherEdge2 = lastOverlap.edge2.previous;
            edge2Tangents[1] = FBComputeTangentFromRightOffset(otherEdge2.curve, offset);
        } else
            edge2Tangents[1] = FBComputeTangentFromRightOffset(lastOverlap.range.curve2LeftBezier, offset);
    }
}

static BOOL FBAreTangentsAmbigious(NSPoint edge1Tangents[2], NSPoint edge2Tangents[2])
{
    NSPoint normalEdge1[2] = { FBNormalizePoint(edge1Tangents[0]), FBNormalizePoint(edge1Tangents[1]) };
    NSPoint normalEdge2[2] = { FBNormalizePoint(edge2Tangents[0]), FBNormalizePoint(edge2Tangents[1]) };
    
    return NSEqualPoints(normalEdge1[0], normalEdge2[0]) || NSEqualPoints(normalEdge1[0], normalEdge2[1]) || NSEqualPoints(normalEdge1[1], normalEdge2[0]) || NSEqualPoints(normalEdge1[1], normalEdge2[1]);
}

@implementation FBContourOverlap

@synthesize runs=_runs;

+ (id) contourOverlap
{
    return [[[FBContourOverlap alloc] init] autorelease];
}

- (id) init
{
    self = [super init];
    if ( self != nil ) {
        _runs = [[NSMutableArray alloc] initWithCapacity:19];
    }
    return self;
}

- (void) dealloc
{
    [_runs release];
    
    [super dealloc];
}

- (void) addOverlap:(FBBezierIntersectRange *)range forEdge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2
{
    FBEdgeOverlap *overlap = [FBEdgeOverlap overlapWithRange:range edge1:edge1 edge2:edge2];
    BOOL createNewRun = NO;
    if ( [_runs count] == 0 ) {
        createNewRun = YES;
    } else if ( [_runs count] == 1 ) {
        BOOL inserted = [[_runs lastObject] insertOverlap:overlap];
        createNewRun = !inserted;
    } else {
        BOOL inserted = [[_runs lastObject] insertOverlap:overlap];
        if ( !inserted )
            inserted = [[_runs objectAtIndex:0] insertOverlap:overlap];
        createNewRun = !inserted;
    }
    if ( createNewRun ) {
        FBEdgeOverlapRun *run = [FBEdgeOverlapRun overlapRun];
        [run insertOverlap:overlap];
        [_runs addObject:run];
    }
}

- (void) reset
{
    [_runs removeAllObjects];
}

- (BOOL) isComplete
{
    // To be complete, we should have exactly one run that wraps around
    if ( [_runs count] != 1 )
        return NO;
    
    return [[_runs objectAtIndex:0] isComplete];
}

- (FBBezierContour *) contour1
{
    if ( [_runs count] == 0 )
        return nil;

    FBEdgeOverlapRun *run = [_runs objectAtIndex:0];
    return run.contour1;
}

- (FBBezierContour *) contour2
{
    if ( [_runs count] == 0 )
        return nil;

    FBEdgeOverlapRun *run = [_runs objectAtIndex:0];
    return run.contour2;
}

- (BOOL) isBetweenContour:(FBBezierContour *)contour1 andContour:(FBBezierContour *)contour2
{
    FBBezierContour *myContour1 = self.contour1;
    FBBezierContour *myContour2 = self.contour2;
    return (contour1 == myContour1 && contour2 == myContour2) || (contour1 == myContour2 && contour2 == myContour1);
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: runs = %@>", 
            NSStringFromClass([self class]), FBArrayDescription(_runs)];
}

@end

@implementation FBEdgeOverlapRun

+ (id) overlapRun
{
    return [[[FBEdgeOverlapRun alloc] init] autorelease];
}

- (id) init
{
    self = [super init];
    if ( self != nil ) {
        _overlaps = [[NSMutableArray alloc] initWithCapacity:4];
    }
    return self;
}

- (void) dealloc
{
    [_overlaps release];
    
    [super dealloc];
}

- (BOOL) insertOverlap:(FBEdgeOverlap *)overlap
{
    if ( [_overlaps count] == 0 ) {
        // The first one always works
        [_overlaps addObject:overlap];
        return YES;
    }
    
    // Check to see if overlap fits after our last overlap
    FBEdgeOverlap *lastOverlap = [_overlaps lastObject];
    if ( [lastOverlap fitsBefore:overlap] ) {
        [_overlaps addObject:overlap];
        return YES;
    }
    // Check to see if overlap fits before our first overlap
    FBEdgeOverlap *firstOverlap = [_overlaps objectAtIndex:0];
    if ( [firstOverlap fitsAfter:overlap] ) {
        [_overlaps insertObject:overlap atIndex:0];
        return YES;
    }
    return NO;
}

- (BOOL) isComplete
{
    // To be complete, we should wrap around
    if ( [_overlaps count] == 0 )
        return NO;
    
    FBEdgeOverlap *lastOverlap = [_overlaps lastObject];
    FBEdgeOverlap *firstOverlap = [_overlaps objectAtIndex:0];
    return [lastOverlap fitsBefore:firstOverlap];
}

- (BOOL) isCrossing
{
    // The intersection happens at the end of one of the edges, meaning we'll have to look at the next
    //  edge in sequence to see if it crosses or not. We'll do that by computing the four tangents at the exact
    //  point the intersection takes place. We'll compute the polar angle for each of the tangents. If the
    //  angles of self split the angles of edge2 (i.e. they alternate when sorted), then the edges cross. If
    //  any of the angles are equal or if the angles group up, then the edges don't cross.

    // Calculate the four tangents: The two tangents moving away from the intersection point on self, the two tangents
    //  moving away from the intersection point on edge2.

    FBEdgeOverlap *firstOverlap = [_overlaps objectAtIndex:0];
    FBEdgeOverlap *lastOverlap = [_overlaps lastObject];

    NSPoint edge1Tangents[] = { NSZeroPoint, NSZeroPoint };
    NSPoint edge2Tangents[] = { NSZeroPoint, NSZeroPoint };
    CGFloat offset = 0.0;
    
    do {
        FBComputeEdge1Tangents(firstOverlap, lastOverlap, offset, edge1Tangents);
        FBComputeEdge2Tangents(firstOverlap, lastOverlap, offset, edge2Tangents);
        
        offset += 1.0;
    } while ( FBAreTangentsAmbigious(edge1Tangents, edge2Tangents) );
    
    return FBTangentsCross(edge1Tangents, edge2Tangents);
}

- (void) addCrossings
{
    // Add crossings to both graphs for this intersection/overlap. Pick the middle point and use that
    if ( [_overlaps count] == 0 )
        return;
    
    FBEdgeOverlap *middleOverlap = [_overlaps objectAtIndex:[_overlaps count] / 2];
    [middleOverlap addMiddleCrossing];
}

- (FBBezierContour *) contour1
{
    if ( [_overlaps count] == 0 )
        return nil;
    
    FBEdgeOverlap *overlap = [_overlaps objectAtIndex:0];
    return overlap.edge1.contour;
}

- (FBBezierContour *) contour2
{
    if ( [_overlaps count] == 0 )
        return nil;
    
    FBEdgeOverlap *overlap = [_overlaps objectAtIndex:0];
    return overlap.edge2.contour;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: overlaps = %@>", 
            NSStringFromClass([self class]), FBArrayDescription(_overlaps)];
}

@end

@implementation FBEdgeOverlap

@synthesize edge1=_edge1;
@synthesize edge2=_edge2;
@synthesize range=_range;

+ (id) overlapWithRange:(FBBezierIntersectRange *)range edge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2
{
    return [[[FBEdgeOverlap alloc] initWithRange:range edge1:edge1 edge2:edge2] autorelease];
}

- (id) initWithRange:(FBBezierIntersectRange *)range edge1:(FBContourEdge *)edge1 edge2:(FBContourEdge *)edge2
{
    self = [super init];
    if ( self != nil ) {
        _edge1 = [edge1 retain];
        _edge2 = [edge2 retain];
        _range = [range retain];
    }
    return self;
}

- (void) dealloc
{
    [_edge1 release];
    [_edge2 release];
    [_range release];
    
    [super dealloc];
}

- (BOOL) fitsBefore:(FBEdgeOverlap *)nextOverlap
{
    if ( FBAreValuesClose(_range.parameterRange1.maximum, 1.0) ) {
        // nextOverlap should start at 0 of the next edge
        FBContourEdge *nextEdge = _edge1.next;
        return nextOverlap.edge1 == nextEdge && FBAreValuesClose(nextOverlap.range.parameterRange1.minimum, 0.0);
    }
    
    // nextOverlap should start at about maximum on the same edge
    return nextOverlap.edge1 == _edge1 && FBAreValuesClose(nextOverlap.range.parameterRange1.minimum, _range.parameterRange1.maximum);
}

- (BOOL) fitsAfter:(FBEdgeOverlap *)previousOverlap
{
    if ( FBAreValuesClose(_range.parameterRange1.minimum, 0.0) ) {
        // previousOverlap should end at 1 of the previous edge
        FBContourEdge *previousEdge = _edge1.previous;
        return previousOverlap.edge1 == previousEdge && FBAreValuesClose(previousOverlap.range.parameterRange1.maximum, 1.0);
    }
    
    // previousOverlap should end at about the minimum on the same edge
    return previousOverlap.edge1 == _edge1 && FBAreValuesClose(previousOverlap.range.parameterRange1.maximum, _range.parameterRange1.minimum);
}

- (void) addMiddleCrossing
{
    FBBezierIntersection *intersection = _range.middleIntersection;
    FBEdgeCrossing *ourCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];
    FBEdgeCrossing *theirCrossing = [FBEdgeCrossing crossingWithIntersection:intersection];
    ourCrossing.counterpart = theirCrossing;
    theirCrossing.counterpart = ourCrossing;
    [_edge1 addCrossing:ourCrossing];
    [_edge2 addCrossing:theirCrossing];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: edge1 = %@, edge2 = %@, range = %@>", 
            NSStringFromClass([self class]), self.edge1, self.edge2, self.range];
}

@end
