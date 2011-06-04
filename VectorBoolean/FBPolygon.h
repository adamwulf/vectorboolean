//
//  FBPolygon.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/2/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FBPolygon : NSObject {
    NSMutableArray *_subpolygons;
    NSRect _bounds;
}

- (id) initWithBezierPath:(NSBezierPath *)bezier;

- (FBPolygon *) unionWithPolygon:(FBPolygon *)polygon;
- (FBPolygon *) intersectWithPolygon:(FBPolygon *)polygon;
- (FBPolygon *) differenceWithPolygon:(FBPolygon *)polygon;
- (FBPolygon *) xorWithPolygon:(FBPolygon *)polygon;

- (NSBezierPath *) bezierPath;

@end
