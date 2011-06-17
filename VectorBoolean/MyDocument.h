//
//  MyDocument.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CanvasView;

@interface MyDocument : NSDocument {
    IBOutlet CanvasView *_view;
    SEL _resetAction;
}

- (IBAction) onReset:(id)sender;
- (IBAction) onUnion:(id)sender;
- (IBAction) onIntersect:(id)sender;
- (IBAction) onDifference:(id)sender; // Punch
- (IBAction) onJoin:(id)sender; // XOR

- (IBAction) onCircleOverlappingRectangle:(id)sender;
- (IBAction) onCircleInRectangle:(id)sender;
- (IBAction) onRectangleInCircle:(id)sender;
- (IBAction) onCircleOnRectangle:(id)sender;
- (IBAction) onRectangleWithHoleOverlappingRectangle:(id)sender;
- (IBAction) onTwoRectanglesOverlappingCircle:(id)sender;
- (IBAction) onCircleOverlappingCircle:(id)sender;
- (IBAction) onComplexShapes:(id)sender;

@end
