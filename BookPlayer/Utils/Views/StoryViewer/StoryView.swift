//
//  StoryView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StoryView: View {
  @Binding var model: StoryViewModel
  var onPrevious: () -> Void
  var onNext: () -> Void
  var onPause: () -> Void
  var onResume: () -> Void
  var onSubscription: (PricingModel) -> Void
  var onDismiss: () -> Void
  var onTipJar: (String?) -> Void

  var body: some View {
    ZStack {
      StoryRewindControlView(
        onSkip: onPrevious,
        onPause: onPause,
        onResume: onResume
      )
      .accessibilityHidden(true)
      VStack {
        VStack {
          if model.image == "apple-watch" {
            Image(systemName: "applewatch.radiowaves.left.and.right")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: 150)
              .cornerRadius(9)
              .allowsHitTesting(false)
              .padding(.top, Spacing.L1 * 2)
              .padding(.bottom, Spacing.L1)
              .accessibilityHidden(true)
          }
          Text(model.title)
            .shadow(radius: 2, y: 3)
            .font(Font(Fonts.titleStory))
            .padding()
            .allowsHitTesting(false)

          Text(model.body)
            .font(Font(Fonts.bodyStory))
            .padding([.bottom, .leading, .trailing])
            .multilineTextAlignment(.center)
            .allowsHitTesting(false)

          if let image = model.image {
            switch image {
            case "family-pic":
              Image(.smallFamilyPic)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300)
                .cornerRadius(9)
                .allowsHitTesting(false)
                .padding()
                .accessibilityHidden(true)
            case "app-icon":
              HStack(alignment: .center) {
                VStack {
                  Image(uiImage: UIImage(named: "retro-icon@3x")!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .cornerRadius(9)
                  Text("2016")
                    .font(.callout.weight(.bold))
                }

                Image(systemName: "arrow.forward")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .opacity(0.6)
                  .font(.largeTitle.weight(.bold))
                  .frame(width: 40, height: 20)
                  .padding([.leading, .trailing], Spacing.S3)
                  .offset(y: -Spacing.S1)
                VStack {
                  Image(uiImage: UIImage(named: "default-icon@3x")!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .cornerRadius(9)
                  Text("Now")
                    .font(.callout.weight(.bold))
                }
              }
              .allowsHitTesting(false)
              .padding([.top], Spacing.L1)
              .padding([.leading, .trailing])
              .accessibilityHidden(true)
            default:
              EmptyView()
            }

          }
        }
        .accessibilityElement(children: .combine)

        if let action = Binding($model.action) {
          StoryActionView(
            action: action,
            onSubscription: onSubscription,
            onDismiss: onDismiss,
            onTipJar: onTipJar
          )
          .padding([.leading, .trailing])
          .padding([.top], Spacing.L1)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(.smooth, value: model.title)
      .accessibilityElement(children: .contain)
      .accessibilitySortPriority(1)
      .zIndex(1)
      StoryForwardControlView(
        onSkip: onNext,
        onPause: onPause,
        onResume: onResume
      )
      .accessibilityHidden(model.action != nil)
    }
  }
}

#Preview {
  ZStack {
    StoryBackgroundView()
    StoryView(model: .constant(
      StoryViewModel(
        title: "Story title",
        body: "Story body",
        duration: 2,
        action: .init(
          options: [
            .init(id: "supportTier4", title: "$3.99", price: 3.99),
            .init(id: "proMonthly", title: "$4.99", price: 4.99),
            .init(id: "supportTier10", title: "$9.99", price: 9.99)
          ],
          defaultOption: .init(id: "proMonthly", title: "$4.99", price: 4.99),
          button: ""
        )
      )), onPrevious: {
        print("Previous")
      }, onNext: {
        print("Next")
      }, onPause: {
        print("Pause")
      }, onResume: {
        print("Resume")
      }, onSubscription: { option in
        print(option.title)
      }, onDismiss: {
        print("Dismiss")
      }, onTipJar: { _ in
        print("Tip Jar")
      })
    .foregroundColor(.white)
  }
}
