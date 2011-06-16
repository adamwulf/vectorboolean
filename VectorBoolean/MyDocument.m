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

- (void) addRectangle:(NSRect)rect;
- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius;

- (void) addRectangle:(NSRect)rect toPath:(NSBezierPath *)rectangle;
- (void) addCircleAtPoint:(NSPoint)center withRadius:(CGFloat)radius toPath:(NSBezierPath *)circle;

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
    }
    
    return YES;
}

@end
