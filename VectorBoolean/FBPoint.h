//
//  FBPoint.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FBPoint : NSObject {
    FBPoint *_next;
    FBPoint *_previous;
    FBPoint *_neighbor;
    NSPoint _location;
    BOOL _intersection;
    BOOL _entry;
    CGFloat _relativeDistance;
}

- (id) initWithLocation:(NSPoint)location;

@property (assign) FBPoint *next;
@property (assign) FBPoint *previous;
@property (assign) FBPoint *neighbor;
@property NSPoint location;
@property (getter=isIntersection) BOOL intersection;
@property CGFloat relativeDistance;
@property (getter=isEntry) BOOL entry;

@end

///////////////////////////////////////////////////////////////

@interface FBPointList : NSObject {
    FBPoint *_head;
    FBPoint *_tail;
    NSMutableArray *_points;
}

- (void) addPoint:(FBPoint *)point;
- (void) insertPoint:(FBPoint *)point after:(FBPoint *)location;
- (void) enumeratePointsWithBlock:(void (^)(FBPoint *point, BOOL *stop))block;

@end
