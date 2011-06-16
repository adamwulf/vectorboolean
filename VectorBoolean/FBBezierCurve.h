//
//  FBBezierCurve.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


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

@end
