//
//  FBBezierCurve.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// FBRange is a range of parameter (t)
typedef struct FBRange {
    CGFloat minimum;
    CGFloat maximum;
} FBRange;

extern FBRange FBRangeMake(CGFloat minimum, CGFloat maximum);
extern BOOL FBRangeHasConverged(FBRange range, NSUInteger places);
extern CGFloat FBRangeGetSize(FBRange range);
extern CGFloat FBRangeAverage(FBRange range);
extern CGFloat FBRangeScaleNormalizedValue(FBRange range, CGFloat value);

// FBBezierCurve is one cubic 2D bezier curve. It represents one segment of a bezier path, and is where
//  the intersection calculation happens
@interface FBBezierCurve : NSObject {
    NSPoint _endPoint1;
    NSPoint _controlPoint1;
    NSPoint _controlPoint2;
    NSPoint _endPoint2;
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

- (NSArray *) intersectionsWithBezierCurve:(FBBezierCurve *)curve;

- (NSPoint) pointAtParameter:(CGFloat)parameter leftBezierCurve:(FBBezierCurve **)leftBezierCurve rightBezierCurve:(FBBezierCurve **)rightBezierCurve;
- (FBBezierCurve *) subcurveWithRange:(FBRange)range;

- (void) round;

@end
