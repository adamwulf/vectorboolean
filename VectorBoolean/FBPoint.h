//
//  FBPoint.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FBPointList;

@interface FBPoint : NSObject {
    FBPoint *_next;
    FBPoint *_previous;
    FBPoint *_neighbor;
    FBPointList *_container;
    NSPoint _location;
    BOOL _intersection;
    BOOL _entry;
    BOOL _visited;
    CGFloat _relativeDistance;
}

- (id) initWithLocation:(NSPoint)location;

@property (assign) FBPoint *next;
@property (assign) FBPoint *previous;
@property (assign) FBPoint *neighbor;
@property (assign) FBPointList *container;
@property NSPoint location;
@property (getter=isIntersection) BOOL intersection;
@property CGFloat relativeDistance;
@property (getter=isEntry) BOOL entry;
@property (getter=isVisited) BOOL visited;

@end

///////////////////////////////////////////////////////////////

@interface FBPointList : NSObject {
    FBPoint *_head;
    FBPoint *_tail;
    NSMutableArray *_points;
}

- (void) addPoint:(FBPoint *)point;
- (void) insertPoint:(FBPoint *)point after:(FBPoint *)location;
- (void) removePoint:(FBPoint *)point;

- (void) enumeratePointsWithBlock:(void (^)(FBPoint *point, BOOL *stop))block;
- (void) removeIntersectionPoints;

@property (readonly) FBPoint *firstPoint;
@property (readonly) FBPoint *lastPoint;

@end
