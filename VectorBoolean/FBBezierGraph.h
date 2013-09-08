//
//  FBBezierGraph.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FBBezierContour;

// FBBezierGraph is more or less an exploded version of an UIBezierPath, and
//  the two can be converted between easily. FBBezierGraph allows boolean
//  operations to be performed by allowing the curves to be annotated with
//  extra information such as where intersections happen.
@interface FBBezierGraph : NSObject {
    NSMutableArray *_contours;
    CGRect _bounds;
}

+ (id) bezierGraph;
+ (id) bezierGraphWithBezierPath:(UIBezierPath *)path;
- (id) initWithBezierPath:(UIBezierPath *)path;

- (FBBezierGraph *) unionWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) intersectWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) differenceWithBezierGraph:(FBBezierGraph *)graph;
- (FBBezierGraph *) xorWithBezierGraph:(FBBezierGraph *)graph;

- (UIBezierPath *) bezierPath;

@property (readonly) NSArray* contours;

- (void) debuggingInsertCrossingsForUnionWithBezierGraph:(FBBezierGraph *)otherGraph;
- (void) debuggingInsertCrossingsForIntersectWithBezierGraph:(FBBezierGraph *)otherGraph;
- (void) debuggingInsertCrossingsForDifferenceWithBezierGraph:(FBBezierGraph *)otherGraph;
- (void) debuggingInsertIntersectionsWithBezierGraph:(FBBezierGraph *)otherGraph;
- (UIBezierPath *) debugPathForContainmentOfContour:(FBBezierContour *)contour;
- (UIBezierPath *) debugPathForJointsOfContour:(FBBezierContour *)testContour;

@end
