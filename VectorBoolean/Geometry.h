//
//  Geometry.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


CGFloat FBDistanceBetweenPoints(CGPoint point1, CGPoint point2);
CGFloat FBDistancePointToLine(CGPoint point, CGPoint lineStartPoint, CGPoint lineEndPoint);
CGPoint FBLineNormal(CGPoint lineStart, CGPoint lineEnd);
CGPoint FBLineMidpoint(CGPoint lineStart, CGPoint lineEnd);

CGPoint FBAddPoint(CGPoint point1, CGPoint point2);
CGPoint FBScalePoint(CGPoint point, CGFloat scale);
CGPoint FBUnitScalePoint(CGPoint point, CGFloat scale);
CGPoint FBSubtractPoint(CGPoint point1, CGPoint point2);
CGFloat FBDotMultiplyPoint(CGPoint point1, CGPoint point2);
CGFloat FBPointLength(CGPoint point);
CGFloat FBPointSquaredLength(CGPoint point);
CGPoint FBNormalizePoint(CGPoint point);
CGPoint FBNegatePoint(CGPoint point);
CGPoint FBRoundPoint(CGPoint point);

CGPoint FBRectGetTopLeft(CGRect rect);
CGPoint FBRectGetTopRight(CGRect rect);
CGPoint FBRectGetBottomLeft(CGRect rect);
CGPoint FBRectGetBottomRight(CGRect rect);

void FBExpandBoundsByPoint(CGPoint *topLeft, CGPoint *bottomRight, CGPoint point);
CGRect FBUnionRect(CGRect rect1, CGRect rect2);

BOOL FBArePointsClose(CGPoint point1, CGPoint point2);
BOOL FBArePointsCloseWithOptions(CGPoint point1, CGPoint point2, CGFloat threshold);
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
CGFloat PolarAngle(CGPoint point);

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

extern BOOL FBTangentsCross(CGPoint edge1Tangents[2], CGPoint edge2Tangents[2]);
