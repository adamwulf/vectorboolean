//
//  FBBezierCurve.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Geometry.h"

@class FBBezierIntersectRange;

// FBBezierCurve is one cubic 2D bezier curve. It represents one segment of a bezier path, and is where
//  the intersection calculation happens
@interface FBBezierCurve : NSObject {
    NSPoint _endPoint1;
    NSPoint _controlPoint1;
    NSPoint _controlPoint2;
    NSPoint _endPoint2;
	BOOL _isStraightLine;		// GPC: flag when curve came from a straight line segment
}

+ (NSArray *) bezierCurvesFromBezierPath:(NSBezierPath *)path;

+ (id) bezierCurveWithLineStartPoint:(NSPoint)startPoint endPoint:(NSPoint)endPoint;
+ (id) bezierCurveWithEndPoint1:(NSPoint)endPoint1 controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 endPoint2:(NSPoint)endPoint2;

- (id) initWithEndPoint1:(NSPoint)endPoint1 controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 endPoint2:(NSPoint)endPoint2;
- (id) initWithLineStartPoint:(NSPoint)startPoint endPoint:(NSPoint)endPoint;

@property NSPoint endPoint1;
@property NSPoint controlPoint1;
@property NSPoint controlPoint2;
@property NSPoint endPoint2;
@property BOOL isStraightLine;
@property (readonly) NSRect bounds;

- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve;
- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve overlapRange:(FBBezierIntersectRange **)intersectRange;

- (NSPoint) pointAtParameter:(CGFloat)parameter leftBezierCurve:(FBBezierCurve **)leftBezierCurve rightBezierCurve:(FBBezierCurve **)rightBezierCurve;
- (FBBezierCurve *) subcurveWithRange:(FBRange)range;
- (NSArray *) splitSubcurvesWithRange:(FBRange)range;

- (CGFloat) lengthAtParameter:(CGFloat)parameter;
- (CGFloat) length;

- (FBBezierCurve *) reversedCurve;	// GPC: added

- (NSBezierPath *) bezierPath;

@end
