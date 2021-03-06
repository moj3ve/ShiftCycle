#import <UIKit/UIKit.h>
#import <UIKit/UIKeyboardLayoutStar.h>
#import <UIKit/UIKeyboardInput.h>
#import <UIKit/UITextInput.h>

// IPC Notifications for third-party keyboards
#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFNotificationCenter.h>
extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

@interface UIKeyboardImpl : UIView
	+ (UIKeyboardImpl*)activeInstance;
	- (void)insertText:(id)text;

	@property (readonly, assign, nonatomic) UIResponder <UITextInputPrivate> *privateInputDelegate;
	@property (readonly, assign, nonatomic) UIResponder <UITextInput> *inputDelegate;
@end

@interface UIKBKey : NSObject
	@property(copy) NSString * representedString;
@end

@interface WKTextPosition : UITextPosition
	@property (nonatomic) CGRect positionRect;
@end

@interface WKWebView : UIWebView
	-(void)evaluateJavaScript:(id)arg1 completionHandler:(/*^block*/id)arg2;
@end

@interface WKContentView : UITextView {
	WKWebView *_webView;
}
	-(id)selectedText;
	-(void)replaceText:(id)arg1 withText:(id)arg2;
@end

@interface UIPhysicalKeyboardEvent : NSObject
	@property (nonatomic,readonly) BOOL _isKeyDown; 
	@property (nonatomic,readonly) long long _keyCode;		
	- (void*)_hidEvent;		 
@end

// Use to add support for 3rd party keyboards
@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

NSMutableArray *variants = [[NSMutableArray alloc] init];
int variant = 0;
NSString *lastInserted = nil;
bool change = false;
NSRegularExpression *germanRegex = [NSRegularExpression regularExpressionWithPattern:@"(^|\\W)ß" options:NSRegularExpressionCaseInsensitive error:nil];
static NSString *oldPath = @"/var/mobile/Library/Preferences/com.hackingdartmouth.shiftcycle.plist";
static NSString *newPath = @"/var/mobile/Library/Preferences/com.hackingdartmouth.shiftcycle-2.plist";

static NSString *sarcasticify(NSString *original) {
	// split the original string into pieces
	NSMutableArray *chars = [NSMutableArray array];
	[original enumerateSubstringsInRange: NSMakeRange(0, [original length]) options: NSStringEnumerationByComposedCharacterSequences
			usingBlock: ^(NSString *inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
			[chars addObject:inSubstring];
	}];

	// capitalize
	NSMutableString *result = [@"" mutableCopy];
	BOOL capitalize = YES;
	for (int i = 0; i < [chars count]; i++) {
		if (capitalize) {
			[result appendString:[[chars[i] stringByReplacingOccurrencesOfString:@"ß" withString:@"ẞ"] uppercaseString]];
		} else {
			[result appendString:[chars[i] lowercaseString]];
		}
		if ([[chars[i] stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet]] isEqualToString:@""]) {
			capitalize = !capitalize;
		}
	}

	return result;
}

// Function that takes in a string and fills a mutable array with all of the possible variants
static void fillArray(NSString *original) {
	// Initialize
	variants = [[NSMutableArray alloc] init];

	// Check to see if the selected section actually has text
	if ([original length] == 0) return;

	// Add in the original
	[variants addObject:original];
	variant = 0;

	// Check if the new path has been switched over
	NSMutableArray *cycles = [[NSMutableArray alloc] initWithContentsOfFile:newPath];
	if (cycles == nil) {
		// Pulls in options set in Settings pane to determine which are enabled cycles
		NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:oldPath];

		NSNumber *uppercaseS = [settings objectForKey:@"uppercase"];
		NSNumber *lowercaseS = [settings objectForKey:@"lowercase"];
		NSNumber *capitalizedS = [settings objectForKey:@"capitalized"];
		NSNumber *concatS = [settings objectForKey:@"concatenated"];
		NSNumber *sarcasticS = [settings objectForKey:@"sarcastic"];

		BOOL upper = (uppercaseS == nil || uppercaseS.integerValue == 1);
		BOOL lower = (lowercaseS == nil || lowercaseS.integerValue == 1);
		BOOL capital = (capitalizedS == nil || capitalizedS.integerValue == 1);
		BOOL conc = (concatS == nil || concatS.integerValue == 1);
		BOOL sarc = (sarcasticS == nil || sarcasticS.integerValue == 1);

		// uppercase is hardcoded to fix German's weird capitalization change of ß in 2010
		NSString *uppercase = [[original stringByReplacingOccurrencesOfString:@"ß" withString:@"ẞ"] uppercaseString];
		NSString *lowercase = [original lowercaseString];
		NSString *capitalized = [[germanRegex stringByReplacingMatchesInString:original options:0 range:NSMakeRange(0, [original length]) withTemplate:@"$1ẞ"] capitalizedString];
		NSString *concat = [capitalized stringByReplacingOccurrencesOfString:@" " withString:@""];
		NSString *sarcastic = sarcasticify(original);
		if (![variants containsObject:uppercase] && upper)
			[variants addObject:uppercase];
		if (![variants containsObject:lowercase] && lower)
			[variants addObject:lowercase];
		if (![variants containsObject:capitalized] && capital)
			[variants addObject:capitalized];
		if (![variants containsObject:concat] && conc)
			[variants addObject:concat];
		if (![variants containsObject:sarcastic] && sarc)
			[variants addObject:sarcastic];
	} else { // Use the new saved ordered system
		for (int i = 0; i < [cycles count]; i++) {
			BOOL enabled = ([cycles[i][2] boolValue]);
			
			if (enabled) {
				NSString *cycleType = cycles[i][0];
				NSString *newString = nil;
				if ([cycleType isEqualToString:@"uppercase"]) {
					newString = [[original stringByReplacingOccurrencesOfString:@"ß" withString:@"ẞ"] uppercaseString];
				} else if ([cycleType isEqualToString:@"lowercase"]) {
					newString = [original lowercaseString];
				} else if ([cycleType isEqualToString:@"capitalized"]) {
					newString = [[germanRegex stringByReplacingMatchesInString:original options:0 range:NSMakeRange(0, [original length]) withTemplate:@"$1ẞ"] capitalizedString];
				} else if ([cycleType isEqualToString:@"concatenated"]) {
					newString = [[[germanRegex stringByReplacingMatchesInString:original options:0 range:NSMakeRange(0, [original length]) withTemplate:@"$1ẞ"] capitalizedString] stringByReplacingOccurrencesOfString:@" " withString:@""];
				} else if ([cycleType isEqualToString:@"sarcastic"]) {
					newString = sarcasticify(original);
				}
				if (![variants containsObject:newString])
					[variants addObject:newString];
			}
		}
	}
}

// Handles the text replacement
static void textReplace() {
	// Gets the current keyboard implementation
	UIKeyboardImpl *impl = [%c(UIKeyboardImpl) activeInstance];

	id delegate = impl.inputDelegate ?: impl.privateInputDelegate;

	// Cycles to the new one to insert
	variant = (variant + 1) % (int)[variants count];

	change = true;
	// Works around Safari's broken text handling by injecting javascript
	if ([NSStringFromClass([delegate class]) isEqualToString:@"WKContentView"]) {
		NSString *selectedString = [delegate selectedText];

		if ([selectedString length] > 0) {
			NSString *text = [variants objectAtIndex:variant];

			// Gets the current input, replaces the text, and re-selects
			NSString *js = [NSString stringWithFormat:@"var repl = '%@'; var el = document.activeElement; var tagName = el ? el.tagName.toLowerCase() : null; if ((tagName == 'textarea' || tagName == 'input') && (typeof el.selectionStart == 'number')) { var val = el.value; var start = el.selectionStart; var end = el.selectionEnd; var text = val.slice(start, end); el.value = val.slice(0, start) + repl + val.slice(end); el.selectionStart = start; el.selectionEnd = start + repl.length; } ", text];
			WKWebView *webView = MSHookIvar<WKWebView*>(delegate, "_webView");
			[webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
				change = false;
				lastInserted = text;
			}];
		}
	} else {
		NSString *selectedString = [delegate textInRange:[delegate selectedTextRange]];
		if ([selectedString length] > 0) {
			// Inserts in the proper string
			// Slightly longer than necessary due to emojis being one character but length two (and flags being length 4)
			NSInteger offset = [delegate offsetFromPosition:[delegate beginningOfDocument] toPosition:[[delegate selectedTextRange] start]];
			NSString *text = [variants objectAtIndex:variant];
			[delegate insertText:text];
			UITextPosition *from = [delegate positionFromPosition:[delegate beginningOfDocument] offset:offset];
			UITextPosition *to = [delegate positionFromPosition:from offset:text.length];
			[delegate setSelectedTextRange:[delegate textRangeFromPosition:from toPosition:to]];

			lastInserted = text;
		}
		change = false;
	}
}

%hook UIKeyboardLayoutStar
	// Overrides shift key on selected text
	- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
		UITouch *touch = [touches anyObject];
		NSString *key = [[[self keyHitTest:[touch locationInView:touch.view]] representedString] lowercaseString];

		if ([key isEqualToString:@"shift"] && (int)[variants count] > 0) {
			textReplace();
		}
		%orig;
	}
%end

// Handles Safari's broken selection detection
%hook WKContentView
	-(void)_selectionChanged {
		%orig;

		if (!change) {
			UIKeyboardImpl *impl = [%c(UIKeyboardImpl) activeInstance];

			id delegate = impl.privateInputDelegate ?: impl.inputDelegate;

			// Triggers whenever the bounds change and also just seemingly randomly
			if ([NSStringFromClass([delegate class]) isEqualToString:@"WKContentView"]) {
				NSString *selectedString = (NSString *)[(WKContentView *)delegate selectedText];
			
				double start_x = [(WKTextPosition *)[[delegate selectedTextRange] start] positionRect].origin.x;
				double start_y = [(WKTextPosition *)[[delegate selectedTextRange] start] positionRect].origin.y;
				double end_x = [(WKTextPosition *)[[delegate selectedTextRange] end] positionRect].origin.x;
				double end_y = [(WKTextPosition *)[[delegate selectedTextRange] end] positionRect].origin.y;

				double size = [(WKTextPosition *)[[delegate selectedTextRange] start] positionRect].size.width;

				// Check if there's something selected
				if (start_x < (end_x - size) && start_y <= end_y) {
					// Check that it wasn't what you just inserted (to keep from wiping initial configs)
					if (![selectedString isEqualToString:lastInserted]) {
						fillArray(selectedString);
						lastInserted = nil;
					}
				} else {
					variants = [[NSMutableArray alloc] init];
					lastInserted = nil;
				}
			}
		}
	}
%end

// Third party notification handler
void thirdPartyShift(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	if ((int)[variants count] > 0) {
		textReplace();
	}
}

%hook UIKeyboardImpl
	- (id)initWithFrame:(CGRect)arg1 {
		// Remove any current ones, and add your own (keep up to date with only one observer)
		CFNotificationCenterRemoveObserver(CFNotificationCenterGetDistributedCenter(), NULL, CFSTR("com.hackingdartmouth.shiftcycle.thirdpartyshift"), NULL);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
			NULL,
			&thirdPartyShift,
			CFSTR("com.hackingdartmouth.shiftcycle.thirdpartyshift"),
			NULL,
			CFNotificationSuspensionBehaviorDeliverImmediately);
		return %orig;
	}

	-(void)updateForChangedSelection {
		%orig;

		if (!change) {
			id inpd = self.privateInputDelegate ?: self.inputDelegate;

			NSString *selectedString = nil;

			// Triggers when tapping and choosing 'Select', not when adjusting the bounds
			if ([NSStringFromClass([inpd class]) isEqualToString:@"WKContentView"]) {
				double start_x = [(WKTextPosition *)[[inpd selectedTextRange] start] positionRect].origin.x;
				double start_y = [(WKTextPosition *)[[inpd selectedTextRange] start] positionRect].origin.y;
				double end_x = [(WKTextPosition *)[[inpd selectedTextRange] end] positionRect].origin.x;
				double end_y = [(WKTextPosition *)[[inpd selectedTextRange] end] positionRect].origin.y;

				double size = [(WKTextPosition *)[[inpd selectedTextRange] start] positionRect].size.width;

				// Check if there's something selected
				if (start_x < (end_x - size) && start_y <= end_y) {
					selectedString = (NSString *)[(WKContentView *)inpd selectedText];
					lastInserted = nil;
				} else {
					variants = [[NSMutableArray alloc] init];
					return;
				}
			} else {
				UITextRange *selRange = [inpd selectedTextRange];

				if ([selRange isEmpty]) {
					variants = [[NSMutableArray alloc] init];
					return;
				} else {
					selectedString = [inpd textInRange:[inpd selectedTextRange]];
				}
			}

			fillArray(selectedString);
		}
	}

	// Handles built in keyboard caps-lock key
	-(void)handleKeyEvent:(id)arg1 {
		UIPhysicalKeyboardEvent *key = (UIPhysicalKeyboardEvent *)arg1;
		if ([key _isKeyDown]) { // trigger on keydown not keyup
			if ([key _hidEvent]) { // if this is nil (whenever a press is made on the built in keyboard), the call to _keyCode will fail
				if ([key _keyCode] == 57	&& (int)[variants count] > 0) // caps-lock
					textReplace();
			}
		}
		%orig;
	}
%end

// SwiftKey compatibility (hook into 'Shift' key touchUp)
%hook SKKeyboardShiftKey // (SKKeyboardCharacterKey general key)
	-(void)touchUpInsideAtPoint:(id)arg1 activeTouch:(id)arg2 matchingTouchDown:(id)arg3 movedOutsideKey:(id)arg4 {
		CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(),
			CFSTR("com.hackingdartmouth.shiftcycle.thirdpartyshift"), 
			NULL, 
			NULL,
			kCFNotificationDeliverImmediately);
		%orig;
	}
%end