//
//  MyDocument.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "MyDocument.h"
#import "CanvasView.h"
#import "Canvas.h"
#import "NSBezierPath+Boolean.h"

@interface MyDocument ()

- (void) addSomeOverlap;
- (void) addCircleInRectangle;
- (void) addRectangleInCircle;
- (void) addCircleOnRectangle;
- (void) addHoleyRectangleWithRectangle;
- (void) addCircleOnTwoRectangles;
- (void) addCircleOverlappingCircle;
- (void) addComplexShapes;
- (void) addComplexShapes2;
- (void) addTriangleInsideRectangle;
- (void) addDiamondOverlappingRectangle;
- (void) addDiamondInsideRectangle;

- (void) addRectangle:(NSRect)rect;
- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius;
- (void) addTriangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3;
- (void) addQuadrangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 point4:(NSPoint)point4;

- (void) addRectangle:(NSRect)rect toPath:(NSBezierPath *)rectangle;
- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius toPath:(NSBezierPath *)circle;
- (void) addTriangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 toPath:(NSBezierPath *)path;
- (void) addQuadrangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 point4:(NSPoint)point4 toPath:(NSBezierPath *)path;

@end

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
        _resetAction = @selector(addCircleOnRectangle);
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    
    [self onReset:nil];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    /*
     Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    /*
    Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return YES;
}

- (IBAction) onReset:(id)sender
{
    [_view.canvas clear];
    
    [self performSelector:_resetAction];
    
    [_view setNeedsDisplay:YES];
}

- (void) addSomeOverlap
{
    [self addRectangle:NSMakeRect(50, 50, 300, 200)];
    [self addCircleAtPoint:NSMakePoint(355, 240) withRadius:125];
}

- (void) addCircleInRectangle
{
    [self addRectangle:NSMakeRect(50, 50, 350, 300)];
    [self addCircleAtPoint:NSMakePoint(210, 200) withRadius:125];    
}

- (void) addRectangleInCircle
{
    [self addRectangle:NSMakeRect(150, 150, 150, 150)];
    [self addCircleAtPoint:NSMakePoint(200, 200) withRadius:185];    
}

- (void) addCircleOnRectangle
{
    [self addRectangle:NSMakeRect(15, 15, 370, 370)];
    [self addCircleAtPoint:NSMakePoint(200, 200) withRadius:185];    
}

- (void) addHoleyRectangleWithRectangle
{
    NSBezierPath *holeyRectangle = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(50, 50, 350, 300) toPath:holeyRectangle];
    [self addCircleAtPoint:NSMakePoint(210, 200) withRadius:125 toPath:holeyRectangle];    
    [_view.canvas addPath:holeyRectangle withColor:[NSColor blueColor]];

    NSBezierPath *rectangle = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(180, 5, 100, 400) toPath:rectangle];
    [_view.canvas addPath:rectangle withColor:[NSColor redColor]];
}

- (void) addCircleOnTwoRectangles
{
    NSBezierPath *rectangles = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(50, 5, 100, 400) toPath:rectangles];
    [self addRectangle:NSMakeRect(350, 5, 100, 400) toPath:rectangles];
    [_view.canvas addPath:rectangles withColor:[NSColor blueColor]];

    [self addCircleAtPoint:NSMakePoint(200, 200) withRadius:185];    
}

- (void) addCircleOverlappingCircle
{
    NSBezierPath *circle = [NSBezierPath bezierPath];
    [self addCircleAtPoint:NSMakePoint(210, 110) withRadius:100 toPath:circle];
    [_view.canvas addPath:circle withColor:[NSColor blueColor]];
    
    [self addCircleAtPoint:NSMakePoint(355, 240) withRadius:125];
}

- (void) addComplexShapes
{
    NSBezierPath *holeyRectangle = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(50, 50, 350, 300) toPath:holeyRectangle];
    [self addCircleAtPoint:NSMakePoint(210, 200) withRadius:125 toPath:holeyRectangle];    

    NSBezierPath *rectangle = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(180, 5, 100, 400) toPath:rectangle];

    NSBezierPath *allParts = [holeyRectangle fb_union:rectangle];
    NSBezierPath *intersectingParts = [holeyRectangle fb_intersect:rectangle];
    
    [_view.canvas addPath:allParts withColor:[NSColor blueColor]];
    [_view.canvas addPath:intersectingParts withColor:[NSColor redColor]];
}

- (void) addComplexShapes2
{
    NSBezierPath *rectangles = [NSBezierPath bezierPath];
    [self addRectangle:NSMakeRect(50, 5, 100, 400) toPath:rectangles];
    [self addRectangle:NSMakeRect(350, 5, 100, 400) toPath:rectangles];

    NSBezierPath *circle = [NSBezierPath bezierPath];
    [self addCircleAtPoint:NSMakePoint(200, 200) withRadius:185 toPath:circle];    

    NSBezierPath *allParts = [rectangles fb_union:circle];
    NSBezierPath *intersectingParts = [rectangles fb_intersect:circle];

    [_view.canvas addPath:allParts withColor:[NSColor blueColor]];
    [_view.canvas addPath:intersectingParts withColor:[NSColor redColor]];
}

- (void) addTriangleInsideRectangle
{
    [self addRectangle:NSMakeRect(100, 100, 300, 300)];
    [self addTriangle:NSMakePoint(100, 400) point2:NSMakePoint(400, 400) point3:NSMakePoint(250, 250)];
}

- (void) addDiamondOverlappingRectangle
{
    [self addRectangle:NSMakeRect(50, 50, 200, 200)];
    [self addQuadrangle:NSMakePoint(50, 250) point2:NSMakePoint(150, 400) point3:NSMakePoint(250, 250) point4:NSMakePoint(150, 100)];
}

- (void) addDiamondInsideRectangle
{
    [self addRectangle:NSMakeRect(100, 100, 300, 300)];
    [self addQuadrangle:NSMakePoint(100, 250) point2:NSMakePoint(250, 400) point3:NSMakePoint(400, 250) point4:NSMakePoint(250, 100)];
}

- (void) addRectangle:(NSRect)rect
{
    NSBezierPath *rectangle = [NSBezierPath bezierPath];
    [self addRectangle:rect toPath:rectangle];
    [_view.canvas addPath:rectangle withColor:[NSColor blueColor]];
}

- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius
{
    NSBezierPath *circle = [NSBezierPath bezierPath];
    [self addCircleAtPoint:center withRadius:radius toPath:circle];
    [_view.canvas addPath:circle withColor:[NSColor redColor]];
}

- (void) addTriangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3
{
    NSBezierPath *triangle = [NSBezierPath bezierPath];
    [self addTriangle:point1 point2:point2 point3:point3 toPath:triangle];
    [_view.canvas addPath:triangle withColor:[NSColor redColor]];
}

- (void) addQuadrangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 point4:(NSPoint)point4
{
    NSBezierPath *quandrangle = [NSBezierPath bezierPath];
    [self addQuadrangle:point1 point2:point2 point3:point3 point4:point4 toPath:quandrangle];
    [_view.canvas addPath:quandrangle withColor:[NSColor redColor]];
}

- (void) addRectangle:(NSRect)rect toPath:(NSBezierPath *)rectangle
{
    [rectangle moveToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
    [rectangle lineToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
    [rectangle lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
    [rectangle lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
    [rectangle lineToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
}

- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius toPath:(NSBezierPath *)circle
{
    static const CGFloat FBMagicNumber = 0.55228475;
    CGFloat controlPointLength = radius * FBMagicNumber;
    [circle moveToPoint:NSMakePoint(center.x - radius, center.y)];
    [circle curveToPoint:NSMakePoint(center.x, center.y + radius) controlPoint1:NSMakePoint(center.x - radius, center.y + controlPointLength) controlPoint2:NSMakePoint(center.x - controlPointLength, center.y + radius)];
    [circle curveToPoint:NSMakePoint(center.x + radius, center.y) controlPoint1:NSMakePoint(center.x + controlPointLength, center.y + radius) controlPoint2:NSMakePoint(center.x + radius, center.y + controlPointLength)];
    [circle curveToPoint:NSMakePoint(center.x, center.y - radius) controlPoint1:NSMakePoint(center.x + radius, center.y - controlPointLength) controlPoint2:NSMakePoint(center.x + controlPointLength, center.y - radius)];
    [circle curveToPoint:NSMakePoint(center.x - radius, center.y) controlPoint1:NSMakePoint(center.x - controlPointLength, center.y - radius) controlPoint2:NSMakePoint(center.x - radius, center.y - controlPointLength)];
}

- (void) addTriangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 toPath:(NSBezierPath *)path
{
    [path moveToPoint:point1];
    [path lineToPoint:point2];
    [path lineToPoint:point3];
    [path lineToPoint:point1];
}

- (void) addQuadrangle:(NSPoint)point1 point2:(NSPoint)point2 point3:(NSPoint)point3 point4:(NSPoint)point4 toPath:(NSBezierPath *)path
{
    [path moveToPoint:point1];
    [path lineToPoint:point2];
    [path lineToPoint:point3];
    [path lineToPoint:point4];
    [path lineToPoint:point1];
}


- (IBAction) onUnion:(id)sender
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_union:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onIntersect:(id)sender
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_intersect:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onDifference:(id)sender // Punch
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_difference:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onJoin:(id)sender // XOR
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_xor:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onCircleOverlappingRectangle:(id)sender
{
    _resetAction = @selector(addSomeOverlap);
    [self onReset:sender];
}

- (IBAction) onCircleInRectangle:(id)sender
{
    _resetAction = @selector(addCircleInRectangle);
    [self onReset:sender];
}

- (IBAction) onRectangleInCircle:(id)sender
{
    _resetAction = @selector(addRectangleInCircle);
    [self onReset:sender];
}

- (IBAction) onCircleOnRectangle:(id)sender
{
    _resetAction = @selector(addCircleOnRectangle);
    [self onReset:sender];
}

- (IBAction) onRectangleWithHoleOverlappingRectangle:(id)sender
{
    _resetAction = @selector(addHoleyRectangleWithRectangle);
    [self onReset:sender];
}

- (IBAction) onTwoRectanglesOverlappingCircle:(id)sender
{
    _resetAction = @selector(addCircleOnTwoRectangles);
    [self onReset:sender];
}

- (IBAction) onCircleOverlappingCircle:(id)sender
{
    _resetAction = @selector(addCircleOverlappingCircle);
    [self onReset:sender];    
}

- (IBAction) onComplexShapes:(id)sender
{
    _resetAction = @selector(addComplexShapes);
    [self onReset:sender];        
}

- (IBAction) onComplexShapes2:(id)sender
{
    _resetAction = @selector(addComplexShapes2);
    [self onReset:sender];        
}

- (IBAction) onTriangleInsideRectangle:(id)sender
{
    _resetAction = @selector(addTriangleInsideRectangle);
    [self onReset:sender];        
}

- (IBAction) onDiamondOverlappingRectangle:(id)sender
{
    _resetAction = @selector(addDiamondOverlappingRectangle);
    [self onReset:sender];        
}

- (IBAction) onDiamondInsideRectangle:(id)sender
{
    _resetAction = @selector(addDiamondInsideRectangle);
    [self onReset:sender];        
}

- (IBAction) onShowPoints:(id)sender
{
    _view.canvas.showPoints = !_view.canvas.showPoints;
    [_view setNeedsDisplay:YES];
}

- (IBAction) onShowIntersections:(id)sender
{
    _view.canvas.showIntersections = !_view.canvas.showIntersections;
    [_view setNeedsDisplay:YES];    
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    NSMenuItem *menuItem = (NSMenuItem *)anItem;
    if ( [anItem action] == @selector(onCircleOverlappingRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addSomeOverlap) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onCircleInRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addCircleInRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onRectangleInCircle:) ) {
        [menuItem setState:_resetAction == @selector(addRectangleInCircle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onCircleOnRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addCircleOnRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onRectangleWithHoleOverlappingRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addHoleyRectangleWithRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onTwoRectanglesOverlappingCircle:) ) {
        [menuItem setState:_resetAction == @selector(addCircleOnTwoRectangles) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onCircleOverlappingCircle:) ) {
        [menuItem setState:_resetAction == @selector(addCircleOverlappingCircle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onComplexShapes:) ) {
        [menuItem setState:_resetAction == @selector(addComplexShapes) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onComplexShapes2:) ) {
        [menuItem setState:_resetAction == @selector(addComplexShapes2) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onTriangleInsideRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addTriangleInsideRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onDiamondOverlappingRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addDiamondOverlappingRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onDiamondInsideRectangle:) ) {
        [menuItem setState:_resetAction == @selector(addDiamondInsideRectangle) ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onShowPoints:) ) {
        [menuItem setState:_view.canvas.showPoints ? NSOnState : NSOffState];
    } else if ( [anItem action] == @selector(onShowIntersections:) ) {
        [menuItem setState:_view.canvas.showIntersections ? NSOnState : NSOffState];
    }

    
    return YES;
}

@end
