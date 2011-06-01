//
//  NSBezierPath+FitCurve.m
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "NSBezierPath+FitCurve.h"
#import "NSBezierPath+Utilities.h"
#import "Geometry.h"
#import "math.h"

// Algorithm implemented here is the one described in "An Algorithm for Automatically Fitting Digitized Curves"
//  by Philip J. Schneider contained in the book Graphics Gems

static const NSUInteger FitCurveMaximumReparameterizes = 4;

static CGFloat Determinant(CGFloat matrix1[2], CGFloat matrix2[2])
{
    return matrix1[0] * matrix2[1] - matrix1[1] * matrix2[0];
}

// The following are 3rd degree Bertstein polynomials. They all have
//  the same formula:
//
//  B[i](input) = (3! / ((3-i)! * i!)) * input^i * (1 - input) ^ (3 - i)
//
//  however the functions below have been optimized for their value of i.
static CGFloat Bernstein0(CGFloat input)
{
    return powf(1.0 - input, 3);
}

static CGFloat Bernstein1(CGFloat input)
{
    return 3 * input * powf(1.0 - input, 2);
}

static CGFloat Bernstein2(CGFloat input)
{
    return 3 * powf(input, 2) * (1.0 - input);
}

static CGFloat Bernstein3(CGFloat input)
{
    return powf(input, 3);
}

static NSPoint BezierWithPoints(NSUInteger degree, NSPoint *bezierPoints, CGFloat parameter)
{
    // Calculate a point on the bezier curve passed in, specifically the point at parameter.
    //  We could just plug parameter into the Q(t) formula shown in the fb_fitBezierInRange: comments.
    //  However, that method isn't numerically stable, meaning it amplifies any errors, which is bad
    //  seeing we're using floating point numbers with limited precision. Instead we'll use
    //  De Casteljau's algorithm.
    //
    // See: http://www.cs.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/de-casteljau.html
    //  for an explaination of De Casteljau's algorithm.
    
    // With this algorithm we start out with the points in the bezier path.    
    NSPoint points[4] = {};
    for (NSUInteger i = 0; i <= degree; i++)
        points[i] = bezierPoints[i];
    
    for (NSUInteger k = 1; k <= degree; k++) {
        for (NSUInteger i = 0; i <= (degree - k); i++) {
            points[i].x = (1.0 - parameter) * points[i].x + parameter * points[i + 1].x;
            points[i].y = (1.0 - parameter) * points[i].y + parameter * points[i + 1].y;            
        }
    }
    
    return points[0]; // we'll end up with just one point, which is handy, 'cause that's what we want
}

static NSPoint Bezier(NSUInteger degree, NSBezierPath *bezier, CGFloat parameter)
{
    // With this algorithm we start out with the points in the bezier path. We assume the bezier
    //  path is a move to and a curve to
    NSBezierElement element1 = [bezier fb_elementAtIndex:0];
    NSBezierElement element2 = [bezier fb_elementAtIndex:1];
    NSPoint bezierPoints[4] = {element1.point, element2.controlPoints[0], element2.controlPoints[1], element2.point};
    
    return BezierWithPoints(degree, bezierPoints, parameter);
}

static CGFloat NewtonsMethod(NSBezierPath *bezier, NSPoint point, CGFloat parameter)
{
    // Use Newton's Method to refine our parameter. In general, that formula is:
    //
    //  parameter = parameter - f(parameter) / f'(parameter)
    //
    // In our case:
    //
    //  f(parameter) = (Q(parameter) - point) * Q'(parameter) = 0
    //
    // Where Q'(parameter) is tangent to the curve at Q(parameter) and orthogonal to [Q(parameter) - P]
    //
    // Taking the derivative gives us:
    //
    //  f'(parameter) = (Q(parameter) - point) * Q''(parameter) + Q'(parameter) * Q'(parameter)
    //
    
    // We assume the bezier path is a move to and a curve to
    NSBezierElement element1 = [bezier fb_elementAtIndex:0];
    NSBezierElement element2 = [bezier fb_elementAtIndex:1];
    NSPoint bezierPoints[4] = {element1.point, element2.controlPoints[0], element2.controlPoints[1], element2.point};

    // Compute Q(parameter)
    NSPoint qAtParameter = BezierWithPoints(3, bezierPoints, parameter);
    
    // Compute Q'(parameter)
    NSPoint qPrimePoints[3] = {};
    for (NSUInteger i = 0; i < 3; i++) {
        qPrimePoints[i].x = (bezierPoints[i + 1].x - bezierPoints[i].x) * 3.0;
        qPrimePoints[i].y = (bezierPoints[i + 1].y - bezierPoints[i].y) * 3.0;
    }
    NSPoint qPrimeAtParameter = BezierWithPoints(2, qPrimePoints, parameter);
    
    // Compute Q''(parameter)
    NSPoint qPrimePrimePoints[2] = {};
    for (NSUInteger i = 0; i < 2; i++) {
        qPrimePrimePoints[i].x = (qPrimePoints[i + 1].x - qPrimePoints[i].x) * 2.0;
        qPrimePrimePoints[i].y = (qPrimePoints[i + 1].y - qPrimePoints[i].y) * 2.0;        
    }
    NSPoint qPrimePrimeAtParameter = BezierWithPoints(1, qPrimePrimePoints, parameter);
    
    // Compute f(parameter) and f'(parameter)
    NSPoint qMinusPoint = FBSubtractPoint(qAtParameter, point);
    CGFloat fAtParameter = FBDotMultiplyPoint(qMinusPoint, qPrimeAtParameter);
    CGFloat fPrimeAtParameter = FBDotMultiplyPoint(qMinusPoint, qPrimePrimeAtParameter) + FBDotMultiplyPoint(qPrimeAtParameter, qPrimeAtParameter);
    
    // Newton's method!
    return parameter - (fAtParameter / fPrimeAtParameter);
}

@interface NSBezierPath (FitCurvePrivate)

- (NSBezierPath *) fb_fitCubicToRange:(NSRange)range leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent errorThreshold:(CGFloat)errorThreshold;
- (NSArray *) fb_refineParameters:(NSArray *)parameters forRange:(NSRange)range bezier:(NSBezierPath *)bezier;
- (CGFloat) fb_findMaximumErrorForBezier:(NSBezierPath *)bezier inRange:(NSRange)range parameters:(NSArray *)parameters maximumIndex:(NSUInteger *)maximumIndex;
- (NSBezierPath *) fb_fitBezierUsingNaiveMethodInRange:(NSRange)range leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent;
- (NSPoint) fb_computeLeftTangentAtIndex:(NSUInteger)index;
- (NSPoint) fb_computeRightTangentAtIndex:(NSUInteger)index;
- (NSPoint) fb_computeCenterTangentAtIndex:(NSUInteger)index;
- (NSArray *) fb_estimateParametersUsingChordLengthMethodInRange:(NSRange)range;
- (NSBezierPath *) fb_fitBezierInRange:(NSRange)range withParameters:(NSArray *)parameters leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent;

@end

@implementation NSBezierPath (FitCurve)

- (NSBezierPath *) fb_fitCurve:(CGFloat)errorThreshold
{
    // Safety first
    if ( [self elementCount] < 2 )
        return self;
    
    NSPoint leftTangentVector = [self fb_computeLeftTangentAtIndex:0];
    NSPoint rightTangentVector = [self fb_computeRightTangentAtIndex:[self elementCount] - 1];
    return [self fb_fitCubicToRange:NSMakeRange(0, [self elementCount]) leftTangent:leftTangentVector rightTangent:rightTangentVector errorThreshold:errorThreshold];
}

@end

@implementation NSBezierPath (FitCurvePrivate)

- (NSBezierPath *) fb_fitCubicToRange:(NSRange)range leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent errorThreshold:(CGFloat)errorThreshold
{
    // Handle the special case where we only have two points
    if ( range.length == 2 ) 
        return [self fb_fitBezierUsingNaiveMethodInRange:range leftTangent:leftTangent rightTangent:rightTangent];

    // First thing, just try to fit one bezier curve to all our points in range
    NSArray *parameters = [self fb_estimateParametersUsingChordLengthMethodInRange:range];
    NSBezierPath *bezier = [self fb_fitBezierInRange:range withParameters:parameters leftTangent:leftTangent rightTangent:rightTangent];
    
    // See how well our bezier fit our points. If it's within the allowed error, we're done
    NSUInteger maximumIndex = NSNotFound;
    CGFloat error = [self fb_findMaximumErrorForBezier:bezier inRange:range parameters:parameters maximumIndex:&maximumIndex];
    if ( error < errorThreshold )
        return bezier;
    
    // Huh. That wasn't good enough. Well, our estimated parameters probably sucked, so see if it makes sense to try
    //  to refine them. If error is huge, it probably means that probably won't help, so in that case just skip it.
    if ( error < (errorThreshold * errorThreshold) ) {
        for (NSUInteger i = 0; i < FitCurveMaximumReparameterizes; i++) {
            parameters = [self fb_refineParameters:parameters forRange:range bezier:bezier];
            
            // OK, try again with the new parameters
            bezier = [self fb_fitBezierInRange:range withParameters:parameters leftTangent:leftTangent rightTangent:rightTangent];
            error = [self fb_findMaximumErrorForBezier:bezier inRange:range parameters:parameters maximumIndex:&maximumIndex];
            if ( error < errorThreshold )
                return bezier; // sweet, it worked!
        }
    }
    
    // Alright, we couldn't fit a single bezier curve to all these points no matter how much we refined the parameters.
    //  Instead, split the points into two parts based on where the biggest error is. Build two separate curves which
    //  we'll combine into one single NSBezierPath.
    NSPoint centerTangent = [self fb_computeCenterTangentAtIndex:maximumIndex];
    NSBezierPath *leftBezier = [self fb_fitCubicToRange:NSMakeRange(range.location, maximumIndex - range.location + 1) leftTangent:leftTangent rightTangent:centerTangent errorThreshold:errorThreshold];
    NSBezierPath *rightBezier = [self fb_fitCubicToRange:NSMakeRange(maximumIndex, (range.location + range.length) - maximumIndex) leftTangent:FBNegatePoint(centerTangent) rightTangent:rightTangent errorThreshold:errorThreshold];
    [leftBezier fb_appendPath:rightBezier];
    return leftBezier;
}

- (NSArray *) fb_refineParameters:(NSArray *)parameters forRange:(NSRange)range bezier:(NSBezierPath *)bezier
{
    // Use Newton's Method to refine our parameters.
    NSMutableArray *refinedParameters = [NSMutableArray arrayWithCapacity:range.length];
    for (NSUInteger i = 0; i < range.length; i++) {
        [refinedParameters addObject:[NSNumber numberWithFloat:NewtonsMethod(bezier, [self fb_pointAtIndex:range.location + i], [[parameters objectAtIndex:i] floatValue])]];
    }
    return refinedParameters;
}

- (CGFloat) fb_findMaximumErrorForBezier:(NSBezierPath *)bezier inRange:(NSRange)range parameters:(NSArray *)parameters maximumIndex:(NSUInteger *)maximumIndex
{
    // Here we calculate the squared errors, defined as:
    //
    //  S = SUM( (point[i] - Q(parameters[i])) ^ 2 )
    //
    //  Where point[i] is the point on this NSBezierPath at i, parameters[i] is the float in the parameters
    //  NSArray at index i. Q is the bezier curve represented by the variable bezier. This formula takes
    //  the difference (distance) between a point in this NSBezierPath we're trying to fit, and the corresponding
    //  point in the generated bezier curve, squares it, and adds all the differences up (i.e. squared errors).
    //  This tells us how far off our curve is from our points we're trying to fit.    
    CGFloat maximumError = 0.0;
    for (NSUInteger i = 1; i < (range.length - 1); i++) {
        NSPoint pointOnQ = Bezier(3, bezier, [[parameters objectAtIndex:i] floatValue]); // Calculate Q(parameters[i])
        NSPoint point = [self fb_pointAtIndex:range.location + i];
        CGFloat distance = FBPointSquaredLength(FBSubtractPoint(pointOnQ, point));
        if ( distance >= maximumError ) {
            maximumError = distance;
            *maximumIndex = range.location + i;
        }
    }
    return maximumError;
}

- (NSBezierPath *) fb_fitBezierUsingNaiveMethodInRange:(NSRange)range leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent
{
    // This is a fallback method for when our normal bezier curve fitting method fails, either due to too few points
    //  or other anomalies. As with the normal curve fitting, we have the two end points and the direction of the two control
    //  points, meaning we only lack the distance of the control points from their end points. However, instead of getting
    //  all fancy pants in calculating those distances we just throw up our hands and guess that it's a third of the distance between
    //  the two end points. It's a heuristic, and not a good one.
    
    NSBezierPath *result = [NSBezierPath bezierPath];
    [result fb_copyAttributesFrom:self];
    
    CGFloat thirdOfDistance = FBDistanceBetweenPoints([self fb_pointAtIndex:range.location + 1], [self fb_pointAtIndex:range.location]) / 3.0;
    
    [result moveToPoint:[self fb_pointAtIndex:range.location]];
    [result curveToPoint:[self fb_pointAtIndex:range.location + 1] controlPoint1:FBAddPoint([self fb_pointAtIndex:range.location], FBUnitScalePoint(leftTangent, thirdOfDistance)) controlPoint2:FBAddPoint([self fb_pointAtIndex:range.location + 1], FBUnitScalePoint(rightTangent, thirdOfDistance))];
    
    return result;
}

- (NSBezierPath *) fb_fitBezierInRange:(NSRange)range withParameters:(NSArray *)parameters leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent
{
    // We want to create a bezier curve to fit the path. A bezier curve is simply four points:
    //  the two end points, and a control point for each end point. We already have the end points 
    //  (i.e. [self pointAtIndex:range.location] and [self pointAtIndex:range.location+range.length-1])
    //  and the direction of the control points away from the end points (leftTangent and rightTangent). 
    //  The only thing lacking is the distance of the control points from their respective end points.
    //  This function computes those distances, called leftAlpha and rightAlpha, and then constructs
    //  the bezier curve from that.
    //
    // The basic formula used here for fitting a bezier is:
    //
    //  leftEndPoint = [self pointAtIndex:0]
    //  rightEndPoint = [self pointAtIndex:[self elementCount]-1]
    //  leftControlPoint = leftAlpha * leftTangent + leftEndPoint
    //  rightControlPoint = rightAlpha * rightTangent + rightEndPoint

    // By controlling the distance of the control points from their end points, we can affect the curve
    //  of the bezier. We want to chose distances (leftAlpha and rightAlpha) such that it best fits the
    //  points in self. Formally stated, we want to minimize the squared errors as represented by:
    //
    //  S = SUM( (point[i] - Q(parameters[i])) ^ 2 )
    //
    //  Where point[i] is the point on this NSBezierPath at i, parameters[i] is the float in the parameters
    //  NSArray at index i. Q is the bezier curve we're generating in this function. This formula takes
    //  the difference (distance) between a point in this NSBezierPath we're trying to fit, and the corresponding
    //  point in the generated bezier curve, squares it, and adds all the differences up (i.e. squared errors).
    //  This tells us how far off our curve is from our points we're trying to fit. We'd like to minimize this,
    //  when calculating leftAlpha and rightAlpha.
    //
    //  Using the least squares approach we can write the equations we want to solve:
    //
    //  d(S) / d(leftAlpha) = 0
    //  d(S) / d(rightAlpha) = 0
    //
    //  Here d() is the derivative, and S is the squared errors defined above. By then substituting in
    //  S and then Q(t), which is defined as:
    //
    //  Q(t) = SUM(V[i] * Bernstein[i](t))
    //
    //  Where i ranges between [0..3], V is one of the points on the bezier curve. V[0] is the leftEndPoint,
    //  V[1] the leftControlPoint, V[2] the rightControlPoint, and V[3] the rightEndPoint. Berstein[i] is
    //  is a polynomial defined by the Bernstein0(), Bernstein1(), Bernstein2(), Bernstein3() functions
    //  (see their comments for explaination).
    //
    // After much mathematical flagellation, we arrive at the following definitions
    //
    //  leftAlpha = det(X * C2) / det(C1 * C2)
    //  rightAlpha = det(C1 * X) / det(C1 * C2)
    //
    // Where:
    //
    //  C1 = [SUM(A1[i] * A1[i]), SUM(A1[i] * A2[i])]
    //  C2 = [SUM(A1[i] * A2[i]), SUM(A2[i] * A2[i])]
    //  X = [SUM(partOfX * A1[i]), SUM(partOfX * A2[i])]
    //      Where partOfX = (points[i] - (leftEndPoint * Bernstein0(parameters[i]) + leftEndPoint * Bernstein1(parameters[i]) + rightEndPoint * Bernstein2(parameters[i]) + rightEndPoint * Bernstein3(parameters[i])))
    //  A1[i] = leftTangent * Bernstein1(parameters[i])
    //  A2[i] = rightTangent * Bernstein2(parameters[i])
    
    // Create tables for the A values
    NSPoint *a1 = (NSPoint *)calloc(range.length, sizeof(NSPoint));
    NSPoint *a2 = (NSPoint *)calloc(range.length, sizeof(NSPoint));    
    for (NSUInteger i = 0; i < range.length; i++) {
        a1[i] = FBUnitScalePoint(leftTangent, Bernstein1([[parameters objectAtIndex:i] floatValue]));
        a2[i] = FBUnitScalePoint(rightTangent, Bernstein2([[parameters objectAtIndex:i] floatValue]));
    }
    
    // Create the C1, C2, and X matrices
    CGFloat c1[2] = {};
    CGFloat c2[2] = {};
    CGFloat x[2] = {};
    NSPoint partOfX = NSZeroPoint;
    NSPoint leftEndPoint = [self fb_pointAtIndex:range.location];
    NSPoint rightEndPoint = [self fb_pointAtIndex:range.location + range.length - 1];
    for (NSUInteger i = 0; i < range.length; i++) {
        c1[0] += FBDotMultiplyPoint(a1[i], a1[i]);
        c1[1] += FBDotMultiplyPoint(a1[i], a2[i]);
        c2[0] += FBDotMultiplyPoint(a1[i], a2[i]);
        c2[1] += FBDotMultiplyPoint(a2[i], a2[i]);
        
        partOfX = FBSubtractPoint([self fb_pointAtIndex:range.location + i], 
                                  FBAddPoint(FBScalePoint(leftEndPoint, Bernstein0([[parameters objectAtIndex:i] floatValue])),
                                             FBAddPoint(FBScalePoint(leftEndPoint, Bernstein1([[parameters objectAtIndex:i] floatValue])),
                                                        FBAddPoint(FBScalePoint(rightEndPoint, Bernstein2([[parameters objectAtIndex:i] floatValue])),
                                                                   FBScalePoint(rightEndPoint, Bernstein3([[parameters objectAtIndex:i] floatValue]))))));
        
        x[0] += FBDotMultiplyPoint(partOfX, a1[i]);
        x[1] += FBDotMultiplyPoint(partOfX, a2[i]);
    }
    
    // We're done with the A values, so free that up
    free(a1);
    free(a2);

    // Calculate left and right alpha
    CGFloat c1AndC2 = Determinant(c1, c2);
    CGFloat xAndC2 = Determinant(x, c2);
    CGFloat c1AndX = Determinant(c1, x);
    CGFloat leftAlpha = 0.0;
    CGFloat rightAlpha = 0.0;
    if ( c1AndC2 != 0 ) {
        leftAlpha = xAndC2 / c1AndC2;
        rightAlpha = c1AndX / c1AndC2;
    }
    
    // If the alpha values are too small or negative, things aren't going to work out well. Fall back
    //  to the simple heuristic
    CGFloat verySmallValue = 1.0e-6 * FBDistanceBetweenPoints(leftEndPoint, rightEndPoint);
    if ( leftAlpha < verySmallValue || rightAlpha < verySmallValue )
        return [self fb_fitBezierUsingNaiveMethodInRange:range leftTangent:leftTangent rightTangent:rightTangent];
    
    // We already have the end points, so we just need the control points. Use alpha values
    //  to calculate those
    NSPoint leftControlPoint = FBAddPoint(FBUnitScalePoint(leftTangent, leftAlpha), leftEndPoint);
    NSPoint rightControlPoint = FBAddPoint(FBUnitScalePoint(rightTangent, rightAlpha), rightEndPoint);
    
    // Create the bezier path based on the end and control points we calculated
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path fb_copyAttributesFrom:self];
    [path moveToPoint:leftEndPoint];
    [path curveToPoint:rightEndPoint controlPoint1:leftControlPoint controlPoint2:rightControlPoint];
    return path;
}

- (NSArray *) fb_estimateParametersUsingChordLengthMethodInRange:(NSRange)range
{
    // We assume that our bezier curve is represented by the function Q(t), where t has the range of [0..1].
    //  The output of Q(t) is (x, y) coordinates that (hopefully) fit closely to our input
    //  points (i.e the points in this bezier path). In this method we're trying to estimate the 
    //  parameter of the function Q (i.e. t) for each of our input points. For the end points, this is easy:
    //  Q(0) should give us [self fb_pointAtIndex:range.location] and Q(1) should give us
    //  [self fb_pointAtIndex:range.location + range.length - 1]. For the points in between we'll use the
    //  chord length method.
    //
    // The chord length method assumes a straight line between the points is a reasonable estimate for the curve
    //  between the points. Thus we can estimate t for a given point Foo to be distance in between all the points
    //  from the start point up to the point Foo, divided by the distance between all the points (in order to normalize
    //  the distance between [0..1])
    
    NSMutableArray *distances = [NSMutableArray arrayWithCapacity:range.length];
    [distances addObject:[NSNumber numberWithFloat:0.0]]; // First one is always 0 (see above)
    CGFloat totalDistance = 0.0;
    for (NSUInteger i = 1; i < range.length; i++) {
        // Calculate the total distance along the curve up to this point
        totalDistance += FBDistanceBetweenPoints([self fb_pointAtIndex:range.location + i], [self fb_pointAtIndex:range.location + i - 1]);
        [distances addObject:[NSNumber numberWithFloat:totalDistance]];
    }
    
    // Now go through and normalize the distances to in the range [0..1]
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:range.length];
    for (NSNumber *distance in distances)
        [parameters addObject:[NSNumber numberWithFloat:[distance floatValue] / totalDistance]];

    return parameters;
}

- (NSPoint) fb_computeLeftTangentAtIndex:(NSUInteger)index
{
    // Compute the tangent unit vector by computing the vector between the left two points,
    //  then normalizing it so its unit vector.
    return FBNormalizePoint( FBSubtractPoint([self fb_pointAtIndex:index + 1], [self fb_pointAtIndex:index]) );
}

- (NSPoint) fb_computeRightTangentAtIndex:(NSUInteger)index
{
    // Compute the tangent unit vector by computing the vector between the right two points,
    //  then normalizing it so its unit vector.
    return FBNormalizePoint( FBSubtractPoint([self fb_pointAtIndex:index - 1], [self fb_pointAtIndex:index]) );
}

- (NSPoint) fb_computeCenterTangentAtIndex:(NSUInteger)index
{
    // Compute the tangent unit vector with index as the center. We'll calculate the vectors on both sides
    //  of index and then average them together.
    NSPoint vector1 = FBSubtractPoint([self fb_pointAtIndex:index - 1], [self fb_pointAtIndex:index]);
    NSPoint vector2 = FBSubtractPoint([self fb_pointAtIndex:index], [self fb_pointAtIndex:index + 1]);
    return FBNormalizePoint(NSMakePoint((vector1.x + vector2.x) / 2.0, (vector1.y + vector2.y) / 2.0));
}
@end
