//
//  FBBezierGraph.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// FBBezierGraph is more or less an exploded version of an NSBezierPath, and
//  the two can be converted between easily. FBBezierGraph allows boolean
//  operations to be performed by allowing the curves to be annotated with
//  extra information such as where intersections happen.
@interface FBBezierGraph : NSObject {
    NSMutableArray *_contours;
    NSRect _bounds;
}

+ (id) bezierGraph;
+ (id) bezierGraphWithBezierPath:(NSBezierPath *)path;
- (id) initWithBezierPath:(NSBezierPath *)path;

- (FBBezierGraph *) unionWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph;

- (NSBezierPath *) bezierPath;

@end
