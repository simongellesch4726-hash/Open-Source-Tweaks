/*
 * Tweak.x
 * Indicators
 *
 * Created by Zachary Thomas Paul <LacertosusThemes@gmail.com> on 5/27/2021.
 * Copyright © 2021 LacertosusDeus <LacertosusThemes@gmail.com>. All rights reserved.
 */
#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
@import Alderis;
#import "AlderisColorPicker.h"
#import "Indicators.h"
#import "HBLog.h"

    //Preferences
  static NSInteger indicatorSpacing;

  static BOOL showFlashlightIndicator;
  static NSString *flLightColor;
  static NSString *flDarkColor;

  static BOOL showVPNIndicator;
  static NSString *vpnLightColor;
  static NSString *vpnDarkColor;

  static BOOL showDNDIndicator;
  static NSString *dndLightColor;
  static NSString *dndDarkColor;

    //Variables
  SBRecordingIndicatorViewController *recordingIndicatorViewController;
  SBRecordingIndicatorView *flashlightIndicator;
  SBRecordingIndicatorView *vpnIndicator;
  SBRecordingIndicatorView *dndIndicator;

%hook SBRecordingIndicatorViewController
  // iOS 17 still calculates the indicator geometry before the recording indicator is displayed.
  // Initialize our additional indicators after Apple has established _center and _size.
  -(void)calculateInitialIndicatorPositionAndSize {
    %orig;
    [self ir_setupIndicatorsIfNeeded];
  }

%new
  -(void)ir_setupIndicatorsIfNeeded {
    if(flashlightIndicator || !self.view) {
      return;
    }

    recordingIndicatorViewController = self;

        //Add observer for flashlight level notification, this is not called when the camera flash is turn on
        //Add observer for vpn connection notification
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ir_updateIndicatorForFlashlightState:) name:@"FlashlightLevel" object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ir_updateIndicatorForVPNState:) name:@"SBVPNConnectionChangedNotification" object:nil];

        //Add state listener for DND
      Class dndConnectionClass = %c(DNDRemoteServiceConnection);
      if(dndConnectionClass && [dndConnectionClass respondsToSelector:@selector(sharedInstance)]) {
        DNDRemoteServiceConnection *connection = [dndConnectionClass sharedInstance];
        if(connection && [connection respondsToSelector:@selector(addEventListener:)]) {
          [connection addEventListener:self];
        }
      }

        //Create flashlight indicator
      flashlightIndicator = [[%c(SBRecordingIndicatorView) alloc] init];
      flashlightIndicator.alpha = 0;
      flashlightIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:flLightColor] darkColor:[UIColor PF_colorWithHex:flDarkColor]];;
      flashlightIndicator.translatesAutoresizingMaskIntoConstraints = NO;
      [self.view addSubview:flashlightIndicator];

        //Create VPN indicator
      vpnIndicator = [[%c(SBRecordingIndicatorView) alloc] init];
      vpnIndicator.alpha = 0;
      vpnIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:vpnLightColor] darkColor:[UIColor PF_colorWithHex:vpnDarkColor]];;
      vpnIndicator.translatesAutoresizingMaskIntoConstraints = NO;
      [self.view addSubview:vpnIndicator];

        //Create DND indicator
      dndIndicator = [[%c(SBRecordingIndicatorView) alloc] init];
      dndIndicator.alpha = 0;
      dndIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:dndLightColor] darkColor:[UIColor PF_colorWithHex:dndDarkColor]];;
      dndIndicator.translatesAutoresizingMaskIntoConstraints = NO;
      [self.view addSubview:dndIndicator];

        //Add constraints
      CGPoint center = [[self valueForKey:@"_center"] CGPointValue];
      CGFloat xConstant = (self.view.bounds.size.width / 2) * -1;

      [NSLayoutConstraint activateConstraints:@[
        [flashlightIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + indicatorSpacing],
        [flashlightIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],

        [flashlightIndicator.widthAnchor constraintEqualToConstant:0],
        [flashlightIndicator.heightAnchor constraintEqualToConstant:0],

        [vpnIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + (indicatorSpacing * [self ir_spacingMultiplierForIndicatorType:IRIndicatorTypeVPN])],
        [vpnIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],

        [vpnIndicator.widthAnchor constraintEqualToConstant:0],
        [vpnIndicator.heightAnchor constraintEqualToConstant:0],

        [dndIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + (indicatorSpacing * [self ir_spacingMultiplierForIndicatorType:IRIndicatorTypeDND])],
        [dndIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],

        [dndIndicator.widthAnchor constraintEqualToConstant:0],
        [dndIndicator.heightAnchor constraintEqualToConstant:0]
      ]];
  }

  // DND state changes aren't sent after a respring, so we check once
  -(void)viewDidAppear:(BOOL)arg1 {
    %orig;

    Class requestDetailsClass = %c(DNDRequestDetails);
    Class dndConnectionClass = %c(DNDRemoteServiceConnection);
    if(!requestDetailsClass || !dndConnectionClass ||
       ![requestDetailsClass respondsToSelector:@selector(detailsRepresentingNowWithClientIdentifier:)] ||
       ![dndConnectionClass respondsToSelector:@selector(sharedInstance)]) {
      return;
    }

    DNDRequestDetails *requestDetails = [requestDetailsClass detailsRepresentingNowWithClientIdentifier:@"com.apple.donotdisturb.control-center.module"];
    DNDRemoteServiceConnection *connection = [dndConnectionClass sharedInstance];
    if(!connection || ![connection respondsToSelector:@selector(queryStateWithRequestDetails:completionHandler:)]) {
      return;
    }

    [connection queryStateWithRequestDetails:requestDetails completionHandler:^(DNDState *state, NSError *error) {
      if(!error && state && dndIndicator) {
        CGFloat size = [[self valueForKey:@"_size"] floatValue];
        if([state isActive]) {
          [dndIndicator ir_startShowAnimatorForIndicatorWithSize:size];
        } else {
          [dndIndicator ir_startHideAnimatorForIndicator];
        }
      } else {
        HBLogError(@"Indicators - Error checking DND status: %@", error);
      }
    }];
  }

%new  //Helper method to determine spacing between indicators
  -(NSInteger)ir_spacingMultiplierForIndicatorType:(IRIndicatorType)indicatorType  {
    if(indicatorType  == IRIndicatorTypeVPN) {
      return (showFlashlightIndicator) ? 2 : 1;
    }

    if(indicatorType == IRIndicatorTypeDND) {
      if(showFlashlightIndicator && showVPNIndicator) {
        return 3;
      }

      if((!showFlashlightIndicator && showVPNIndicator) || (showFlashlightIndicator && !showVPNIndicator)) {
        return 2;
      }

      if(!showFlashlightIndicator && showVPNIndicator) {
        return 1;
      }
    }

    return 1;
  }

%new  //Update indicators
  -(void)ir_updateIndicators {
    if(flashlightIndicator && vpnIndicator && dndIndicator) {
      flashlightIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:flLightColor] darkColor:[UIColor PF_colorWithHex:flDarkColor]];;
      vpnIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:vpnLightColor] darkColor:[UIColor PF_colorWithHex:vpnDarkColor]];;
      dndIndicator.backgroundColor = [UIColor dynamicColorWithLightColor:[UIColor PF_colorWithHex:dndLightColor] darkColor:[UIColor PF_colorWithHex:dndDarkColor]];;

      CGPoint center = [[self valueForKey:@"_center"] CGPointValue];
      CGFloat xConstant = (self.view.bounds.size.width / 2) * -1;

      [NSLayoutConstraint activateConstraints:@[
        [flashlightIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + indicatorSpacing],
        [flashlightIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],

        [vpnIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + (indicatorSpacing * [self ir_spacingMultiplierForIndicatorType:IRIndicatorTypeVPN])],
        [vpnIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],

        [dndIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:xConstant + center.x + (indicatorSpacing * [self ir_spacingMultiplierForIndicatorType:IRIndicatorTypeDND])],
        [dndIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:((self.view.bounds.size.height / 2) - center.y) * -1],
      ]];
    }
  }

%new  //Flashlight updates
  -(void)ir_updateIndicatorForFlashlightState:(NSNotification *)notification {
    if(showFlashlightIndicator && flashlightIndicator) {
      NSDictionary *userInfo = notification.userInfo;
      BOOL state = [userInfo[@"FlashlightValue"] floatValue] > 0;

      if(state) {
        CGFloat size = [[self valueForKey:@"_size"] floatValue];
        [flashlightIndicator ir_startShowAnimatorForIndicatorWithSize:size];
      }

      if(!state) {
        [flashlightIndicator ir_startHideAnimatorForIndicator];
      }
    }
  }

%new  //VPN updates
  -(void)ir_updateIndicatorForVPNState:(NSNotification *)notification {
    if(showVPNIndicator && vpnIndicator) {
      BOOL state = [[%c(SBTelephonyManager) sharedTelephonyManager] isUsingVPNConnection];

      if(state) {
        CGFloat size = [[self valueForKey:@"_size"] floatValue];
        [vpnIndicator ir_startShowAnimatorForIndicatorWithSize:size];
      }

      if(!state) {
        [vpnIndicator ir_startHideAnimatorForIndicator];
      }
    }
  }

%new  //DND updates
  -(void)remoteService:(DNDRemoteServiceConnection *)service didReceiveDoNotDisturbStateUpdate:(DNDStateUpdate *)stateUpdate {
    if(showDNDIndicator && dndIndicator) {
      BOOL state = [stateUpdate.state isActive];

      if(state) {
        CGFloat size = [[self valueForKey:@"_size"] floatValue];
        [dndIndicator ir_startShowAnimatorForIndicatorWithSize:size];
      }

      if(!state) {
        [dndIndicator ir_startHideAnimatorForIndicator];
      }
    }
  }

%new  //Required method by DNDRemoteServiceConnectionEventListener
  -(NSString *)clientIdentifier {
    return @"com.lacertosusrepo.indicators";
  }
%end

  //Add the animators to every instance of SBRecordingIndicatorView so we can stop the animators for ONE indicator
%hook SBRecordingIndicatorView
%property (nonatomic, retain) UIViewPropertyAnimator *overScaleAnimation;
%property (nonatomic, retain) UIViewPropertyAnimator *normalScaleAnimation;
%property (nonatomic, retain) UIViewPropertyAnimator *restScaleAnimation;
%property (nonatomic, retain) UIViewPropertyAnimator *zeroScaleAnimation;

%new  //Create and start animators for showing indicator
  -(void)ir_startShowAnimatorForIndicatorWithSize:(CGFloat)size {
      //Stop active animators
    [self ir_stopAllAnimations];

      //Create animators
    dispatch_async(dispatch_get_main_queue(), ^{
        //Scale to large dot
      self.overScaleAnimation = [[UIViewPropertyAnimator alloc] initWithDuration:0.7 curve:UIViewAnimationCurveEaseInOut animations:nil];
      [self.overScaleAnimation addAnimations:^{
        [self setNeedsLayout];
        self.alpha = 1.0;

        for(NSLayoutConstraint *constraint in self.constraints) {
          constraint.constant = size * 1.2;
        }

        [self layoutIfNeeded];
      }];
      [self.overScaleAnimation addCompletion:^(UIViewAnimatingPosition finalPosition) {
        [self.normalScaleAnimation startAnimation];
      }];

        //Scale to average size dot
      self.normalScaleAnimation = [[UIViewPropertyAnimator alloc] initWithDuration:0.7 curve:UIViewAnimationCurveEaseInOut animations:nil];
      [self.normalScaleAnimation addAnimations:^{
        [self setNeedsLayout];
        self.alpha = 1.0;

        for(NSLayoutConstraint *constraint in self.constraints) {
          constraint.constant = size;
        }

        [self layoutIfNeeded];
      }];
      [self.normalScaleAnimation addCompletion:^(UIViewAnimatingPosition finalPosition) {
        [self.restScaleAnimation startAnimation];
      }];

        //Scale to rest size
      self.restScaleAnimation = [[UIViewPropertyAnimator alloc] initWithDuration:2.0 curve:UIViewAnimationCurveEaseInOut animations:nil];
      [self.restScaleAnimation addAnimations:^{
        [self setNeedsLayout];
        self.alpha = 0.8;

        for(NSLayoutConstraint *constraint in self.constraints) {
          constraint.constant = size * 0.8;
        }

        [self layoutIfNeeded];
      }];

        //Start animators
      [self.overScaleAnimation startAnimation];
    });
  }

%new  //Create and start animator to hide indicator
  -(void)ir_startHideAnimatorForIndicator {
      //Stop active animators
    [self ir_stopAllAnimations];

    dispatch_async(dispatch_get_main_queue(), ^{
        //Scale to 0
      self.zeroScaleAnimation = [[UIViewPropertyAnimator alloc] initWithDuration:1.0 curve:UIViewAnimationCurveEaseInOut animations:nil];
      [self.zeroScaleAnimation addAnimations:^{
        [self setNeedsLayout];
        self.alpha = 0;

        for(NSLayoutConstraint *constraint in self.constraints) {
          constraint.constant = 0;
        }

        [self layoutIfNeeded];
      }];

        //Start animator
      [self.zeroScaleAnimation startAnimation];
    });
  }

%new  //Stop all animators
  -(void)ir_stopAllAnimations {
    dispatch_async(dispatch_get_main_queue(), ^{
      if(self.overScaleAnimation.state == UIViewAnimatingStateActive) {
        [self.overScaleAnimation stopAnimation:YES];
      }

      if(self.normalScaleAnimation.state == UIViewAnimatingStateActive) {
        [self.normalScaleAnimation stopAnimation:YES];
      }

      if(self.restScaleAnimation.state == UIViewAnimatingStateActive) {
        [self.restScaleAnimation stopAnimation:YES];
      }

      if(self.zeroScaleAnimation.state == UIViewAnimatingStateActive) {
        [self.zeroScaleAnimation stopAnimation:YES];
      }
    });
  }
%end

%ctor {
  HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:@"com.lacertosusrepo.indicatorsprefs"];
  [preferences registerInteger:&indicatorSpacing default:12 forKey:@"indicatorSpacing"];
  [preferences registerBool:&showFlashlightIndicator default:YES forKey:@"showFlashlightIndicator"];
  [preferences registerObject:&flLightColor default:@"#5691F0" forKey:@"flLightColor"];
  [preferences registerObject:&flDarkColor default:@"#FFFFFF" forKey:@"flDarkColor"];
  [preferences registerBool:&showVPNIndicator default:YES forKey:@"showVPNIndicator"];
  [preferences registerObject:&vpnLightColor default:@"#D6246E" forKey:@"vpnLightColor"];
  [preferences registerObject:&vpnDarkColor default:@"#ED5393" forKey:@"vpnDarkColor"];
  [preferences registerBool:&showDNDIndicator default:YES forKey:@"showDNDIndicator"];
  [preferences registerObject:&dndLightColor default:@"#7D3CBD" forKey:@"dndLightColor"];
  [preferences registerObject:&dndDarkColor default:@"#AE74E8" forKey:@"dndDarkColor"];

  [preferences registerPreferenceChangeBlock:^{
    if(recordingIndicatorViewController) {
      [recordingIndicatorViewController ir_updateIndicators];
    }
  }];
}
