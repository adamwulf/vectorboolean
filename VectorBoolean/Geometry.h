//
//  Geometry.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


CGFloat FBDistanceBetweenPoints(NSPoint point1, NSPoint point2);
CGFloat FBDistancePointToLine(NSPoint point, NSPoint lineStartPoint, NSPoint lineEndPoint);
NSPoint FBLineNormal(NSPoint lineStart, NSPoint lineEnd);
NSPoint FBLineMidpoint(NSPoint lineStart, NSPoint lineEnd);

NSPoint FBAddPoint(NSPoint point1, NSPoint point2);
NSPoint FBScalePoint(NSPoint point, CGFloat scale);
NSPoint FBUnitScalePoint(NSPoint point, CGFloat scale);
NSPoint FBSubtractPoint(NSPoint point1, NSPoint point2);
CGFloat FBDotMultiplyPoint(NSPoint point1, NSPoint point2);
CGFloat FBPointLength(NSPoint point);
CGFloat FBPointSquaredLength(NSPoint point);
NSPoint FBNormalizePoint(NSPoint point);
NSPoint FBNegatePoint(NSPoint point);
NSPoint FBRoundPoint(NSPoint point);

NSPoint FBRectGetTopLeft(NSRect rect);
NSPoint FBRectGetTopRight(NSRect rect);
NSPoint FBRectGetBottomLeft(NSRect rect);
NSPoint FBRectGetBottomRight(NSRect rect);

void FBExpandBoundsByPoint(NSPoint *topLeft, NSPoint *bottomRight, NSPoint point);
NSRect FBUnionRect(NSRect rect1, NSRect rect2);

BOOL FBArePointsClose(NSPoint point1, NSPoint point2);
BOOL FBArePointsCloseWithOptions(NSPoint point1, NSPoint point2, CGFloat threshold);
BOOL FBAreValuesClose(CGFloat value1, CGFloat value2);
BOOL FBAreValuesCloseWithOptions(CGFloat value1, CGFloat value2, CGFloat threshold);

//////////////////////////////////////////////////////////////////////////
// Angle Range structure provides a simple way to store angle ranges
//  and determine if a specific angle falls within. 
//
typedef struct FBAngleRange {
    CGFloat minimum;
    CGFloat maximum;
} FBAngleRange;

FBAngleRange FBAngleRangeMake(CGFloat minimum, CGFloat maximum);
BOOL FBAngleRangeContainsAngle(FBAngleRange range, CGFloat angle);

CGFloat NormalizeAngle(CGFloat value);
CGFloat PolarAngle(NSPoint point);

//////////////////////////////////////////////////////////////////////////////////
// Parameter ranges
//

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

extern BOOL FBTangentsCross(NSPoint edge1Tangents[2], NSPoint edge2Tangents[2]);
