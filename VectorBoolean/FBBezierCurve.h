//
//  FBBezierCurve.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Geometry.h"

@class FBBezierIntersectRange;

// FBBezierCurve is one cubic 2D bezier curve. It represents one segment of a bezier path, and is where
//  the intersection calculation happens
@interface FBBezierCurve : NSObject {
    CGPoint _endPoint1;
    CGPoint _controlPoint1;
    CGPoint _controlPoint2;
    CGPoint _endPoint2;
	BOOL _isStraightLine;		// GPC: flag when curve came from a straight line segment
}

+ (NSArray *) bezierCurvesFromBezierPath:(UIBezierPath *)path;

+ (id) bezierCurveWithLineStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint;
+ (id) bezierCurveWithEndPoint1:(CGPoint)endPoint1 controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2 endPoint2:(CGPoint)endPoint2;

- (id) initWithEndPoint1:(CGPoint)endPoint1 controlPoint1:(CGPoint)controlPoint1 controlPoint2:(CGPoint)controlPoint2 endPoint2:(CGPoint)endPoint2;
- (id) initWithLineStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint;

@property CGPoint endPoint1;
@property CGPoint controlPoint1;
@property CGPoint controlPoint2;
@property CGPoint endPoint2;
@property BOOL isStraightLine;
@property (readonly) CGRect bounds;

- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve;
- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve overlapRange:(FBBezierIntersectRange **)intersectRange;

- (CGPoint) pointAtParameter:(CGFloat)parameter leftBezierCurve:(FBBezierCurve **)leftBezierCurve rightBezierCurve:(FBBezierCurve **)rightBezierCurve;
- (FBBezierCurve *) subcurveWithRange:(FBRange)range;
- (NSArray *) splitSubcurvesWithRange:(FBRange)range;
- (NSArray *) splitCurveAtParameter:(CGFloat)parameter;

- (CGFloat) lengthAtParameter:(CGFloat)parameter;
- (CGFloat) length;

- (FBBezierCurve *) reversedCurve;	// GPC: added

- (UIBezierPath *) bezierPath;

@end
