//
//  FBBezierIntersection.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FBBezierCurve;

@interface FBBezierIntersection : NSObject {
    NSPoint _location;
    FBBezierCurve *_curve1;
    CGFloat _t1;
    FBBezierCurve *_curve2;
    CGFloat _t2;
    BOOL _tangent;
}

@property NSPoint location;
@property (retain) FBBezierCurve *curve1;
@property CGFloat t1;
@property (retain) FBBezierCurve *curve2;
@property CGFloat t2;
@property (getter = isTangent) BOOL tangent;

@end
