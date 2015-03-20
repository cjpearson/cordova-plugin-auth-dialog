//
//  UIWebView+AuthDialog.m
//
//
//

#import <objc/runtime.h>
#import "UIWebView+AuthDialog.h"
#import "AuthenticationDialog.h"

@interface UIWebView ()
-(void)webView:(id)webview resource:(id)resource didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge fromDataSource:(id)dataSource;
@end

@implementation UIWebView (AuthDialog)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(webView:resource:didReceiveAuthenticationChallenge:fromDataSource:);
        SEL swizzledSelector = @selector(AD_webView:resource:didReceiveAuthenticationChallenge:fromDataSource:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        if(didAddMethod){
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        }
        else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

NSMutableArray* challenges;
static BOOL alertShowing;

-(void)AD_webView:(id)webview resource:(id)resource didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge fromDataSource:(id)dataSource {
    
    NSLog(@"Auth Dialog: Attempts: %@, URL: %@", @([challenge previousFailureCount]), [[dataSource request] URL]);
    
    if(!challenges){
        challenges = [NSMutableArray new];
    }
    [challenges addObject:challenge];

    if (!alertShowing){
        CredentialsViewController* credentialsViewController = [CredentialsViewController new];
        UIAlertView* view = [[UIAlertView alloc] initWithTitle:@"Authentication Required"
                                                       message:nil
                                                      delegate:credentialsViewController
                                             cancelButtonTitle:@"Cancel"
                                             otherButtonTitles:@"Log In", nil];
        
        view.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
        
        objc_setAssociatedObject(view, _cmd, credentialsViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [view show];
        
        alertShowing = YES;
        
        credentialsViewController.onResult = ^(NSString * userName, NSString* password, BOOL isCancelled)  {
            alertShowing = NO;
            NSLog(@"Auth Dialog: Resolving challenges");
            for (NSURLAuthenticationChallenge* challenge in challenges){
                [[challenge sender] useCredential:[NSURLCredential credentialWithUser:userName
                                                                             password:password
                                                                          persistence:NSURLCredentialPersistencePermanent]
                       forAuthenticationChallenge:challenge];
            }
            [challenges removeAllObjects];
        };
    }
}
@end
