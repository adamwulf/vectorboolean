//
//  FBContourEdge.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBContourEdge.h"
#import "FBEdgeCrossing.h"
#import "FBBezierContour.h"
#import "FBDebug.h"

@interface FBContourEdge ()

- (void) sortCrossings;

@end

@implementation FBContourEdge

@synthesize curve=_curve;
@synthesize crossings=_crossings;
@synthesize index=_index;
@synthesize contour=_contour;
@synthesize startShared=_startShared;
@synthesize stopShared=_stopShared;

- (id) initWithBezierCurve:(FBBezierCurve *)curve contour:(FBBezierContour *)contour
{
    self = [super init];
    
    if ( self != nil ) {
        _curve = [curve retain];
        _crossings = [[NSMutableArray alloc] initWithCapacity:4];
        _contour = contour; // no cyclical references
    }
    
    return self;
}

- (void)dealloc
{
    [_crossings release];
    [_curve release];
    
    [super dealloc];
}

- (void) addCrossing:(FBEdgeCrossing *)crossing
{
    // Make sure the crossing can make it back to us, and keep all the crossings sorted
    crossing.edge = self;
    [_crossings addObject:crossing];
    [self sortCrossings];
}

- (void) removeCrossing:(FBEdgeCrossing *)crossing
{
    // Keep the crossings sorted
    crossing.edge = nil;
    [_crossings removeObject:crossing];
    [self sortCrossings];
}

- (void) sortCrossings
{
    // Sort by the "order" of the crossing, then assign indices so next and previous work correctly.
    [_crossings sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        FBEdgeCrossing *crossing1 = obj1;
        FBEdgeCrossing *crossing2 = obj2;
        if ( crossing1.order < crossing2.order )
            return NSOrderedAscending;
        else if ( crossing1.order > crossing2.order )
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSUInteger index = 0;
    for (FBEdgeCrossing *crossing in _crossings)
        crossing.index = index++;
}

- (void) removeAllCrossings
{
    [_crossings removeAllObjects];
}

- (FBContourEdge *)next
{
    if ( _index >= ([self.contour.edges count] - 1) )
        return [self.contour.edges objectAtIndex:0];
    
    return [self.contour.edges objectAtIndex:_index + 1];
}

- (FBContourEdge *)previous
{
    if ( _index == 0 )
        return [self.contour.edges objectAtIndex:[self.contour.edges count] - 1];
    
    return [self.contour.edges objectAtIndex:_index - 1];
}

- (NSArray *) intersectingEdges
{
    NSMutableArray *edges = [NSMutableArray arrayWithCapacity:[_crossings count]];
    for (FBEdgeCrossing *crossing in _crossings) {
        FBContourEdge *intersectingEdge = crossing.counterpart.edge;
        if ( ![edges containsObject:intersectingEdge] )
            [edges addObject:intersectingEdge];
    }
    return edges;
}

- (FBEdgeCrossing *) firstCrossing
{
    if ( [_crossings count] == 0 )
        return nil;
    return [_crossings objectAtIndex:0];
}

- (FBEdgeCrossing *) lastCrossing
{
    if ( [_crossings count] == 0 )
        return nil;
    return [_crossings objectAtIndex:[_crossings count] - 1];    
}

- (void) round
{
    [_curve round];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: curve = %@ crossings = %@>", NSStringFromClass([self class]), [_curve description], FBArrayDescription(_crossings)];
}

@end
